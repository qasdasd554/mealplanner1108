"""Schematy Pydantic v2 dla przepisów, tagów i składników."""

from __future__ import annotations

import uuid
from datetime import datetime
from decimal import Decimal

from pydantic import BaseModel, ConfigDict

from app.services.nutrition_calculator import quantity_to_grams


class RecipeIngredientCreate(BaseModel):
    """Dane składnika przy tworzeniu przepisu."""

    product_id: uuid.UUID
    quantity: float
    unit: str
    is_optional: bool = False


from pydantic import BaseModel, ConfigDict, field_validator, model_validator


class RecipeIngredientResponse(BaseModel):
    """Odpowiedź API — składnik przepisu."""

    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    product_id: uuid.UUID
    product_name: str
    quantity: float
    unit: str
    is_optional: bool
    kcal: int | None = None

    @model_validator(mode="before")
    @classmethod
    def get_product_name(cls, data):
        if hasattr(data, "product") and data.product is not None:
            kcal = None
            if data.product.nutrition_per_100 and "kcal" in data.product.nutrition_per_100:
                try:
                    kcal_per_100 = float(data.product.nutrition_per_100["kcal"])
                    weight = quantity_to_grams(
                        data.product.name, float(data.quantity), data.unit
                    )
                    kcal = int(round(kcal_per_100 * (weight / 100.0)))
                except:
                    pass

            return {
                "id": data.id,
                "product_id": data.product_id,
                "product_name": data.product.name,
                "quantity": data.quantity,
                "unit": data.unit,
                "is_optional": data.is_optional,
                "kcal": kcal,
            }
        return data


class RecipeBase(BaseModel):
    """Wspólne pola przepisu."""

    name: str
    description: str | None = None
    cuisine: str | None = None
    meal_type: str
    prep_time_min: int | None = None
    cook_time_min: int | None = None
    servings: int = 2
    difficulty: str = "łatwy"


class RecipeCreate(RecipeBase):
    """Dane wymagane do utworzenia przepisu."""

    tags: list[str] = []
    ingredients: list[RecipeIngredientCreate] = []


class RecipeResponse(RecipeBase):
    """Odpowiedź API — pełne dane przepisu."""

    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    nutrition_total: dict | None = None
    image_url: str | None = None
    is_active: bool
    tags: list[str] = []
    ingredients: list[RecipeIngredientResponse] = []
    created_at: datetime

    @field_validator("tags", mode="before")
    @classmethod
    def serialize_tags(cls, v):
        if isinstance(v, list):
            return [t.tag if hasattr(t, "tag") else t for t in v]
        return v

    @model_validator(mode="before")
    @classmethod
    def ensure_nutrition(cls, data):
        if not getattr(data, "nutrition_total", None) and hasattr(data, "ingredients"):
            total = {"kcal": 0, "protein": 0, "fat": 0, "carbs": 0, "fiber": 0}
            for ing in data.ingredients:
                prod = getattr(ing, "product", None)
                if prod and prod.nutrition_per_100:
                    try:
                        qty = float(ing.quantity)
                        unit = getattr(ing, "unit", "g")
                        w = quantity_to_grams(prod.name, qty, unit)
                        for k in total:
                            total[k] += float(prod.nutrition_per_100.get(k, 0) or 0) * (w / 100.0)
                    except:
                        pass
            if any(v > 0 for v in total.values()):
                # Obejście problemu ze zmianą obiektu SQLAlchemy - zwracamy dict z oryginalnymi wartościami
                res = {k: getattr(data, k) for k in data.__table__.columns.keys() if hasattr(data, k)}
                res["tags"] = data.tags
                res["ingredients"] = data.ingredients
                res["nutrition_total"] = {k: round(v, 1) for k, v in total.items()}
                return res
        return data
