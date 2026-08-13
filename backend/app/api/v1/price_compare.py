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
from typing import List

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
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

class PriceCompareStoreResult(BaseModel):
    store_id: uuid.UUID
    store_name: str
    total_price: float
    is_cheapest: bool
    savings_vs_most_expensive: float
    items: List[PriceCompareItem]

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
            req_qty_grams = quantity_to_grams(product.name, req_qty_native, ingredient.unit)

            if product.id not in product_requirements:
                product_requirements[product.id] = {"product": product, "grams": req_qty_grams}
            else:
                product_requirements[product.id]["grams"] += req_qty_grams

    # ── Policz cenę w każdym sklepie — identyczna logika co lista zakupów ──
    store_results = []

    for store in stores:
        total_price = 0.0
        items = []

        for prod_id, req in product_requirements.items():
            product = req["product"]
            total_grams = req["grams"]

            store_product = (
                await db.execute(
                    select(StoreProduct).where(
                        StoreProduct.store_id == store.id,
                        StoreProduct.product_id == prod_id,
                    )
                )
            ).scalars().first()

            if not store_product:
                # Produkt niedostępny w tym sklepie — pomijamy w tej cenie,
                # tak samo jak robi to lista zakupów.
                continue

            product_unit = product.unit or "szt"
            default_qty_native = float(product.default_quantity or 1.0)
            default_qty_grams = quantity_to_grams(product.name, default_qty_native, product_unit)

            package_count = (
                math.ceil(total_grams / default_qty_grams) if default_qty_grams > 0 else 1
            )
            item_cost = round(float(store_product.price) * package_count, 2)
            total_price += item_cost

            items.append(PriceCompareItem(
                product_name=product.name,
                quantity_needed=round(grams_to_quantity(product.name, total_grams, product_unit), 2),
                unit=product_unit,
                price_in_store=item_cost,
                store_brand_name=store_product.store_brand_name,
            ))

        store_results.append({
            "store_id": store.id,
            "store_name": store.name,
            "total_price": round(total_price, 2),
            "items": items,
        })

    if not store_results:
        return []

    store_results.sort(key=lambda x: x["total_price"])
    cheapest_price = store_results[0]["total_price"]
    most_expensive_price = max(res["total_price"] for res in store_results)

    final_results = []
    for res in store_results:
        final_results.append(
            PriceCompareStoreResult(
                store_id=res["store_id"],
                store_name=res["store_name"],
                total_price=res["total_price"],
                is_cheapest=(res["total_price"] == cheapest_price and res["total_price"] > 0),
                savings_vs_most_expensive=round(most_expensive_price - res["total_price"], 2),
                items=res["items"],
            )
        )

    return final_results
