"""Budowanie i zarządzanie listami zakupów.

Moduł agreguje składniki z planu posiłków, przelicza ilości
na pełne opakowania, uwzględnia ceny sklepowe i sortuje pozycje
według kolejności działów w sklepie.
"""

from __future__ import annotations

import logging
import math
from collections import defaultdict
from typing import Any
from uuid import UUID

from sqlalchemy import and_, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import joinedload, selectinload

from app.models import (
    MealPlan,
    MealPlanEntry,
    Product,
    Recipe,
    RecipeIngredient,
    ShoppingList,
    ShoppingListItem,
    StoreDepartment,
    StoreProduct,
)
from app.services.exceptions import MealPlanNotFoundError, ShoppingListNotFoundError
from app.services.nutrition_calculator import grams_to_quantity, quantity_to_grams

logger = logging.getLogger(__name__)


class ShoppingListBuilder:
    """Tworzy i przelicza listy zakupów na podstawie planów posiłków."""

    def __init__(self, db: AsyncSession) -> None:
        self.db = db

    # ==================================================================
    # Tworzenie listy z planu posiłków
    # ==================================================================

    async def build_from_meal_plan(self, meal_plan_id: UUID) -> ShoppingList:
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
        aggregated = self._aggregate_ingredients(meal_plan)

        # ── 3+4. Przelicz opakowania i ceny ──────────────────────────
        items_data = await self._resolve_store_details(
            aggregated=aggregated,
            store_id=meal_plan.store_id,
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
            .options(selectinload(ShoppingList.items))
        )
        result = await self.db.execute(stmt)
        shopping_list = result.scalar_one_or_none()
        if shopping_list is None:
            raise ShoppingListNotFoundError(shopping_list_id)

        meal_plan_id = shopping_list.meal_plan_id

        # Usuń stare pozycje
        for item in list(shopping_list.items):
            await self.db.delete(item)
        await self.db.flush()

        # Przebuduj
        meal_plan = await self._load_meal_plan(meal_plan_id)
        aggregated = self._aggregate_ingredients(meal_plan)
        items_data = await self._resolve_store_details(
            aggregated=aggregated,
            store_id=meal_plan.store_id,
        )

        for item_data in items_data:
            item = ShoppingListItem(
                shopping_list_id=shopping_list_id,
                **item_data,
            )
            self.db.add(item)

        await self.db.commit()
        
        result = await self.db.execute(
            select(ShoppingList)
            .options(selectinload(ShoppingList.items))
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
            store_product_obj = item.store_product
            product = store_product_obj.product if store_product_obj else None
            product_name = product.name if product else "Nieznany produkt"
            product_id = store_product_obj.product_id if store_product_obj else None
            dept_info = dept_map.get(product_id, ("Inne", 999))
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
        stmt = (
            select(MealPlan)
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
                    product_name, float(ing.quantity or 0.0), ing.unit or "g"
                )
                aggregated[ing.product_id] += grams * multiplier

        return dict(aggregated)

    async def _resolve_store_details(
        self,
        aggregated: dict[UUID, float],
        store_id: UUID,
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

        items_data: list[dict[str, Any]] = []

        for product_id, total_qty_grams in aggregated.items():
            product = products.get(product_id)
            store_product = store_products.get(product_id)

            # Pomiń składniki, które nie mają pozycji w sklepie
            if store_product is None:
                logger.warning(
                    "Produkt %s nie ma pozycji w sklepie — pomijam na liście zakupów",
                    product_id,
                )
                continue

            product_name = product.name if product else ""
            product_unit = getattr(product, "unit", None) or "szt"

            # Ilość potrzebna, przeliczona na jednostkę natywną produktu
            # (tę samą, w której podane jest default_quantity opakowania)
            required_in_product_unit = grams_to_quantity(
                product_name, total_qty_grams, product_unit
            )

            # Rozmiar opakowania — przeliczony na wspólną bazę gramów/ml,
            # żeby dzielenie odbywało się w spójnych jednostkach
            default_qty_native = float(getattr(product, "default_quantity", None) or 1.0)
            default_qty_grams = quantity_to_grams(
                product_name, default_qty_native, product_unit
            )

            package_count = (
                math.ceil(total_qty_grams / default_qty_grams)
                if default_qty_grams > 0
                else 1
            )

            # Cena
            unit_price = float(getattr(store_product, "price", None) or 0.0)
            estimated_price = round(unit_price * package_count, 2)

            # Dział
            department_id = getattr(store_product, "department_id", None)

            items_data.append(
                {
                    "store_product_id": store_product.id,
                    "required_quantity": float(round(required_in_product_unit, 2)),
                    "unit": product_unit,
                    "estimated_price": estimated_price,
                    "department_id": department_id,
                    "is_checked": False,
                }
            )

        # Sortuj po sort_order działu
        dept_order: dict[UUID | None, int] = {}
        for sp in store_products.values():
            dept = getattr(sp, "department", None)
            if dept is not None:
                dept_order[sp.department_id] = getattr(dept, "sort_order", 999)

        items_data.sort(key=lambda x: dept_order.get(x.get("department_id"), 999))
        return items_data

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
