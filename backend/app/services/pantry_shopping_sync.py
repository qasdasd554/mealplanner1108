"""Uzgadnia otwarte listy zakupów z aktualną zawartością spiżarni."""

from __future__ import annotations

import math
import uuid
from decimal import Decimal

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models import MealPlan, PantryItem, Product, ShoppingList, ShoppingListItem
from app.services.nutrition_calculator import grams_to_quantity, quantity_to_grams
from app.services.shopping_list_builder import pantry_coverage_grams


def split_required_quantity(
    product: Product, rows: list[ShoppingListItem], pantry: PantryItem | None
) -> tuple[Decimal, Decimal]:
    """Zwraca (w spiżarni, do kupienia) w jednostce pierwszej pozycji.

    Sumujemy także istniejące pozycje spiżarniane, więc ponowne wywołanie
    nie zmniejsza zapotrzebowania po raz drugi.
    """
    unit = rows[0].unit
    required_grams = sum(
        quantity_to_grams(product.name, float(row.required_quantity), row.unit)
        for row in rows
    )
    covered_grams = pantry_coverage_grams(
        product.name, required_grams, pantry, product.unit
    )
    covered = Decimal(str(grams_to_quantity(product.name, covered_grams, unit)))
    required = Decimal(str(grams_to_quantity(product.name, required_grams, unit)))
    covered = min(required, max(Decimal(0), covered.quantize(Decimal("0.001"))))
    return covered, required - covered


async def sync_product_in_shopping_lists(
    db: AsyncSession, user_id: uuid.UUID, product_id: uuid.UUID
) -> None:
    """Przesuwa produkt do/z «W spiżarni» na otwartych listach właściciela.

    Dla częściowego stanu spiżarni pozostawia niedobór jako pozycję zakupową.
    Nie rusza list ukończonych ani scalonych.
    """
    product = await db.get(Product, product_id)
    if product is None:
        return
    pantry = (await db.execute(
        select(PantryItem).where(
            PantryItem.user_id == user_id, PantryItem.product_id == product_id
        )
    )).scalar_one_or_none()
    lists = (await db.execute(
        select(ShoppingList)
        .join(MealPlan, ShoppingList.meal_plan_id == MealPlan.id)
        .where(
            MealPlan.user_id == user_id,
            ShoppingList.status.notin_(("completed", "merged")),
        )
        .options(
            selectinload(ShoppingList.items)
            .selectinload(ShoppingListItem.store_product)
        )
    )).scalars().all()

    for shopping_list in lists:
        rows = [
            item for item in shopping_list.items
            if (
                item.store_product is not None
                and item.store_product.product_id == product_id
            ) or (
                item.store_product_id is None
                and item.custom_name is not None
                and item.custom_name.strip().casefold() == product.name.strip().casefold()
            )
        ]
        if not rows:
            continue

        covered, purchase = split_required_quantity(product, rows, pantry)
        pantry_row = next((row for row in rows if row.is_from_pantry), None)
        purchase_row = next((row for row in rows if not row.is_from_pantry), None)
        template = rows[0]

        def new_row() -> ShoppingListItem:
            return ShoppingListItem(
                shopping_list_id=shopping_list.id,
                store_product_id=template.store_product_id,
                custom_name=template.custom_name,
                unit=template.unit,
                is_generated=template.is_generated,
                substituted_for=template.substituted_for,
            )

        retained: list[ShoppingListItem] = []
        if covered > 0:
            row = pantry_row or new_row()
            row.required_quantity = covered
            row.is_from_pantry = True
            row.is_checked = True
            row.estimated_price = Decimal("0.00")
            row.department_id = None
            db.add(row)
            retained.append(row)

        if purchase > 0:
            row = purchase_row or new_row()
            row.required_quantity = purchase
            row.is_from_pantry = False
            row.is_checked = purchase_row.is_checked if purchase_row else False
            store_product = row.store_product or template.store_product
            if store_product is not None:
                row.department_id = store_product.department_id
                package_grams = quantity_to_grams(
                    product.name, float(product.default_quantity or 1), product.unit
                )
                needed_grams = quantity_to_grams(product.name, float(purchase), row.unit)
                packages = math.ceil(needed_grams / package_grams) if package_grams > 0 else 1
                row.estimated_price = (store_product.price * packages).quantize(Decimal("0.01"))
            else:
                row.department_id = None
                row.estimated_price = None
            db.add(row)
            retained.append(row)

        for row in rows:
            if row not in retained:
                await db.delete(row)
