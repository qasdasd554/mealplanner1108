"""Schematy Pydantic dla promocji sklepowych."""

import uuid
from datetime import date, datetime
from decimal import Decimal

from pydantic import BaseModel, ConfigDict


class PromotionResponse(BaseModel):
    """Odpowiedź API — pojedyncza promocja."""

    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    product_name: str
    store_name: str
    regular_price: Decimal
    promo_price: Decimal
    promo_type: str
    promo_description: str | None = None
    valid_from: date
    valid_until: date
    requires_loyalty_card: bool
    savings: Decimal
    savings_percent: int
    review_status: str = "approved"
    created_at: datetime
