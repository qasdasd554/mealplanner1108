"""Reguły częstotliwości kontekstowych ofert Premium."""

from datetime import datetime, timedelta


# Oferta jest kontekstowa i pojawia się dopiero po wykonaniu działania, które
# pokazuje wartość Premium. Zatwierdzony limit: 24 godziny na konto,
# wspólny dla PL/GB, wszystkich kontekstów i urządzeń.
PREMIUM_OFFER_COOLDOWN = timedelta(hours=24)
PREMIUM_OFFER_CONTEXTS = {
    "recipe",
    "meal_plan",
    "barcode_scanner",
    "shopping_list",
    "pantry",
    "journal",
}


def premium_offer_next_eligible_at(last_shown_at: datetime) -> datetime:
    """Zwraca najwcześniejszy moment ponownego pokazania oferty."""

    return last_shown_at + PREMIUM_OFFER_COOLDOWN


def is_premium_offer_due(
    last_shown_at: datetime | None,
    *,
    now: datetime,
) -> bool:
    """Czy minął globalny odstęp 24 godzin między ofertami."""

    return (
        last_shown_at is None
        or premium_offer_next_eligible_at(last_shown_at) <= now
    )
