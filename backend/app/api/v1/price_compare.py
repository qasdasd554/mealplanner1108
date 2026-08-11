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

router = APIRouter()

class PriceCompareItem(BaseModel):
    product_name: str
    quantity_needed: float
    unit: str
    price_in_store: float

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
    # UWAGA: ten endpoint był napisany synchronicznie na sesji asynchronicznej
    # (`def`, `db.get`, `db.execute(...).scalars()`), przez co zawsze kończył
    # się błędem 500. Poniżej wersja asynchroniczna; relacje ładowane są z góry
    # (selectinload), bo leniwe doczytywanie w trybie async rzuca MissingGreenlet.
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

    # Fetch all stores
    stores = (await db.execute(select(Store))).scalars().all()
    if not stores:
        return []

    # Calculate required quantities per product
    # MealPlan -> MealPlanEntry -> Recipe -> RecipeIngredient -> Product
    product_requirements = {} # product_id -> { "product": Product, "quantity": total_quantity_needed, "unit": unit }

    # Fetch entries with relationships eagerly
    entries = meal_plan.entries
    for entry in entries:
        recipe = entry.recipe
        if not recipe:
            continue
        # Model ma pole `servings_multiplier`, nie `servings`.
        entry_multiplier = float(entry.servings_multiplier or 1)
        servings_multiplier = (
            entry_multiplier / float(recipe.servings) if recipe.servings else entry_multiplier
        )
        
        for ingredient in recipe.ingredients:
            product = ingredient.product
            if not product:
                continue
            req_qty = float(ingredient.quantity) * servings_multiplier
            
            if product.id not in product_requirements:
                product_requirements[product.id] = {
                    "product": product,
                    "quantity": req_qty,
                    "unit": ingredient.unit
                }
            else:
                # Assuming units match for the same product across recipes, or we just sum it (simplified)
                product_requirements[product.id]["quantity"] += req_qty

    # Calculate price for each store
    store_results = []
    
    for store in stores:
        total_price = 0.0
        items = []
        
        # We need to get StoreProduct for each required product in this store
        for prod_id, req in product_requirements.items():
            product = req["product"]
            req_qty = req["quantity"]
            
            store_product = (
                await db.execute(
                    select(StoreProduct).where(
                        StoreProduct.store_id == store.id,
                        StoreProduct.product_id == prod_id,
                    )
                )
            ).scalars().first()
            
            if store_product:
                # Calculate cost
                # simplified calculation: cost = (req_qty / default_quantity) * store_product.price
                default_qty = float(product.default_quantity) if product.default_quantity else 1.0
                
                # Check if units match, if not, simplistic conversion (e.g. g to kg if product is kg)
                # In real scenario, more complex conversion is needed
                calc_qty = req_qty
                if req["unit"] == "g" and product.unit == "kg":
                    calc_qty = req_qty / 1000.0
                elif req["unit"] == "kg" and product.unit == "g":
                    calc_qty = req_qty * 1000.0
                elif req["unit"] == "ml" and product.unit == "l":
                    calc_qty = req_qty / 1000.0
                elif req["unit"] == "l" and product.unit == "ml":
                    calc_qty = req_qty * 1000.0

                item_cost = (calc_qty / default_qty) * float(store_product.price)
                total_price += item_cost
                
                items.append(PriceCompareItem(
                    product_name=product.name,
                    quantity_needed=req_qty,
                    unit=req["unit"],
                    price_in_store=item_cost
                ))
            else:
                # Product not available in this store, handle appropriately? 
                # For now just continue, meaning it's missing from the price calculation.
                pass
                
        store_results.append({
            "store_id": store.id,
            "store_name": store.name,
            "total_price": total_price,
            "items": items
        })

    if not store_results:
        return []

    # Determine cheapest and most expensive
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
                savings_vs_most_expensive=most_expensive_price - res["total_price"],
                items=res["items"]
            )
        )

    return final_results
