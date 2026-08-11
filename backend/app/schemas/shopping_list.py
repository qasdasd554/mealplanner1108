"""Schematy Pydantic v2 dla list zakupów."""

from __future__ import annotations

import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict, model_validator


class ShoppingListItemResponse(BaseModel):
    """Odpowiedź API — pozycja na liście zakupów."""

    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    product_id: uuid.UUID | None = None
    product_name: str
    brand: str | None = None
    department_name: str | None = None
    department_sort_order: int | None = None
    required_quantity: float
    unit: str
    estimated_price: float | None = None
    is_checked: bool
    substituted_for_name: str | None = None

    @model_validator(mode="before")
    @classmethod
    def get_related_fields(cls, data):
        if hasattr(data, "store_product") and data.store_product is not None:
            prod = data.store_product.product
            dept = data.department
            return {
                "id": data.id,
                "product_id": prod.id if prod else None,
                "product_name": prod.name if prod else "Nieznany produkt",
                "brand": prod.brand if prod else None,
                "department_name": dept.name if dept else "Inne",
                "department_sort_order": dept.sort_order if dept else 99,
                "required_quantity": data.required_quantity,
                "unit": data.unit,
                "estimated_price": data.estimated_price,
                "is_checked": data.is_checked,
                "substituted_for_name": (
                    data.substituted_for_product.name
                    if getattr(data, "substituted_for_product", None) is not None
                    else None
                ),
            }
        return data


class ShoppingListResponse(BaseModel):
    """Odpowiedź API — pełna lista zakupów pogrupowana wg działów."""

    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    meal_plan_id: uuid.UUID
    store_id: uuid.UUID
    store_name: str
    status: str
    total_estimated_price: float | None = None
    items_by_department: dict[str, list[ShoppingListItemResponse]] = {}
    created_at: datetime

    @model_validator(mode="before")
    @classmethod
    def get_related_fields(cls, data):
        if hasattr(data, "store") and data.store is not None:
            items_by_dept = {}
            total_price = 0.0
            for item in (data.items or []):
                dept_name = item.department.name if item.department else "Inne"
                if dept_name not in items_by_dept:
                    items_by_dept[dept_name] = []
                items_by_dept[dept_name].append(item)
                if item.estimated_price:
                    total_price += float(item.estimated_price)
            
            return {
                # UWAGA: zwracamy meal_plan_id jako "id", ponieważ wszystkie endpointy
                # listy zakupów (/shopping-lists/{list_id}/...) identyfikują listę po ID
                # planu posiłków (relacja 1:1), a nie po własnym kluczu głównym ShoppingList.
                # Zwracanie tu data.id (PK listy) powodowało, że każda kolejna akcja
                # (zaznaczanie produktu, podmiana zamiennika, podsumowanie) kończyła się 404.
                "id": data.meal_plan_id,
                "meal_plan_id": data.meal_plan_id,
                "store_id": data.store_id,
                "store_name": data.store.name,
                "status": data.status,
                "total_estimated_price": round(total_price, 2),
                "items_by_department": items_by_dept,
                "created_at": data.created_at,
            }
        return data
