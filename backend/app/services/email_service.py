"""Wysyłka e-maili (weryfikacja konta, reset hasła) przez Resend.

Dlaczego Resend: czysty, prosty REST API, 3000 darmowych maili miesięcznie
na stałe (nie okres próbny), zero konfiguracji SMTP. Backend wywołuje
bezpośrednio ich endpoint HTTP przez httpx — dokładnie ten sam wzorzec,
którego już używamy dla Gemini i Google Play Developer API, więc nie
dodajemy żadnej nowej zależności/SDK tylko dla tego jednego serwisu.
"""

from __future__ import annotations

import logging

import httpx

from app.core.config import settings

logger = logging.getLogger(__name__)

_RESEND_API_URL = "https://api.resend.com/emails"


class EmailSendError(Exception):
    """Wysyłka maila się nie powiodła — brak konfiguracji albo błąd Resend."""


async def _send_code_email(
    to_email: str,
    code: str,
    display_name: str | None,
    *,
    subject: str,
    intro_line: str,
    footer_line: str,
) -> None:
    """Wspólna logika wysyłki maila z 6-cyfrowym kodem — używana zarówno
    przez weryfikację konta, jak i reset hasła, żeby nie duplikować
    wywołania HTTP do Resend i wyglądu maila w dwóch miejscach."""
    if not settings.RESEND_API_KEY:
        raise EmailSendError(
            "Wysyłka e-maili nie jest skonfigurowana na serwerze (brak RESEND_API_KEY)."
        )

    greeting = f"Cześć {display_name}!" if display_name else "Cześć!"
    html = f"""
    <div style="font-family: -apple-system, sans-serif; max-width: 480px; margin: 0 auto;">
        <h2 style="color: #10B981;">Meal Planner Polska</h2>
        <p>{greeting}</p>
        <p>{intro_line}</p>
        <p style="font-size: 32px; font-weight: bold; letter-spacing: 8px;
                   background: #F3F4F6; padding: 16px 24px; border-radius: 12px;
                   text-align: center;">{code}</p>
        <p style="color: #6B7280; font-size: 14px;">{footer_line}</p>
    </div>
    """

    async with httpx.AsyncClient(timeout=15.0) as client:
        try:
            response = await client.post(
                _RESEND_API_URL,
                headers={
                    "Authorization": f"Bearer {settings.RESEND_API_KEY}",
                    "Content-Type": "application/json",
                },
                json={
                    "from": settings.RESEND_FROM_EMAIL,
                    "to": [to_email],
                    "subject": subject,
                    "html": html,
                },
            )
        except httpx.HTTPError as exc:
            logger.warning("Błąd połączenia z Resend przy wysyłce kodu: %s", exc)
            raise EmailSendError("Nie udało się połączyć z serwisem wysyłki e-maili.") from exc

    if response.status_code >= 300:
        logger.warning(
            "Resend zwrócił błąd (status %d) przy wysyłce kodu do %s: %s",
            response.status_code,
            to_email,
            response.text[:300],
        )
        raise EmailSendError("Serwis wysyłki e-maili zwrócił błąd.")


async def send_verification_email(to_email: str, code: str, display_name: str | None) -> None:
    """Wysyła e-mail z kodem weryfikacyjnym (6 cyfr) przy rejestracji.

    Rzuca EmailSendError, jeśli wysyłka się nie powiedzie — WYWOŁUJĄCY
    kod (endpoint /auth/register) celowo NIE przerywa całej rejestracji
    z tego powodu (konto i tak się tworzy), tylko loguje błąd — inaczej
    chwilowa awaria Resend uniemożliwiałaby rejestrację w ogóle. Użytkownik
    może zawsze poprosić o ponowne wysłanie kodu (/auth/resend-code).
    """
    await _send_code_email(
        to_email,
        code,
        display_name,
        subject="Twój kod weryfikacyjny — Meal Planner Polska",
        intro_line="Twój kod weryfikacyjny do potwierdzenia konta:",
        footer_line=(
            "Kod jest ważny przez 15 minut. Jeśli to nie Ty próbowałeś/aś "
            "założyć konto, zignoruj tę wiadomość."
        ),
    )


async def send_password_reset_email(to_email: str, code: str, display_name: str | None) -> None:
    """Wysyła e-mail z kodem do zresetowania hasła."""
    await _send_code_email(
        to_email,
        code,
        display_name,
        subject="Reset hasła — Meal Planner Polska",
        intro_line="Otrzymaliśmy prośbę o reset hasła do Twojego konta. Twój kod:",
        footer_line=(
            "Kod jest ważny przez 15 minut. Jeśli to nie Ty prosiłeś/aś "
            "o reset hasła, zignoruj tę wiadomość — Twoje hasło pozostanie bez zmian."
        ),
    )

