"""Schematy Pydantic v2 dla list zakupów."""

from __future__ import annotations

import uuid
from datetime import date, datetime

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
    is_from_pantry: bool = False
    substituted_for_name: str | None = None
    currency_code: str = "PLN"
    price_is_estimated: bool = False
    quote_status: str | None = None
    package_quantity: float | None = None
    package_unit: str | None = None
    package_count: int | None = None
    purchased_quantity: float | None = None
    regional_offer_id: uuid.UUID | None = None
    price_source: dict | None = None
    pricing_as_of: date | None = None

    @model_validator(mode="before")
    @classmethod
    def get_related_fields(cls, data):
        snapshot = getattr(data, "regional_snapshot", None)
        if snapshot is not None:
            quote = snapshot.quote_data or {}
            pantry = bool(getattr(data, "is_from_pantry", False))
            return {
                "id": data.id, "product_id": snapshot.product_id,
                "product_name": snapshot.name_en, "brand": None,
                "department_name": "In pantry" if pantry else "Other",
                "department_sort_order": 10_000 if pantry else 999,
                "required_quantity": data.required_quantity, "unit": data.unit,
                "estimated_price": data.estimated_price,
                "is_checked": data.is_checked, "is_from_pantry": pantry,
                "substituted_for_name": None,
                "currency_code": "GBP", "quote_status": snapshot.quote_status,
                "price_is_estimated": quote.get("price_is_estimated", False),
                "package_quantity": quote.get("package_quantity"),
                "package_unit": quote.get("package_unit"),
                "package_count": quote.get("package_count"),
                "purchased_quantity": quote.get("purchased_quantity"),
                "regional_offer_id": snapshot.offer_id,
                "price_source": quote.get("price_source"),
                "pricing_as_of": snapshot.pricing_as_of,
            }
        if hasattr(data, "store_product") and data.store_product is not None:
            prod = data.store_product.product
            dept = data.department
            # Marka własna sklepu (np. "Mleczna Dolina") ma pierwszeństwo
            # przed ogólną marką produktu (prod.brand — zwykle pusta,
            # bo nasz katalog trzyma produkty jako generyczne, wspólne
            # dla wszystkich sklepów). Dzięki temu lista zakupów pokazuje
            # realną nazwę, pod jaką kupisz dany produkt w TYM konkretnym
            # sklepie.
            # An old store-product link may retain canonical identity after
            # switching to an unpriced shop; it is not that shop's own brand.
            brand = ((data.store_product.store_brand_name if data.estimated_price is not None else None)
                     or (prod.brand if prod else None))
            return {
                "id": data.id,
                "product_id": prod.id if prod else None,
                "product_name": prod.name if prod else "Nieznany produkt",
                "brand": brand,
                "department_name": "W spiżarni" if getattr(data, "is_from_pantry", False) else (
                    dept.name if dept else "Inne"
                ),
                "department_sort_order": 10_000 if getattr(data, "is_from_pantry", False) else (
                    dept.sort_order if dept else 99
                ),
                "required_quantity": data.required_quantity,
                "unit": data.unit,
                "estimated_price": data.estimated_price,
                "is_checked": data.is_checked,
                "is_from_pantry": getattr(data, "is_from_pantry", False),
                "substituted_for_name": (
                    data.substituted_for_product.name
                    if getattr(data, "substituted_for_product", None) is not None
                    else None
                ),
            }
        if getattr(data, "custom_name", None):
            return {
                "id": data.id,
                "product_id": None,
                "product_name": data.custom_name,
                "brand": None,
                "department_name": "W spiżarni" if getattr(data, "is_from_pantry", False) else "Inne",
                "department_sort_order": 10_000 if getattr(data, "is_from_pantry", False) else 999,
                "required_quantity": data.required_quantity,
                "unit": data.unit,
                "estimated_price": data.estimated_price if getattr(data, "is_from_pantry", False) else None,
                "is_checked": data.is_checked,
                "is_from_pantry": getattr(data, "is_from_pantry", False),
                "substituted_for_name": None,
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
    currency_code: str = "PLN"
    has_unpriced_items: bool = False
    price_is_estimated: bool = False

    @model_validator(mode="before")
    @classmethod
    def get_related_fields(cls, data):
        if hasattr(data, "store") and data.store is not None:
            if getattr(data.store, "country_code", "PL") == "GB":
                grouped = {}
                total = 0.0
                missing = estimated = False
                for item in (data.items or []):
                    response = ShoppingListItemResponse.model_validate(item)
                    if response.currency_code != "GBP":
                        # Legacy free-text rows remain visible, not valued as PLN.
                        response = response.model_copy(update={
                            "currency_code": "GBP", "estimated_price": None,
                            "quote_status": "unpriced", "department_name": "Other",
                        })
                    grouped.setdefault(response.department_name or "Other", []).append(response)
                    if not response.is_from_pantry and response.estimated_price is None:
                        missing = True
                    total += response.estimated_price or 0
                    estimated = estimated or response.price_is_estimated
                pantry_rows = grouped.pop("In pantry", None)
                if pantry_rows is not None:
                    grouped["In pantry"] = pantry_rows
                return {
                    "id": data.meal_plan_id, "meal_plan_id": data.meal_plan_id,
                    "store_id": data.store_id, "store_name": data.store.name,
                    "status": data.status, "created_at": data.created_at,
                    "total_estimated_price": None if missing else round(total, 2),
                    "items_by_department": grouped, "currency_code": "GBP",
                    "has_unpriced_items": missing, "price_is_estimated": estimated,
                }
            items_by_dept = {}
            total_price = 0.0
            missing_prices = False
            for item in (data.items or []):
                dept_name = (
                    "W spiżarni" if getattr(item, "is_from_pantry", False) else
                    item.department.name if item.department else "Inne"
                )
                if dept_name not in items_by_dept:
                    items_by_dept[dept_name] = []
                items_by_dept[dept_name].append(item)
                if not getattr(item, "is_from_pantry", False) and item.estimated_price is None:
                    missing_prices = True
                if item.estimated_price:
                    total_price += float(item.estimated_price)
            pantry_items = items_by_dept.pop("W spiżarni", None)
            if pantry_items is not None:
                items_by_dept["W spiżarni"] = pantry_items

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
                "total_estimated_price": None if missing_prices else round(total_price, 2),
                "has_unpriced_items": missing_prices,
                "items_by_department": items_by_dept,
                "created_at": data.created_at,
            }
        return data
