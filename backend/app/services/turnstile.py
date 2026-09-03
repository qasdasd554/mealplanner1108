"""Weryfikacja tokenu Cloudflare Turnstile (bramka CAPTCHA przed
logowaniem i rejestracją).

Turnstile działa dwuetapowo: przeglądarka (u nas: WebView w aplikacji)
rozwiązuje wyzwanie i dostaje jednorazowy token, a serwer musi ten token
potwierdzić u Cloudflare. Sprawdzenie po stronie serwera jest
OBOWIĄZKOWE — bez niego token jest tylko napisem, który każdy może
podrobić, bo klient jest w pełni pod kontrolą atakującego.

Bramka jest WYŁĄCZONA, gdy `TURNSTILE_SECRET_KEY` jest puste. Dzięki temu
wdrożenie backendu nie psuje starszych wersji aplikacji, które nie wysyłają
jeszcze tokenu — włączasz ją dopiero, gdy nowa wersja jest już w sklepach.
"""

from __future__ import annotations

import logging

import httpx
from fastapi import HTTPException, status

from app.core.config import settings

logger = logging.getLogger(__name__)

_VERIFY_URL = "https://challenges.cloudflare.com/turnstile/v0/siteverify"


async def verify_turnstile_token(token: str | None, remote_ip: str | None = None) -> None:
    """Sprawdza token u Cloudflare. Nic nie zwraca — przy niepowodzeniu
    podnosi wyjątek HTTP, żeby wywołanie w endpoincie było jednolinijkowe.

    Raises:
        HTTPException 400: brak tokenu, gdy bramka jest włączona.
        HTTPException 403: token odrzucony przez Cloudflare (nieważny,
            zużyty albo wystawiony dla innej witryny).
    """
    if not settings.TURNSTILE_SECRET_KEY:
        return  # bramka wyłączona — patrz komentarz na górze pliku

    if not token or not token.strip():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Potwierdź, że nie jesteś robotem.",
        )

    payload = {"secret": settings.TURNSTILE_SECRET_KEY, "response": token}
    if remote_ip:
        payload["remoteip"] = remote_ip

    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.post(_VERIFY_URL, data=payload)
            response.raise_for_status()
            result = response.json()
    except httpx.HTTPError:
        # ŚWIADOMA DECYZJA: awaria Cloudflare NIE blokuje logowania.
        # Odwrotne zachowanie (odrzucać wszystko, gdy nie da się
        # zweryfikować) zamieniłoby awarię zewnętrznej usługi w całkowitą
        # niedostępność aplikacji. Ryzyko jest ograniczone, bo pozostają
        # limity liczby prób logowania (patrz app/core/rate_limit.py).
        logger.warning("Nie udało się zweryfikować tokenu Turnstile — przepuszczam żądanie.")
        return

    if not result.get("success"):
        logger.info("Turnstile odrzucił token: %s", result.get("error-codes"))
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Weryfikacja nie powiodła się. Spróbuj ponownie.",
        )
