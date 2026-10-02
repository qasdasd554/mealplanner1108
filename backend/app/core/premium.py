"""Jedno źródło prawdy dla aktywnego dostępu Premium.

Zakupy są weryfikowane po stronie serwera w Apple App Store lub Google
Play, a zapisany status jest okresowo synchronizowany przez
``app.services.subscription_sync``. Sama flaga ``is_premium`` nigdy nie
wystarcza: płatny produkt musi mieć również przyszłą datę wygaśnięcia.
"""

from __future__ import annotations

from datetime import datetime, timezone

from app.models.user import User

PAID_SUBSCRIPTION_PRODUCT_IDS = {
    "premium_weekly_v2",
    "premium_monthly",
    "premium_yearly",
}


def is_premium_active(user: User) -> bool:
    """Zwraca True, jeśli konto ma AKTYWNY status premium.

    Administratorzy (role="admin") mają dostęp do funkcji premium
    automatycznie — zgodnie z pierwotnym założeniem, że admin ma pełne
    uprawnienia do wszystkiego w aplikacji, nie tylko do moderacji
    komentarzy. Nie trzeba osobno ustawiać is_premium na koncie admina.

    Poza tym uwzględnia datę wygaśnięcia — jeśli `premium_expires_at` jest
    ustawione i minęło, traktujemy konto jako NIE-premium, nawet jeśli
    flaga `is_premium` wciąż jest ustawiona na True (na wypadek, gdyby
    proces odnawiania/wygaszania subskrypcji jeszcze nie zdążył
    zaktualizować tej flagi). `premium_expires_at = None` oznacza brak
    terminu wygaśnięcia (np. jednorazowy, bezterminowy zakup, jeśli
    kiedyś taki wprowadzimy).
    """
    if user.role == "admin":
        return True
    if not user.is_premium:
        return False
    # Płatna subskrypcja zawsze ma konkretny koniec okresu rozliczeniowego.
    # Brak daty w odpowiedzi sklepu jest błędem danych, a nie zakupem
    # bezterminowym. Ręczne dostępy administracyjne (bez identyfikatora
    # płatnego produktu) nadal mogą świadomie nie mieć terminu.
    if (
        user.premium_product_id in PAID_SUBSCRIPTION_PRODUCT_IDS
        and user.premium_expires_at is None
    ):
        return False
    if user.premium_expires_at is not None and user.premium_expires_at <= datetime.now(
        timezone.utc
    ):
        return False
    return True
