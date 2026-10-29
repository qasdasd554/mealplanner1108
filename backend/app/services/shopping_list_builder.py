"""Budowanie i zarządzanie listami zakupów.

Moduł agreguje składniki z planu posiłków, przelicza ilości
na pełne opakowania, uwzględnia ceny sklepowe i sortuje pozycje
według kolejności działów w sklepie.
"""

from __future__ import annotations

import logging
from copy import deepcopy
from datetime import date
from decimal import Decimal, localcontext, ROUND_HALF_UP
from types import SimpleNamespace
from collections import defaultdict
from typing import Any
from uuid import UUID

from sqlalchemy import and_, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import joinedload, selectinload

from app.models import (
    MealPlan,
    MealPlanEntry,
    PantryItem,
    Product,
    Recipe,
    RecipeIngredient,
    ShoppingList,
    ShoppingListItem,
    ShoppingListItemRegionalSnapshot,
    StoreDepartment,
    StoreProduct,
    Store,
    User,
)
from app.services.exceptions import MealPlanNotFoundError, ShoppingListNotFoundError
from app.services.nutrition_calculator import grams_to_quantity, quantity_to_grams
from app.services.shopping_list_quota import record_shopping_list_creation
from app.services.regional_requirements import aggregate_regional_requirements, subtract_regional_quantity, RegionalRequirement, to_regional_base_quantity
from app.services.regional_shopping import (
    apply_regional_item_quote, load_regional_offers, refresh_regional_items,
    regional_pantry_coverage,
    regional_pricing_date,
    refresh_regional_plan_budget,
    frozen_regional_purchase_quote,
)
from fastapi import HTTPException

logger = logging.getLogger(__name__)


def pantry_coverage_grams(
    product_name: str,
    required_grams: float,
    pantry: PantryItem | None,
    product_unit: str,
    serving_quantity: float | None = None,
    measure_options: list[dict] | None = None,
) -> float:
    """Ile z zapotrzebowania pokrywa obecna spiżarnia (bez zużywania stanu)."""
    if pantry is None:
        return 0.0
    if pantry.quantity is None:
        return required_grams
    available = quantity_to_grams(
        product_name,
        float(pantry.quantity),
        pantry.unit or product_unit,
        serving_quantity,
        measure_options,
    )
    return min(required_grams, max(0.0, available))


class ShoppingListBuilder:
    """Tworzy i przelicza listy zakupów na podstawie planów posiłków."""

    def __init__(self, db: AsyncSession) -> None:
        self.db = db

    # ==================================================================
    # Tworzenie listy z planu posiłków
    # ==================================================================

    async def build_from_meal_plan(
        self,
        meal_plan_id: UUID,
        *,
        include_pantry: bool = True,
    ) -> ShoppingList:
        """Generuje listę zakupów na podstawie planu posiłków.

        Algorytm:
        1. Załaduj plan z wpisami, przepisami, składnikami.
        2. Agreguj składniki: grupuj po (product_id, unit), sumuj ilości
           z uwzględnieniem ``servings_multiplier``.
        3. Zaokrąglij do pełnych opakowań (``ceil(total / default_quantity)``).
        4. Pobierz cenę i dział ze ``StoreProduct``.
        5. Utwórz ``ShoppingList`` + pozycje.
        6. Posortuj po ``department.sort_order``.

        Args:
            meal_plan_id: identyfikator planu posiłków.

        Returns:
            Nowo utworzony obiekt ``ShoppingList``.
        """
        # ── 1. Załaduj plan ──────────────────────────────────────────
        meal_plan = await self._load_meal_plan(meal_plan_id)

        # ── 2. Agreguj składniki ─────────────────────────────────────
        store = await self.db.get(Store, meal_plan.store_id)
        is_gb = store is not None and store.country_code == "GB"
        # RecipeIngredient IDs/amounts are the source, not a similarity
        # comparison between the recipe title and catalogue product names.
        # Prepared components can themselves be intentional ingredients.
        aggregated = self._aggregate_ingredients(meal_plan) if not is_gb else None

        # ── 3+4. Przelicz opakowania i ceny ──────────────────────────
        items_data = await self._resolve_regional_requirements(meal_plan, include_pantry=include_pantry) if is_gb else await self._resolve_store_details(
            aggregated=aggregated,
            store_id=meal_plan.store_id,
            user_id=meal_plan.user_id,
            include_pantry=include_pantry,
        )

        # ── 5. Utwórz listę zakupów ─────────────────────────────────
        shopping_list = await self._create_shopping_list(
            meal_plan=meal_plan,
            items_data=items_data,
        )

        logger.info(
            "Wygenerowano listę zakupów %s (%d pozycji) dla planu %s",
            shopping_list.id,
            len(items_data),
            meal_plan_id,
        )
        return shopping_list

    # ==================================================================
    # Przeliczenie istniejącej listy
    # ==================================================================

    async def recalculate(self, shopping_list_id: UUID) -> ShoppingList:
        """Przelicza listę zakupów po zmianach w przepisach.

        Usuwa stare pozycje i generuje nowe na podstawie bieżącego stanu
        planu posiłków.

        Args:
            shopping_list_id: identyfikator istniejącej listy zakupów.

        Returns:
            Zaktualizowana ``ShoppingList``.
        """
        stmt = (
            select(ShoppingList)
            .where(ShoppingList.id == shopping_list_id)
            .with_for_update(of=ShoppingList)
            .options(selectinload(ShoppingList.items).selectinload(ShoppingListItem.store_product).selectinload(StoreProduct.product))
        )
        result = await self.db.execute(stmt)
        shopping_list = result.scalar_one_or_none()
        if shopping_list is None:
            raise ShoppingListNotFoundError(shopping_list_id)

        store = await self.db.get(Store, shopping_list.store_id)
        # Pantry sync may have split/replaced rows in this same session.
        # An already loaded collection is not current DB state in either market.
        await self.db.flush()
        shopping_list = (await self.db.execute(
            stmt.execution_options(populate_existing=True)
        )).scalar_one()

        meal_plan_id = shopping_list.meal_plan_id
        checked_regional = {}
        frozen_regional = {}
        for item in shopping_list.items:
            snapshot = item.regional_snapshot
            if item.is_generated and snapshot is not None:
                key = (snapshot.product_id, item.required_quantity, item.unit)
                flag = snapshot.purchase_is_checked if item.is_from_pantry else item.is_checked
                checked_regional.setdefault(key, []).append(bool(flag))
                if store is not None and store.country_code == "GB" and item.is_checked and not item.is_from_pantry:
                    if frozen_regional_purchase_quote(item) is None:
                        raise HTTPException(status_code=409, detail="Correct the saved purchased package before recalculating this list.")
                    values = {
                        column.name: deepcopy(getattr(snapshot, column.name))
                        for column in ShoppingListItemRegionalSnapshot.__table__.columns
                        if column.name != "item_id"
                    }
                    values["purchase_is_checked"] = True
                    frozen_regional.setdefault(key, []).append((values, item.estimated_price))
        manual_extras = {}
        for item in shopping_list.items:
            snapshot = item.regional_snapshot
            if item.is_generated and snapshot is not None and (snapshot.manual_extra_quantity or 0) > 0:
                key = (snapshot.product_id, item.unit)
                manual_extras[key] = manual_extras.get(key, Decimal(0)) + snapshot.manual_extra_quantity

        # Przebuduj
        meal_plan = await self._load_meal_plan(meal_plan_id)
        store = await self.db.get(Store, meal_plan.store_id)
        is_gb = store is not None and store.country_code == "GB"
        aggregated = self._aggregate_ingredients(meal_plan) if not is_gb else None
        items_data = await self._resolve_regional_requirements(
            meal_plan, include_pantry=(meal_plan.preferences or {}).get("include_pantry", True),
            manual_extras=manual_extras,
        ) if is_gb else await self._resolve_store_details(
            aggregated=aggregated,
            store_id=meal_plan.store_id,
            user_id=meal_plan.user_id,
            include_pantry=(meal_plan.preferences or {}).get("include_pantry", True),
        )

        if not is_gb:
            from app.services.polish_shopping_amounts import preserve_polish_purchases
            await preserve_polish_purchases(self.db, shopping_list.items, items_data)

        for item_data in items_data:
            snapshot = item_data.get("regional_snapshot")
            if snapshot is not None:
                key = (snapshot.product_id, item_data["required_quantity"], item_data["unit"])
                old_flags = checked_regional.get(key, [])
                flag = old_flags.pop(0) if old_flags else False
                snapshot.purchase_is_checked = flag
                if not item_data.get("is_from_pantry"):
                    item_data["is_checked"] = flag
                    history = frozen_regional.get(key, [])
                    if flag and history:
                        saved, price = history.pop(0)
                        item_data["regional_snapshot"] = ShoppingListItemRegionalSnapshot(**saved)
                        item_data["estimated_price"] = price
                        item_data["custom_name"] = saved["name_en"][:200]

        if any(values for values in frozen_regional.values()):
            # No old rows have been deleted and no new rows staged. An edited
            # requirement must not invent a different already-bought package.
            raise HTTPException(status_code=409, detail="The recipe amounts changed for a purchased item. Correct its purchase state before recalculating.")

        # Delete only after all current GB purchases can be retained safely.
        # Retained manual/merged rows are not rebuilt from recipe entries.
        for item in list(shopping_list.items):
            if item.is_generated:
                await self.db.delete(item)
        await self.db.flush()
        for item_data in items_data:
            item = ShoppingListItem(
                shopping_list_id=shopping_list_id,
                **item_data,
            )
            self.db.add(item)

        if is_gb:
            # Generated objects were deleted; retained manual/merged snapshots
            # must also move to the new store instead of keeping old GBP packs.
            retained = [item for item in shopping_list.items if not item.is_generated]
            await refresh_regional_items(self.db, SimpleNamespace(items=retained, store_id=meal_plan.store_id))
            await refresh_regional_plan_budget(self.db, shopping_list)
        else:
            from app.services.polish_shopping_amounts import refresh_polish_items
            retained = [item for item in shopping_list.items if not item.is_generated]
            await refresh_polish_items(self.db, SimpleNamespace(items=retained), meal_plan.store_id)

        await self.db.commit()

        result = await self.db.execute(
            select(ShoppingList)
            .execution_options(populate_existing=True)
            .options(
                selectinload(ShoppingList.items).selectinload(ShoppingListItem.store_product).selectinload(StoreProduct.product),
                selectinload(ShoppingList.items).selectinload(ShoppingListItem.department),
                selectinload(ShoppingList.items).selectinload(ShoppingListItem.substituted_for_product),
                selectinload(ShoppingList.store),
            )
            .where(ShoppingList.id == shopping_list_id)
        )
        shopping_list_loaded = result.scalar_one()

        logger.info(
            "Przeliczono listę zakupów %s (%d pozycji)",
            shopping_list_id,
            len(items_data),
        )
        return shopping_list_loaded

    # ==================================================================
    # Grupowanie wg działów
    # ==================================================================

    async def get_grouped_by_department(
        self,
        shopping_list_id: UUID,
    ) -> dict[str, list[dict[str, Any]]]:
        """Zwraca pozycje listy pogrupowane wg nazwy działu sklepowego.

        Pozycje wewnątrz każdego działu posortowane są po nazwie produktu.
        Działy posortowane wg ``sort_order``.

        Args:
            shopping_list_id: identyfikator listy zakupów.

        Returns:
            Słownik ``{department_name: [item_dicts, ...]}``.
        """
        stmt = (
            select(ShoppingList)
            .where(ShoppingList.id == shopping_list_id)
            .options(
                selectinload(ShoppingList.items)
                .selectinload(ShoppingListItem.store_product)
                .joinedload(StoreProduct.product),
            )
        )
        result = await self.db.execute(stmt)
        shopping_list = result.scalar_one_or_none()
        if shopping_list is None:
            raise ShoppingListNotFoundError(shopping_list_id)

        store_id = shopping_list.meal_plan_id  # potrzebujemy store_id z planu
        # Pobierz plan dla store_id
        plan_stmt = select(MealPlan.store_id).where(
            MealPlan.id == shopping_list.meal_plan_id
        )
        plan_result = await self.db.execute(plan_stmt)
        store_id = plan_result.scalar_one()

        # Pobierz mapę product_id -> (department_name, sort_order)
        dept_stmt = (
            select(
                StoreProduct.product_id,
                StoreDepartment.name,
                StoreDepartment.sort_order,
            )
            .join(StoreDepartment, StoreProduct.department_id == StoreDepartment.id)
            .where(StoreProduct.store_id == store_id)
        )
        dept_result = await self.db.execute(dept_stmt)
        dept_map: dict[UUID, tuple[str, int]] = {}
        for product_id, dept_name, sort_order in dept_result.all():
            dept_map[product_id] = (dept_name, sort_order or 0)

        # Grupuj pozycje
        grouped: dict[str, list[dict[str, Any]]] = defaultdict(list)
        sort_keys: dict[str, int] = {}

        for item in shopping_list.items:
            snapshot = item.regional_snapshot
            if snapshot is not None:
                dept_name = "In pantry" if item.is_from_pantry else "Other"
                sort_keys[dept_name] = 10_000 if item.is_from_pantry else 999
                grouped[dept_name].append({
                    "id": item.id, "product_id": snapshot.product_id,
                    "product_name": snapshot.name_en, "quantity": item.required_quantity,
                    "unit": item.unit, "package_count": (snapshot.quote_data or {}).get("package_count"),
                    "estimated_price": item.estimated_price, "is_checked": item.is_checked,
                    "currency_code": "GBP", "quote_status": snapshot.quote_status,
                })
                continue
            store_product_obj = item.store_product
            product = store_product_obj.product if store_product_obj else None
            product_name = product.name if product else (item.custom_name or "Nieznany produkt")
            product_id = store_product_obj.product_id if store_product_obj else None
            dept_info = (
                ("W spiżarni", 10_000) if item.is_from_pantry
                else dept_map.get(product_id, ("Inne", 999))
            )
            dept_name, sort_order = dept_info
            sort_keys[dept_name] = sort_order

            grouped[dept_name].append(
                {
                    "id": item.id,
                    "product_id": product_id,
                    "product_name": product_name,
                    "quantity": item.required_quantity,
                    "unit": item.unit,
                    "package_count": getattr(item, "package_count", None),
                    "estimated_price": getattr(item, "estimated_price", None),
                    "is_checked": getattr(item, "is_checked", False),
                }
            )

        # Sortuj pozycje w działach po nazwie produktu
        for dept_name in grouped:
            grouped[dept_name].sort(key=lambda x: x["product_name"])

        # Zwróć posortowany wg sort_order
        sorted_grouped: dict[str, list[dict[str, Any]]] = {}
        for dept_name in sorted(grouped.keys(), key=lambda d: sort_keys.get(d, 999)):
            sorted_grouped[dept_name] = grouped[dept_name]

        return sorted_grouped

    # ==================================================================
    # Metody wewnętrzne
    # ==================================================================

    async def _load_meal_plan(self, meal_plan_id: UUID) -> MealPlan:
        """Ładuje plan z wpisami, przepisami i składnikami."""
        # expire_on_commit=False can retain the previous entries collection
        # after appending a recipe. Persist pending edits, then load the
        # actual source rows rather than silently rebuilding the old list.
        await self.db.flush()
        stmt = (
            select(MealPlan)
            .execution_options(populate_existing=True)
            .where(MealPlan.id == meal_plan_id)
            .options(
                selectinload(MealPlan.entries)
                .joinedload(MealPlanEntry.recipe)
                .selectinload(Recipe.ingredients)
                .joinedload(RecipeIngredient.product),
            )
        )
        result = await self.db.execute(stmt)
        meal_plan = result.scalar_one_or_none()
        if meal_plan is None:
            raise MealPlanNotFoundError(meal_plan_id)
        return meal_plan

    @staticmethod
    def _aggregate_ingredients(
        meal_plan: MealPlan,
    ) -> dict[UUID, float]:
        """Agreguje składniki z planu posiłków.

        Grupuje po ``product_id`` i sumuje ilości przeliczone na wspólną bazę
        gramów/mililitrów (funkcja ``quantity_to_grams``), niezależnie od
        jednostki użytej w danym przepisie — dzięki temu ten sam produkt
        podany w różnych przepisach w różnych jednostkach (np. 'g' i 'kg')
        poprawnie się sumuje zamiast tworzyć osobne pozycje.

        Returns:
            Słownik ``{product_id: total_quantity_w_gramach_lub_ml}``.
        """
        aggregated: dict[UUID, float] = defaultdict(float)

        for entry in meal_plan.entries:
            recipe = entry.recipe
            if recipe is None:
                continue

            multiplier = float(entry.servings_multiplier or 1.0)

            for ing in recipe.ingredients:
                product = ing.product
                product_name = product.name if product else ""
                grams = quantity_to_grams(
                    product_name,
                    float(ing.quantity or 0.0),
                    ing.unit or "g",
                    getattr(product, "serving_quantity", None),
                    getattr(product, "measure_options", None),
                )
                aggregated[ing.product_id] += grams * multiplier

        return dict(aggregated)

    async def _resolve_store_details(
        self,
        aggregated: dict[UUID, float],
        store_id: UUID,
        user_id: UUID,
        include_pantry: bool = True,
    ) -> list[dict[str, Any]]:
        """Uzupełnia dane sklepowe: opakowania, ceny, działy.

        ``aggregated`` zawiera sumy w spójnej bazie gramów/mililitrów
        (patrz ``_aggregate_ingredients``). Tutaj przeliczamy tę sumę na
        jednostkę natywną produktu (tę, w której sprzedawany jest w sklepie —
        ``product.unit`` / ``product.default_quantity``), dopiero wtedy
        zaokrąglając do pełnych opakowań i licząc cenę. Bez tej konwersji
        dzielenie ilości podanej w jednej jednostce (np. gramy z przepisu)
        przez rozmiar opakowania podany w innej jednostce (np. kilogramy)
        dawało drastycznie zawyżoną liczbę opakowań i cenę.

        Returns:
            Lista słowników gotowych do utworzenia ``ShoppingListItem``.
        """
        if not aggregated:
            return []

        product_ids = set(aggregated.keys())

        # Produkty
        prod_stmt = select(Product).where(Product.id.in_(product_ids))
        prod_result = await self.db.execute(prod_stmt)
        products: dict[UUID, Product] = {p.id: p for p in prod_result.scalars().all()}

        # Pozycje sklepowe
        sp_stmt = (
            select(StoreProduct)
            .where(
                and_(
                    StoreProduct.store_id == store_id,
                    StoreProduct.product_id.in_(product_ids),
                )
            )
            .options(joinedload(StoreProduct.department))
        )
        sp_result = await self.db.execute(sp_stmt)
        store_products: dict[UUID, StoreProduct] = {
            sp.product_id: sp for sp in sp_result.scalars().unique().all()
        }

        pantry_by_product: dict[UUID, PantryItem] = {}
        if include_pantry:
            pantry_result = await self.db.execute(
                select(PantryItem).where(
                    PantryItem.user_id == user_id,
                    PantryItem.product_id.in_(product_ids),
                )
            )
            pantry_by_product = {
                item.product_id: item for item in pantry_result.scalars().all()
            }

        items_data: list[dict[str, Any]] = []

        for product_id, total_qty_grams in aggregated.items():
            product = products.get(product_id)
            store_product = store_products.get(product_id)

            if product is None:
                continue

            product_name = product.name
            product_unit = getattr(product, "unit", None) or "szt"

            pantry_grams = pantry_coverage_grams(
                product_name, total_qty_grams,
                pantry_by_product.get(product_id), product_unit,
                getattr(product, "serving_quantity", None),
                getattr(product, "measure_options", None),
            )
            purchase_grams = max(0.0, total_qty_grams - pantry_grams)

            if pantry_grams > 0:
                items_data.append({
                    "store_product_id": store_product.id if store_product else None,
                    "custom_name": None if store_product else product_name,
                    "required_quantity": round(grams_to_quantity(
                        product_name, pantry_grams, product_unit,
                        getattr(product, "serving_quantity", None),
                        getattr(product, "measure_options", None),
                    ), 3),
                    "unit": product_unit,
                    "estimated_price": 0,
                    "department_id": None,
                    "is_checked": True,
                    "is_from_pantry": True,
                    "is_generated": True,
                })
            if purchase_grams <= 0:
                continue

            if (store_product is None or not getattr(store_product, "is_available", True)
                    or getattr(store_product, "withdrawn_at", None) is not None):
                # Nie ukrywamy brakującej części tylko dlatego, że ten
                # sklep nie ma produktu w katalogu. Ceny nie zgadujemy.
                items_data.append({
                    "store_product_id": store_product.id if store_product is not None else None,
                    "custom_name": None if store_product is not None else product_name,
                    "required_quantity": round(grams_to_quantity(
                        product_name, purchase_grams, product_unit,
                        getattr(product, "serving_quantity", None),
                        getattr(product, "measure_options", None),
                    ), 3),
                    "unit": product_unit,
                    "estimated_price": None,
                    "department_id": None,
                    "is_checked": False,
                    "is_from_pantry": False,
                    "is_generated": True,
                })
                continue

            # Ilość potrzebna, przeliczona na jednostkę natywną produktu
            # (tę samą, w której podane jest default_quantity opakowania)
            required_in_product_unit = grams_to_quantity(
                product_name,
                purchase_grams,
                product_unit,
                getattr(product, "serving_quantity", None),
                getattr(product, "measure_options", None),
            )

            # Persist a physical amount at the available 3-decimal precision.
            # Kilogram/litre fractions should use g/ml when native rounding would
            # discard a meaningful part of the required quantity.
            from app.services.polish_shopping_amounts import item_price, product_amount
            from app.services.uk_catalogue_import import canonical_base_unit
            native = Decimal(str(required_in_product_unit))
            stored = native.quantize(Decimal("0.001"), rounding=ROUND_HALF_UP)
            stored_unit = product_unit
            if stored <= 0 or (product_unit in {"kg", "l"} and abs(native - stored) > Decimal("0.000000001")):
                stored, stored_unit = product_amount(product, Decimal(str(purchase_grams)), canonical_base_unit(product))
            estimated_price = item_price(product, store_product, stored, stored_unit)

            # Dział
            department_id = getattr(store_product, "department_id", None)

            items_data.append(
                {
                    "store_product_id": store_product.id,
                    "required_quantity": stored,
                    "unit": stored_unit,
                    "estimated_price": estimated_price,
                    "department_id": department_id,
                    "is_checked": False,
                    "is_from_pantry": False,
                    "is_generated": True,
                }
            )

        # Sortuj po sort_order działu
        dept_order: dict[UUID | None, int] = {}
        for sp in store_products.values():
            dept = getattr(sp, "department", None)
            if dept is not None:
                dept_order[sp.department_id] = getattr(dept, "sort_order", 999)

        items_data.sort(key=lambda x: (
            x.get("is_from_pantry", False),
            dept_order.get(x.get("department_id"), 999),
        ))
        return items_data

    async def _resolve_regional_requirements(self, meal_plan, *, include_pantry=True, manual_extras=None):
        requirements = aggregate_regional_requirements(meal_plan)
        manual_by_key = {}
        if manual_extras:
            # Re-aggregate original raw requirements PLUS extras. Replacing a
            # dictionary entry would discard the recipe when raw units differ.
            raw_by_product = {}
            products = {}
            for product_id, requirement in requirements.items():
                if not requirement.raw_amounts:
                    raise ValueError("Shopping ingredient quantity cannot be represented safely")
                raw_by_product[product_id] = list(requirement.raw_amounts)
                products[product_id] = requirement.product
            for (product_id, unit), extra in manual_extras.items():
                product = products.get(product_id) or await self.db.get(Product, product_id)
                if product is None:
                    raise ValueError("A manual shopping addition has no canonical product")
                products[product_id] = product
                raw_by_product.setdefault(product_id, []).append((extra, unit))
                try:
                    amount, tracked_unit = to_regional_base_quantity(product, extra, unit)
                except ValueError:
                    amount, tracked_unit = extra, unit
                key = (product_id, tracked_unit)
                manual_by_key[key] = manual_by_key.get(key, Decimal(0)) + amount
            ingredients = []
            for product_id, raw_amounts in raw_by_product.items():
                grouped = {}
                with localcontext() as arithmetic:
                    arithmetic.prec = 130
                    for amount, unit in raw_amounts:
                        grouped[unit] = grouped.get(unit, Decimal(0)) + amount
                ingredients.extend(SimpleNamespace(
                    product_id=product_id, product=products[product_id], quantity=amount, unit=unit,
                ) for unit, amount in grouped.items())
            requirements = aggregate_regional_requirements(SimpleNamespace(entries=[SimpleNamespace(
                servings_multiplier=Decimal(1), recipe=SimpleNamespace(ingredients=ingredients),
            )]))
        product_ids = set(requirements)
        offers = await load_regional_offers(self.db, product_ids, meal_plan.store_id)
        pantry = {}
        if include_pantry and product_ids:
            result = await self.db.execute(select(PantryItem).where(
                PantryItem.user_id == meal_plan.user_id, PantryItem.product_id.in_(product_ids),
            ))
            pantry = {row.product_id: row for row in result.scalars().all()}
        result = []
        for requirement in requirements.values():
            first_result = len(result)
            product = requirement.product
            if product is None:
                raise ValueError("A shopping ingredient has no canonical product")
            if requirement.quantity is not None:
                quantities = [(requirement.quantity, requirement.unit)]
                covered = regional_pantry_coverage(
                    product, requirement.quantity, requirement.unit, pantry.get(product.id),
                )
            else:
                from app.services.regional_requirements import canonical_measure_code
                # Unknown conversions must not fan every recipe into a separate
                # line. Sum only equal units; never add grams to unknown scoops.
                grouped_raw = {}
                with localcontext() as arithmetic:
                    arithmetic.prec = 130
                    for amount, raw_unit in requirement.raw_amounts:
                        raw_unit = canonical_measure_code(raw_unit)
                        grouped_raw[raw_unit] = grouped_raw.get(raw_unit, Decimal(0)) + amount
                quantities = [(amount, unit) for unit, amount in grouped_raw.items()]
                covered = Decimal(0)
            if not quantities:
                raise ValueError("Shopping ingredient quantity cannot be represented safely")
            if covered > 0:
                quantities = [(subtract_regional_quantity(requirement.quantity, covered), requirement.unit)]
                item = ShoppingListItem(is_generated=True, is_checked=False)
                apply_regional_item_quote(
                    item, product=product, store_id=meal_plan.store_id,
                    quantity=covered, unit=requirement.unit, offers=offers,
                    as_of=regional_pricing_date(), from_pantry=True,
                )
                result.append(self._regional_item_data(item))
            for quantity, unit in quantities:
                if quantity <= 0:
                    continue
                item = ShoppingListItem(is_generated=True, is_checked=False)
                apply_regional_item_quote(
                    item, product=product, store_id=meal_plan.store_id,
                    quantity=quantity, unit=unit, offers=offers, as_of=regional_pricing_date(),
                )
                if requirement.quantity is None:
                    item.estimated_price = None
                    item.regional_snapshot.quote_status = "unpriced"
                    item.regional_snapshot.quote_data = None
                    item.regional_snapshot.offer_id = None
                result.append(self._regional_item_data(item))
            for item_data in sorted(result[first_result:], key=lambda value: value["is_from_pantry"]):
                key = (product.id, item_data["unit"])
                manual_left = manual_by_key.get(key, Decimal(0))
                extra = min(manual_left, item_data["required_quantity"])
                item_data["regional_snapshot"].manual_extra_quantity = extra
                manual_by_key[key] = subtract_regional_quantity(manual_left, extra)
        return result

    @staticmethod
    def _regional_item_data(item):
        snapshot = item.regional_snapshot
        item.regional_snapshot = None
        return {
            "store_product_id": None, "custom_name": item.custom_name,
            "required_quantity": item.required_quantity, "unit": item.unit,
            "estimated_price": item.estimated_price, "department_id": None,
            "is_checked": item.is_checked, "is_from_pantry": item.is_from_pantry,
            "is_generated": bool(item.is_generated), "regional_snapshot": snapshot,
        }

    async def _create_shopping_list(
        self,
        meal_plan: MealPlan,
        items_data: list[dict[str, Any]],
    ) -> ShoppingList:
        """Tworzy obiekt ShoppingList z pozycjami i zapisuje w bazie."""
        shopping_list = ShoppingList(
            meal_plan_id=meal_plan.id,
            store_id=meal_plan.store_id,
        )
        self.db.add(shopping_list)
        await self.db.flush()
        user = await self.db.get(User, meal_plan.user_id)
        if user is None:
            raise MealPlanNotFoundError(meal_plan.id)
        await record_shopping_list_creation(
            self.db, user=user, shopping_list_id=shopping_list.id,
        )

        for item_data in items_data:
            item = ShoppingListItem(
                shopping_list_id=shopping_list.id,
                **item_data,
            )
            self.db.add(item)

        await self.db.commit()

        result = await self.db.execute(
            select(ShoppingList)
            .options(selectinload(ShoppingList.items))
            .where(ShoppingList.id == shopping_list.id)
        )
        return result.scalar_one()
