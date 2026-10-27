"""Serwis substytucji produktów.

Obsługuje:
- wyszukiwanie predefiniowanych substytutów z tabeli ``product_substitutes``,
- automatyczną obsługę wycofania produktu ze sklepu,
- fallback na wyszukiwanie podobnych produktów w tym samym dziale
  z użyciem cosine similarity wektorów odżywczych.
"""

from __future__ import annotations

import logging
import math
from datetime import date
from collections import defaultdict
from decimal import Decimal
from typing import Any
from uuid import UUID

from sqlalchemy import and_, or_, select, update
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import joinedload, selectinload

from app.models import (
    MealPlan,
    MealPlanEntry,
    Product,
    ProductSubstitute,
    Recipe,
    RecipeIngredient,
    ShoppingList,
    ShoppingListItem,
    StoreDepartment,
    StoreProduct,
    Store,
    RegionalProductOffer,
)
from app.services.exceptions import (
    ProductNotFoundError,
    StoreProductNotFoundError,
)
from app.services.nutrition_calculator import NutritionCalculator, quantity_to_grams, grams_to_quantity
from app.services.regional_shopping import apply_regional_item_quote, load_regional_offers, regional_pricing_date
from app.services.regional_requirements import to_regional_base_quantity
from app.services.uk_catalogue_import import canonical_base_unit
from app.services.regional_offer_pricing import select_uk_offer_quote
from app.services.market_catalog import regional_offer_available_condition
from app.services.product_market_presentation import is_uk_generic_seed
from app.services.system_content_language import generic_system_ingredient_condition

logger = logging.getLogger(__name__)


def _compatible_dimensions(original, selected):
    if original is None or selected is None:
        return False
    if original.unit == selected.unit == "szt":
        return True
    try:
        return canonical_base_unit(original) == canonical_base_unit(selected)
    except ValueError:
        return False


class ProductSubstitutionService:
    """Zarządza substytucją produktów w planach posiłków i listach zakupów."""

    def __init__(self, db: AsyncSession) -> None:
        self.db = db
        self.nutrition = NutritionCalculator()

    # ==================================================================
    # Wyszukiwanie substytutów
    # ==================================================================

    async def find_substitutes(
        self,
        product_id: UUID,
        store_id: UUID,
        limit: int = 5,
    ) -> list[dict[str, Any]]:
        """Wyszukuje predefiniowane substytuty dostępne w danym sklepie.

        Algorytm:
        1. Pobierz substytuty z tabeli ``product_substitutes``.
        2. Odfiltruj te, które są dostępne w podanym sklepie
           (``is_available=True``, ``withdrawn_at IS NULL``).
        3. Posortuj po ``similarity_score`` malejąco.

        Args:
            product_id: identyfikator produktu oryginalnego.
            store_id: identyfikator sklepu.
            limit: maksymalna liczba wyników.

        Returns:
            Lista słowników z kluczami: ``product``, ``similarity_score``,
            ``store_product``.
        """
        # Pobierz predefiniowane substytuty
        sub_stmt = (
            select(ProductSubstitute)
            .where(ProductSubstitute.original_product_id == product_id)
            .options(joinedload(ProductSubstitute.substitute_product))
            .order_by(ProductSubstitute.similarity_score.desc())
        )
        sub_result = await self.db.execute(sub_stmt)
        substitutes = sub_result.scalars().unique().all()

        if not substitutes:
            return []

        store = await self.db.get(Store, store_id)
        if store is not None and store.country_code == "GB":
            original = await self.db.get(Product, product_id)
            return await self._regional_candidates(
                original, [(sub.substitute_product, sub.similarity_score) for sub in substitutes],
                store_id=store_id, limit=limit,
            )

        # Pobierz dostępność w sklepie
        substitute_ids = [s.substitute_product_id for s in substitutes]
        sp_stmt = select(StoreProduct).where(
            and_(
                StoreProduct.store_id == store_id,
                StoreProduct.product_id.in_(substitute_ids),
                StoreProduct.is_available.is_(True),
                StoreProduct.withdrawn_at.is_(None),
            )
        )
        sp_result = await self.db.execute(sp_stmt)
        available_store_products: dict[UUID, StoreProduct] = {
            sp.product_id: sp for sp in sp_result.scalars().all()
        }

        results: list[dict[str, Any]] = []
        original = await self.db.get(Product, product_id)
        for sub in substitutes:
            if (sub.substitute_product_id not in available_store_products
                    or sub.substitute_product.review_status != "approved"
                    or not _compatible_dimensions(original, sub.substitute_product)):
                continue
            results.append(
                {
                    "product": sub.substitute_product,
                    "similarity_score": sub.similarity_score,
                    "store_product": available_store_products[sub.substitute_product_id],
                }
            )
            if len(results) >= limit:
                break

        return results

    # ==================================================================
    # Obsługa wycofania produktu
    # ==================================================================

    async def handle_product_withdrawal(
        self,
        store_product_id: UUID,
    ) -> dict[str, Any]:
        """Obsługuje wycofanie produktu ze sklepu.

        Algorytm:
        1. Znajdź wycofaną pozycję sklepową.
        2. Znajdź aktywne plany posiłków używające tego produktu.
        3. Dla każdego planu:
           a. Spróbuj znaleźć substytut w tym samym sklepie.
           b. Jeśli znaleziono — automatycznie zamień w liście zakupów.
           c. Jeśli nie — oznacz jako wymagająca ręcznej interwencji.

        Args:
            store_product_id: identyfikator wycofanej pozycji sklepowej.

        Returns:
            Słownik z wynikami obsługi wycofania.
        """
        # 1. Pobierz wycofaną pozycję
        sp_stmt = select(StoreProduct).where(StoreProduct.id == store_product_id)
        sp_result = await self.db.execute(sp_stmt)
        store_product = sp_result.scalar_one_or_none()
        if store_product is None:
            raise StoreProductNotFoundError(store_product_id)

        product_id = store_product.product_id
        store_id = store_product.store_id

        # 2. Znajdź aktywne plany używające tego produktu
        affected_plans = await self._find_affected_plans(product_id, store_id)

        if not affected_plans:
            return {
                "action": "no_impact",
                "message": "Brak aktywnych planów używających tego produktu.",
                "product_id": str(product_id),
            }

        # 3. Szukaj substytutów
        substitutes = await self.find_substitutes(
            product_id=product_id,
            store_id=store_id,
            limit=1,
        )

        if not substitutes:
            # Fallback — szukaj podobnych produktów
            similar = await self.auto_find_similar(
                product_id=product_id,
                store_id=store_id,
            )
            if similar:
                substitutes = similar[:1]

        # Generic/national references are manual choices, not a physical SKU
        # that can be silently auto-swapped by a withdrawal job.
        substitutes = [row for row in substitutes if row.get("store_product") is not None]
        if substitutes:
            best_sub = substitutes[0]
            sub_product = best_sub["product"]
            sub_store_product = best_sub["store_product"]

            # Auto-swap w listach zakupów
            swapped_lists = await self._auto_swap_in_shopping_lists(
                original_product_id=product_id,
                substitute_product_id=sub_product.id,
                substitute_store_product=sub_store_product,
                affected_plans=affected_plans,
            )

            return {
                "action": "auto_substituted",
                "original_product_id": str(product_id),
                "substitute_product_id": str(sub_product.id),
                "substitute_name": sub_product.name,
                "similarity_score": best_sub.get("similarity_score", 0.0),
                "affected_plans": [str(p.id) for p in affected_plans],
                "swapped_shopping_lists": swapped_lists,
            }

        # Brak substytutów
        return {
            "action": "manual_required",
            "original_product_id": str(product_id),
            "affected_plans": [str(p.id) for p in affected_plans],
            "message": (
                "Nie znaleziono automatycznego substytutu. "
                "Wymagana ręczna interwencja użytkownika."
            ),
        }

    # ==================================================================
    # Wyszukiwanie podobnych (fallback)
    # ==================================================================

    async def auto_find_similar(
        self,
        product_id: UUID,
        store_id: UUID,
        limit: int = 5,
    ) -> list[dict[str, Any]]:
        """Wyszukuje produkty podobne odżywczo w tym samym dziale.

        Stosuje cosine similarity na wektorach makroskładników
        ``(kcal, protein, fat, carbs, fiber)``.

        Args:
            product_id: identyfikator produktu referencyjnego.
            store_id: identyfikator sklepu.
            limit: maksymalna liczba wyników.

        Returns:
            Lista posortowana malejąco wg similarity.
        """
        # Pobierz produkt referencyjny
        ref_stmt = select(Product).where(Product.id == product_id)
        ref_result = await self.db.execute(ref_stmt)
        ref_product = ref_result.scalar_one_or_none()
        if ref_product is None:
            raise ProductNotFoundError(product_id)

        store = await self.db.get(Store, store_id)
        if store is not None and store.country_code == "GB":
            local_ids = select(RegionalProductOffer.product_id).where(
                RegionalProductOffer.store_id == store_id,
                RegionalProductOffer.country_code == "GB", RegionalProductOffer.currency_code == "GBP",
                regional_offer_available_condition(as_of=regional_pricing_date()),
            )
            result = await self.db.execute(select(Product).where(
                or_(Product.id.in_(local_ids), generic_system_ingredient_condition(Product)),
                Product.id != product_id, Product.review_status == "approved",
            ).order_by(Product.id).limit(max(50, min(limit * 20, 200))))
            reference = self.nutrition.nutrition_vector(ref_product)
            scored = [(product, self.nutrition.cosine_similarity(reference, self.nutrition.nutrition_vector(product)))
                      for product in result.scalars().all()]
            scored.sort(key=lambda row: row[1], reverse=True)
            return await self._regional_candidates(ref_product, scored, store_id=store_id, limit=limit)

        ref_vector = self.nutrition.nutrition_vector(ref_product)

        # Znajdź dział produktu w sklepie
        ref_sp_stmt = select(StoreProduct.department_id).where(
            and_(
                StoreProduct.store_id == store_id,
                StoreProduct.product_id == product_id,
            )
        )
        ref_sp_result = await self.db.execute(ref_sp_stmt)
        ref_department_id = ref_sp_result.scalar_one_or_none()

        # Pobierz kandydatów z tego samego działu (lub ze wszystkich, jeśli brak działu)
        candidates_stmt = (
            select(StoreProduct)
            .where(
                and_(
                    StoreProduct.store_id == store_id,
                    StoreProduct.is_available.is_(True),
                    StoreProduct.withdrawn_at.is_(None),
                    StoreProduct.product_id != product_id,
                )
            )
            .options(joinedload(StoreProduct.product))
        )
        if ref_department_id is not None:
            candidates_stmt = candidates_stmt.where(
                StoreProduct.department_id == ref_department_id
            )

        cand_result = await self.db.execute(candidates_stmt)
        candidates = cand_result.scalars().unique().all()

        # Oblicz cosine similarity
        scored: list[dict[str, Any]] = []
        for sp in candidates:
            product = sp.product
            if (product is None or product.review_status != "approved"
                    or not _compatible_dimensions(ref_product, product)):
                continue
            cand_vector = self.nutrition.nutrition_vector(product)
            similarity = self.nutrition.cosine_similarity(ref_vector, cand_vector)
            scored.append(
                {
                    "product": product,
                    "similarity_score": similarity,
                    "store_product": sp,
                }
            )

        # Sortuj malejąco
        scored.sort(key=lambda x: x["similarity_score"], reverse=True)
        return scored[:limit]

    # ==================================================================
    # Metody pomocnicze
    # ==================================================================

    async def _find_affected_plans(
        self,
        product_id: UUID,
        store_id: UUID,
    ) -> list[MealPlan]:
        """Znajduje aktywne plany posiłków używające danego produktu w danym sklepie."""
        stmt = (
            select(MealPlan)
            .where(
                and_(
                    MealPlan.store_id == store_id,
                    MealPlan.status.in_(["draft", "active"]),
                )
            )
            .options(
                selectinload(MealPlan.entries)
                .joinedload(MealPlanEntry.recipe)
                .selectinload(Recipe.ingredients),
            )
        )
        result = await self.db.execute(stmt)
        all_plans = result.scalars().unique().all()

        affected: list[MealPlan] = []
        for plan in all_plans:
            for entry in plan.entries:
                recipe = entry.recipe
                if recipe is None:
                    continue
                for ing in recipe.ingredients:
                    if ing.product_id == product_id:
                        affected.append(plan)
                        break
                else:
                    continue
                break

        return affected

    async def _auto_swap_in_shopping_lists(
        self,
        original_product_id: UUID,
        substitute_product_id: UUID,
        substitute_store_product: StoreProduct,
        affected_plans: list[MealPlan],
    ) -> list[str]:
        """Automatycznie zamienia produkt w listach zakupów powiązanych planów.

        Returns:
            Lista identyfikatorów zaktualizowanych list zakupów (jako stringi).
        """
        plan_ids = [p.id for p in affected_plans]
        if not plan_ids:
            return []

        # Znajdź listy zakupów powiązane z planami
        sl_stmt = (
            select(ShoppingList)
            .where(ShoppingList.meal_plan_id.in_(plan_ids))
            .options(selectinload(ShoppingList.items))
        )
        sl_result = await self.db.execute(sl_stmt)
        shopping_lists = sl_result.scalars().unique().all()

        # Find store_product_ids for the original product in the relevant stores
        orig_sp_stmt = select(StoreProduct.id).where(
            StoreProduct.product_id == original_product_id
        )
        orig_sp_result = await self.db.execute(orig_sp_stmt)
        orig_sp_ids = set(orig_sp_result.scalars().all())

        swapped_ids: list[str] = []

        for sl in shopping_lists:
            for item in sl.items:
                if item.store_product_id in orig_sp_ids:
                    item.substituted_for = original_product_id
                    item.store_product_id = substitute_store_product.id
                    # Aktualizuj cenę na podstawie nowego store_product
                    new_price = float(getattr(substitute_store_product, "price", None) or 0.0)
                    item.estimated_price = new_price
                    # Aktualizuj dział
                    new_dept_id = getattr(substitute_store_product, "department_id", None)
                    if new_dept_id is not None:
                        item.department_id = new_dept_id

            swapped_ids.append(str(sl.id))

        await self.db.commit()
        return swapped_ids

    async def substitute_shopping_list_item(
        self,
        item: ShoppingListItem,
        substitute_product_id: UUID,
        store_id: UUID,
    ) -> ShoppingListItem:
        """Ręczna wymiana pojedynczego produktu na liście zakupów.

        Args:
            item: pozycja do zmiany.
            substitute_product_id: ID nowego produktu.
            store_id: ID sklepu powiązanego z listą.

        Returns:
            Zaktualizowana pozycja ShoppingListItem.
        """
        from sqlalchemy import and_
        from sqlalchemy.orm import joinedload
        from app.models import StoreProduct
        from app.core.exceptions import ProductUnavailableException

        store = await self.db.get(Store, store_id)
        snapshot = getattr(item, "regional_snapshot", None)
        if store is not None and store.country_code == "GB":
            product = await self.db.get(Product, substitute_product_id)
            if product is None or product.review_status != "approved" or store.currency_code != "GBP":
                raise ProductUnavailableException(product_id=substitute_product_id, store_id=store_id)
            original_id = snapshot.product_id if snapshot is not None else None
            if original_id is None and item.store_product_id is not None:
                original_id = (await self.db.execute(select(StoreProduct.product_id)
                    .where(StoreProduct.id == item.store_product_id))).scalar_one_or_none()
            original = await self.db.get(Product, original_id) if original_id is not None else None
            try:
                quantity, unit = to_regional_base_quantity(original or product, item.required_quantity, item.unit)
                if canonical_base_unit(product) != unit:
                    raise ValueError("Substitute dimension differs from the original")
            except ValueError as exc:
                raise ProductUnavailableException(product_id=substitute_product_id, store_id=store_id) from exc
            offers = await load_regional_offers(self.db, {product.id}, store_id)
            quote = select_uk_offer_quote(offers, product_id=product.id, store_id=store_id, quantity=quantity, unit=unit, as_of=regional_pricing_date())
            # Explicitly labelled catalogue alternatives are user-approved.
            # They remain estimates, with no offer ID or store-stock claim.
            if quote is None and not is_uk_generic_seed(product, country_code='GB'):
                raise ProductUnavailableException(product_id=substitute_product_id, store_id=store_id)
            item.substituted_for = original_id
            apply_regional_item_quote(
                item, product=product, store_id=store_id,
                quantity=quantity, unit=unit, offers=offers, as_of=regional_pricing_date(),
            )
            item.is_checked = False
            return item

        # Znajdź nowy produkt w sklepie
        stmt = (
            select(StoreProduct)
            .where(
                and_(
                    StoreProduct.product_id == substitute_product_id,
                    StoreProduct.store_id == store_id,
                    StoreProduct.is_available.is_(True),
                    StoreProduct.withdrawn_at.is_(None),
                )
            )
            .options(joinedload(StoreProduct.product), joinedload(StoreProduct.department))
        )
        result = await self.db.execute(stmt)
        substitute_sp = result.scalar_one_or_none()

        if substitute_sp is None:
            raise ProductUnavailableException(
                product_id=substitute_product_id, store_id=store_id
            )

        # Pobierz oryginalny product_id
        orig_stmt = select(StoreProduct).options(joinedload(StoreProduct.product)).where(StoreProduct.id == item.store_product_id)
        orig_res = await self.db.execute(orig_stmt)
        original_sp = orig_res.scalar_one_or_none()
        if original_sp is None or original_sp.product is None:
            raise ProductUnavailableException(product_id=substitute_product_id, store_id=store_id)
        original, selected = original_sp.product, substitute_sp.product
        if selected is None or selected.review_status != "approved":
            raise ProductUnavailableException(product_id=substitute_product_id, store_id=store_id)
        # Preserve the original physical amount, then express it in the new
        # product's unit. Never reinterpret one old package as one gram.
        if original.unit == selected.unit == item.unit == "szt":
            native_quantity = float(item.required_quantity)
        else:
            try:
                if canonical_base_unit(original) != canonical_base_unit(selected):
                    raise ValueError("Different physical dimensions")
                amount = quantity_to_grams(original.name, float(item.required_quantity), item.unit,
                    original.serving_quantity, original.measure_options)
                native_quantity = grams_to_quantity(selected.name, amount, selected.unit,
                    selected.serving_quantity, selected.measure_options)
            except (ValueError, TypeError) as exc:
                raise ProductUnavailableException(product_id=substitute_product_id, store_id=store_id) from exc
        pack_quantity = float(selected.default_quantity or 0)
        if (not math.isfinite(native_quantity) or native_quantity <= 0
                or not math.isfinite(pack_quantity) or pack_quantity <= 0):
            raise ValueError("The product quantity cannot be converted safely")
        cost = Decimal(str(substitute_sp.price)) * math.ceil(native_quantity / pack_quantity)
        stored_quantity, stored_unit = Decimal(str(round(native_quantity, 3))), selected.unit
        if stored_quantity == 0 and original.unit != "szt":
            stored_quantity = Decimal(str(round(amount, 3)))
            stored_unit = canonical_base_unit(selected)
        if (not cost.is_finite() or not 0 <= cost <= Decimal("99999999.99")
                or not Decimal(0) < stored_quantity <= Decimal("9999999.999")):
            raise ValueError("The product quantity or cost exceeds the supported range")

        item.substituted_for = original_sp.product_id
        item.store_product_id = substitute_sp.id
        item.department_id = substitute_sp.department_id
        item.required_quantity = stored_quantity
        item.unit = stored_unit
        item.estimated_price = cost
        item.is_checked = False

        return item
    async def _regional_candidates(self, original, candidates, *, store_id, limit):
        try:
            unit = canonical_base_unit(original)
        except (ValueError, AttributeError):
            return []
        offers = await load_regional_offers(self.db, {product.id for product, _ in candidates}, store_id)
        result, generic = [], []
        for product, score in candidates:
            try:
                if product.review_status != "approved" or canonical_base_unit(product) != unit:
                    continue
            except ValueError:
                continue
            quote = select_uk_offer_quote(offers, product_id=product.id, store_id=store_id,
                quantity=Decimal("0.001"), unit=unit, as_of=regional_pricing_date())
            if quote is not None:
                result.append({"product": product, "similarity_score": score, "regional_quote": quote})
            elif is_uk_generic_seed(product, country_code='GB'):
                from app.services.uk_ons_pricing import quote_national_requirement
                estimate = quote_national_requirement(product, Decimal(100), unit,
                    store_id=store_id, as_of=regional_pricing_date())
                if estimate is not None:
                    generic.append({'product': product, 'similarity_score': score,
                                    'generic_reference': True, 'reference_quote': estimate})
        return (result + generic)[:limit]
