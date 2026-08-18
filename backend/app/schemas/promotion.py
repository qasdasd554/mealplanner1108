"""Schematy Pydantic dla promocji sklepowych."""

import uuid
from datetime import date, datetime

from pydantic import BaseModel, ConfigDict


class PromotionResponse(BaseModel):
    """Odpowiedź API — pojedyncza promocja."""

    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    product_name: str
    store_name: str
    # UWAGA (naprawa): wcześniej te pola były typu Decimal — Pydantic
    # domyślnie serializuje Decimal do JSON jako STRING (żeby nie tracić
    # precyzji), nie jako liczbę, np. `"regular_price": "5.99"` zamiast
    # `"regular_price": 5.99`. Flutter po stronie klienta robił
    # `json['regular_price'] as num?`, co przy stringu rzucało wyjątkiem
    # ("type 'String' is not a subtype of type 'num?'") — to właśnie ten
    # napis użytkownik widział zamiast promocji. Reszta schematów w tym
    # projekcie (plany posiłków, listy zakupów) od razu używa `float`
    # z dokładnie tego powodu — ujednolicono do tego samego wzorca.
    regular_price: float
    promo_price: float
    promo_type: str
    promo_description: str | None = None
    valid_from: date
    valid_until: date
    requires_loyalty_card: bool
    savings: float
    savings_percent: int
    review_status: str = "approved"
    created_at: datetime
