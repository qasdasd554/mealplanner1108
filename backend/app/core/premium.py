"""Pomocnicze funkcje sprawdzania statusu premium.

Fundament pod płatną subskrypcję — samo sprawdzanie statusu jest już w
pełni gotowe i używane w limitach/funkcjach premium. To, czego na razie
BRAKUJE, to rzeczywiste POŁĄCZENIE z Google Play Billing (weryfikacja
zakupu i automatyczne ustawianie is_premium/premium_expires_at po stronie
serwera) — to osobny, większy kawałek pracy wymagający dodatkowej
konfiguracji w Google Cloud (podobnej do tego, co omawialiśmy przy
Firebase), i na razie status premium ustawia się ręcznie w bazie danych,
dokładnie tak jak rolę administratora.
"""

from __future__ import annotations

from datetime import datetime, timezone

from app.models.user import User


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
    if user.premium_expires_at is not None and user.premium_expires_at < datetime.now(timezone.utc):
        return False
    return True
