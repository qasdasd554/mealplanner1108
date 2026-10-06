"""Reguły częstotliwości kontekstowych ofert Premium."""

from datetime import datetime, timedelta


# Oferta jest kontekstowa i pojawia się dopiero po wykonaniu działania, które
# pokazuje wartość Premium. Dwudniowy odstęp pozwala ją przypominać częściej,
# ale nadal chroni użytkownika przed wyskakiwaniem przy każdej wizycie.
PREMIUM_OFFER_COOLDOWN = timedelta(days=2)
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
    """Czy minął globalny, dwudniowy odstęp między ofertami."""

    return (
        last_shown_at is None
        or premium_offer_next_eligible_at(last_shown_at) <= now
    )
