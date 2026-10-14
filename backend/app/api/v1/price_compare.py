"""Porównywanie cen planu posiłków między sklepami.

UWAGA (naprawa): suma tutaj wcześniej różniła się od sumy na liście
zakupów, bo liczono ją INACZEJ — tu proporcjonalnie do dokładnie
potrzebnej ilości (np. 0.3 opakowania = 30% ceny), a na liście zakupów
zaokrąglano W GÓRĘ do pełnych opakowań (bo tyle realnie się kupuje —
sklep nie sprzeda 30% kostki masła). Teraz obie strony liczą dokładnie
tak samo, korzystając z tych samych funkcji konwersji jednostek co
``ShoppingListBuilder``.
"""

import math
import uuid
from datetime import date
from typing import List

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.api.deps import get_current_user, get_db
from app.models.meal_plan import MealPlan, MealPlanEntry
from app.models.recipe import Recipe, RecipeIngredient
from app.models.product import Product, StoreProduct
from app.models.store import Store
from app.models.user import User
from app.services.nutrition_calculator import grams_to_quantity, quantity_to_grams

router = APIRouter()

class PriceCompareItem(BaseModel):
    product_name: str
    quantity_needed: float
    unit: str
    price_in_store: float
    # Marka własna sklepu dla tego produktu (np. "Mleczna Dolina"), jeśli
    # potwierdzona — puste, jeśli w tej kategorii sklep nie ma marki własnej.
    store_brand_name: str | None = None
    price_is_estimated: bool = True
    last_verified: date | None = None

class PriceCompareStoreResult(BaseModel):
    store_id: uuid.UUID
    store_name: str
    total_price: float
    is_cheapest: bool
    savings_vs_most_expensive: float
    items: List[PriceCompareItem]
    has_estimated_prices: bool = True
    is_complete: bool = True
    missing_products: List[str] = Field(default_factory=list)


def _positive_finite_float(value) -> float | None:
    """Nieznana/nieprawidłowa cena lub gramatura nie oznacza darmowego produktu."""
    try:
        number = float(value)
    except (TypeError, ValueError, OverflowError):
        return None
    return number if math.isfinite(number) and number > 0 else None

@router.get("/{meal_plan_id}", response_model=List[PriceCompareStoreResult])
async def compare_prices(
    meal_plan_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.execute(
        select(MealPlan)
        .where(MealPlan.id == meal_plan_id)
        .options(
            selectinload(MealPlan.entries)
            .selectinload(MealPlanEntry.recipe)
            .selectinload(Recipe.ingredients)
            .selectinload(RecipeIngredient.product)
        )
    )
    meal_plan = result.scalar_one_or_none()
    if not meal_plan:
        raise HTTPException(status_code=404, detail="Nie znaleziono planu posiłków")
    if meal_plan.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Brak uprawnień do tego planu posiłków")
    # Porównanie cen nie jest tylnym wejściem do usuniętego planu lub
    # płatnego archiwum; stosuje tę samą regułę co podgląd planu.
    from app.api.v1.meal_plans import _ensure_plan_access
    _ensure_plan_access(meal_plan, current_user)

    stores = (await db.execute(select(Store))).scalars().all()
    if not stores:
        return []

    # ── Agreguj wymagane ilości SKŁADNIKÓW we wspólnej bazie (gramy/ml) ──
    # Wcześniej sumowanie zakładało, że jednostki zawsze się zgadzają
    # ("Assuming units match... simplified") — kruche założenie. Konwersja
    # do wspólnej bazy (tak jak w ShoppingListBuilder) jest odporna na to,
    # że ten sam produkt może być użyty w różnych przepisach w różnych
    # jednostkach.
    product_requirements: dict[uuid.UUID, dict] = {}

    for entry in meal_plan.entries:
        recipe = entry.recipe
        if not recipe:
            continue
        # UWAGA: `servings_multiplier` zapisany na wpisie planu JEST JUŻ
        # finalnym mnożnikiem całego przepisu (np. 0.5 = pół przepisu,
        # 2.0 = podwójna porcja) — dokładnie tak samo liczy to
        # ShoppingListBuilder._aggregate_ingredients(). Wcześniej ten plik
        # DZIELIŁ go dodatkowo przez recipe.servings, co zaniżało ilości
        # (i cenę) względem listy zakupów — stąd różne sumy na obu ekranach
        # dla tego samego planu.
        servings_multiplier = float(entry.servings_multiplier or 1)

        for ingredient in recipe.ingredients:
            product = ingredient.product
            if not product:
                continue
            req_qty_native = float(ingredient.quantity) * servings_multiplier
            req_qty_grams = quantity_to_grams(
                product.name,
                req_qty_native,
                ingredient.unit,
                getattr(product, "serving_quantity", None),
                getattr(product, "measure_options", None),
            )

            if product.id not in product_requirements:
                product_requirements[product.id] = {
                    "product": product,
                    "grams": req_qty_grams,
                    "quantity_known": _positive_finite_float(req_qty_grams) is not None,
                }
            else:
                product_requirements[product.id]["grams"] += req_qty_grams
                if _positive_finite_float(req_qty_grams) is None:
                    product_requirements[product.id]["quantity_known"] = False

    if not product_requirements:
        return []

    # ── Policz cenę w każdym sklepie — identyczna logika co lista zakupów ──
    store_results = []

    # Pobierz ceny jednym zapytaniem zamiast wykonywać osobny SELECT dla
    # każdej pary sklep–produkt. Przy większej liście usuwa to setki rund
    # komunikacji z bazą bez zmiany sposobu liczenia ceny.
    store_product_by_pair: dict[tuple[uuid.UUID, uuid.UUID], StoreProduct] = {}
    if product_requirements:
        store_products = (
            await db.execute(
                select(StoreProduct).where(
                    StoreProduct.store_id.in_([store.id for store in stores]),
                    StoreProduct.product_id.in_(list(product_requirements)),
                )
            )
        ).scalars().all()
        store_product_by_pair = {
            (row.store_id, row.product_id): row for row in store_products
        }

    for store in stores:
        total_price = 0.0
        items = []
        missing_products = []

        for prod_id, req in product_requirements.items():
            product = req["product"]
            total_grams = req["grams"]

            store_product = store_product_by_pair.get((store.id, prod_id))

            if not store_product or not getattr(store_product, "is_available", True):
                missing_products.append(product.name)
                continue

            price = _positive_finite_float(store_product.price)
            total_grams = _positive_finite_float(total_grams)
            if price is None or total_grams is None or not req["quantity_known"]:
                missing_products.append(product.name)
                continue

            product_unit = product.unit or "szt"
            default_qty_native = _positive_finite_float(product.default_quantity)
            if default_qty_native is None:
                missing_products.append(product.name)
                continue
            default_qty_grams = quantity_to_grams(
                product.name,
                default_qty_native,
                product_unit,
                getattr(product, "serving_quantity", None),
                getattr(product, "measure_options", None),
            )

            default_qty_grams = _positive_finite_float(default_qty_grams)
            if default_qty_grams is None:
                # Brak masy opakowania nie może skutkować zakupem fikcyjnego
                # jednego opakowania ani sugerowaniem wiarygodnej sumy.
                missing_products.append(product.name)
                continue

            package_count = math.ceil(total_grams / default_qty_grams)
            item_cost = round(price * package_count, 2)
            total_price += item_cost

            items.append(PriceCompareItem(
                product_name=product.name,
                quantity_needed=round(
                    grams_to_quantity(
                        product.name,
                        total_grams,
                        product_unit,
                        getattr(product, "serving_quantity", None),
                        getattr(product, "measure_options", None),
                    ),
                    2,
                ),
                unit=product_unit,
                price_in_store=item_cost,
                store_brand_name=store_product.store_brand_name,
                price_is_estimated=getattr(store_product, "last_verified", None) is None,
                last_verified=getattr(store_product, "last_verified", None),
            ))

        store_results.append({
            "store_id": store.id,
            "store_name": store.name,
            "total_price": round(total_price, 2),
            "items": items,
            "has_estimated_prices": any(item.price_is_estimated for item in items),
            "is_complete": bool(product_requirements) and not missing_products,
            "missing_products": sorted(set(missing_products)),
        })

    if not store_results:
        return []

    # Nie porównuj części koszyka z całym koszykiem. Najpierw pokazujemy
    # pełne zestawy; brakujących cen nie wolno interpretować jako 0 zł.
    store_results.sort(key=lambda x: (not x["is_complete"], x["total_price"], x["store_name"]))
    complete_prices = [res["total_price"] for res in store_results if res["is_complete"]]
    cheapest_price = min(complete_prices) if complete_prices else None
    most_expensive_price = max(complete_prices) if complete_prices else None

    final_results = []
    for res in store_results:
        final_results.append(
            PriceCompareStoreResult(
                store_id=res["store_id"],
                store_name=res["store_name"],
                total_price=res["total_price"],
                is_cheapest=(res["is_complete"] and res["total_price"] == cheapest_price),
                savings_vs_most_expensive=(
                    round(most_expensive_price - res["total_price"], 2)
                    if res["is_complete"] and most_expensive_price is not None else 0.0
                ),
                items=res["items"],
                has_estimated_prices=res["has_estimated_prices"],
                is_complete=res["is_complete"],
                missing_products=res["missing_products"],
            )
        )

    return final_results
