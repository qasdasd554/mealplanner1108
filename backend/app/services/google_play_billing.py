"""Weryfikacja zakupów subskrypcji Google Play Billing po stronie serwera.

Dlaczego to w ogóle jest potrzebne: sam fakt, że aplikacja mobilna
"twierdzi", że użytkownik kupił subskrypcję, nie jest niczym wiarygodny —
zmodyfikowana wersja aplikacji (albo ktoś przechwytujący ruch sieciowy)
mogłaby po prostu wysłać "kupiłem premium" bez faktycznego zakupu. Jedyny
wiarygodny sposób to zapytać SAMO Google, przez Google Play Developer API,
czy dany token zakupu jest prawdziwy i aktywny — stąd ten moduł.

Używa konta serwisowego Google Cloud (patrz przewodnik konfiguracji
płatności i zmienna GOOGLE_PLAY_SERVICE_ACCOUNT_JSON) do podpisania
żądania i wywołania:
https://developers.google.com/android-publisher/api-ref/rest/v3/purchases.subscriptionsv2/get
"""

from __future__ import annotations

import asyncio
import json
import logging
from datetime import datetime

import httpx
from google.auth.transport.requests import Request as GoogleAuthRequest
from google.oauth2 import service_account

from app.core.config import settings

logger = logging.getLogger(__name__)

_ANDROID_PUBLISHER_SCOPE = "https://www.googleapis.com/auth/androidpublisher"

# Stany subskrypcji, przy których użytkownik nadal POWINIEN mieć dostęp —
# ACTIVE to oczywiste, IN_GRACE_PERIOD to sytuacja, gdy płatność się nie
# powiodła, ale Google wciąż próbuje ponowić obciążenie i celowo NIE
# odcina dostępu w tym okresie (żeby nie karać użytkownika za np.
# wygasłą kartę, zanim zdąży ją zaktualizować).
_ACTIVE_STATES = {"SUBSCRIPTION_STATE_ACTIVE", "SUBSCRIPTION_STATE_IN_GRACE_PERIOD"}


class PurchaseVerificationError(Exception):
    """Weryfikacja zakupu nie powiodła się — nieprawidłowy/nieznany token,
    brak konfiguracji, albo błąd komunikacji z Google."""


def _fetch_access_token_sync() -> str:
    """Część SYNCHRONICZNA (podpisywanie JWT kontem serwisowym i wymiana
    na token dostępu) — celowo wywoływana przez asyncio.to_thread, żeby
    nie zablokować pętli zdarzeń FastAPI (google-auth nie ma natywnego
    wsparcia dla async)."""
    if not settings.GOOGLE_PLAY_SERVICE_ACCOUNT_JSON:
        raise PurchaseVerificationError(
            "Weryfikacja płatności nie jest skonfigurowana na serwerze "
            "(brak GOOGLE_PLAY_SERVICE_ACCOUNT_JSON)."
        )
    try:
        info = json.loads(settings.GOOGLE_PLAY_SERVICE_ACCOUNT_JSON)
    except json.JSONDecodeError as exc:
        raise PurchaseVerificationError(
            "Nieprawidłowy format klucza konta serwisowego Google Play na serwerze."
        ) from exc

    credentials = service_account.Credentials.from_service_account_info(
        info, scopes=[_ANDROID_PUBLISHER_SCOPE]
    )
    credentials.refresh(GoogleAuthRequest())
    return credentials.token


async def verify_subscription_purchase(purchase_token: str, product_id: str) -> dict:
    """Weryfikuje token zakupu subskrypcji bezpośrednio u Google.

    Zwraca słownik: {"is_active": bool, "subscription_state": str,
    "expiry_time": datetime | None, "product_id": str | None}.

    Rzuca PurchaseVerificationError, jeśli weryfikacja się nie powiedzie
    (nieprawidłowy token, brak konfiguracji, błąd sieci/API).
    """
    if not settings.GOOGLE_PLAY_PACKAGE_NAME:
        raise PurchaseVerificationError(
            "Weryfikacja płatności nie jest skonfigurowana na serwerze "
            "(brak GOOGLE_PLAY_PACKAGE_NAME)."
        )
    if not purchase_token:
        raise PurchaseVerificationError("Brak tokenu zakupu do zweryfikowania.")

    access_token = await asyncio.to_thread(_fetch_access_token_sync)

    url = (
        "https://androidpublisher.googleapis.com/androidpublisher/v3/applications/"
        f"{settings.GOOGLE_PLAY_PACKAGE_NAME}/purchases/subscriptionsv2/tokens/{purchase_token}"
    )
    async with httpx.AsyncClient(timeout=15.0) as client:
        try:
            response = await client.get(url, headers={"Authorization": f"Bearer {access_token}"})
        except httpx.HTTPError as exc:
            logger.warning("Błąd połączenia przy weryfikacji zakupu: %s", exc)
            raise PurchaseVerificationError(
                "Nie udało się połączyć z Google w celu weryfikacji zakupu. Spróbuj ponownie."
            ) from exc

    if response.status_code == 404:
        raise PurchaseVerificationError("Nie znaleziono takiego zakupu u Google.")
    if response.status_code != 200:
        logger.warning(
            "Weryfikacja zakupu nieudana (status %d): %s",
            response.status_code,
            response.text[:300],
        )
        raise PurchaseVerificationError("Nie udało się zweryfikować zakupu u Google.")

    data = response.json()
    subscription_state = data.get("subscriptionState", "")
    is_active = subscription_state in _ACTIVE_STATES

    line_items = data.get("lineItems") or []
    expiry_time: datetime | None = None
    matched_product_id: str | None = None
    for item in line_items:
        # Dopasuj do KONKRETNEGO produktu, o który pytamy — subskrypcja
        # może w teorii mieć więcej niż jedną pozycję (np. z dodatkami),
        # a nas interesuje ta, którą użytkownik faktycznie kupił.
        if item.get("productId") == product_id:
            matched_product_id = item.get("productId")
            expiry_str = item.get("expiryTime")
            if expiry_str:
                expiry_time = datetime.fromisoformat(expiry_str.replace("Z", "+00:00"))
            break
    else:
        # Nie znaleziono dokładnego dopasowania po product_id — weź
        # pierwszą pozycję, jeśli w ogóle jakaś istnieje (lepsze to niż
        # całkiem odrzucić poprawny, ale nietypowo ustrukturyzowany zakup).
        if line_items:
            matched_product_id = line_items[0].get("productId")
            expiry_str = line_items[0].get("expiryTime")
            if expiry_str:
                expiry_time = datetime.fromisoformat(expiry_str.replace("Z", "+00:00"))

    return {
        "is_active": is_active,
        "subscription_state": subscription_state,
        "expiry_time": expiry_time,
        "product_id": matched_product_id,
    }


async def verify_consumable_purchase(purchase_token: str, product_id: str) -> dict:
    """Weryfikuje token zakupu produktu JEDNORAZOWEGO/konsumowalnego
    (np. pakiet punktów premium) — INNY endpoint Google Play niż
    subskrypcje, bo to fundamentalnie inny rodzaj produktu w ich API.

    Zwraca słownik: {"is_purchased": bool, "is_consumed": bool,
    "product_id": str | None}.

    UWAGA: samo zweryfikowanie zakupu jako "kupiony" NIE oznacza
    automatycznie, że wolno przyznać punkty — trzeba też sprawdzić
    is_consumed (żeby ten sam zakup nie mógł zostać "wymieniony na
    punkty" dwa razy) i PO przyznaniu punktów jawnie skonsumować zakup
    u Google (patrz consume_purchase poniżej) — inaczej Google Play
    automatycznie zwróci użytkownikowi pieniądze po ~3 dniach
    (wymóg Google dla niekonsumowanych zakupów).

    Rzuca PurchaseVerificationError, jeśli weryfikacja się nie powiedzie.
    """
    if not settings.GOOGLE_PLAY_PACKAGE_NAME:
        raise PurchaseVerificationError(
            "Weryfikacja płatności nie jest skonfigurowana na serwerze "
            "(brak GOOGLE_PLAY_PACKAGE_NAME)."
        )
    if not purchase_token:
        raise PurchaseVerificationError("Brak tokenu zakupu do zweryfikowania.")

    access_token = await asyncio.to_thread(_fetch_access_token_sync)

    url = (
        "https://androidpublisher.googleapis.com/androidpublisher/v3/applications/"
        f"{settings.GOOGLE_PLAY_PACKAGE_NAME}/purchases/products/{product_id}/tokens/{purchase_token}"
    )
    async with httpx.AsyncClient(timeout=15.0) as client:
        try:
            response = await client.get(url, headers={"Authorization": f"Bearer {access_token}"})
        except httpx.HTTPError as exc:
            logger.warning("Błąd połączenia przy weryfikacji zakupu punktów: %s", exc)
            raise PurchaseVerificationError(
                "Nie udało się połączyć z Google w celu weryfikacji zakupu. Spróbuj ponownie."
            ) from exc

    if response.status_code == 404:
        raise PurchaseVerificationError("Nie znaleziono takiego zakupu u Google.")
    if response.status_code != 200:
        logger.warning(
            "Weryfikacja zakupu punktów nieudana (status %d): %s",
            response.status_code,
            response.text[:300],
        )
        raise PurchaseVerificationError("Nie udało się zweryfikować zakupu u Google.")

    data = response.json()
    # purchaseState: 0 = zakupiono, 1 = anulowano, 2 = oczekujące
    # consumptionState: 0 = niekonsumowane, 1 = skonsumowane
    is_purchased = data.get("purchaseState") == 0
    is_consumed = data.get("consumptionState") == 1

    return {
        "is_purchased": is_purchased,
        "is_consumed": is_consumed,
        "product_id": product_id,
    }


async def consume_purchase(purchase_token: str, product_id: str) -> None:
    """Oznacza zakup jako "skonsumowany" u Google — WYMAGANE po
    przyznaniu punktów, inaczej Google Play automatycznie zwróci
    użytkownikowi pieniądze po ok. 3 dniach (standardowa zasada Google
    dla niekonsumowanych zakupów jednorazowych)."""
    access_token = await asyncio.to_thread(_fetch_access_token_sync)
    url = (
        "https://androidpublisher.googleapis.com/androidpublisher/v3/applications/"
        f"{settings.GOOGLE_PLAY_PACKAGE_NAME}/purchases/products/{product_id}/tokens/{purchase_token}:consume"
    )
    async with httpx.AsyncClient(timeout=15.0) as client:
        try:
            response = await client.post(url, headers={"Authorization": f"Bearer {access_token}"})
        except httpx.HTTPError as exc:
            logger.warning("Błąd połączenia przy konsumowaniu zakupu: %s", exc)
            raise PurchaseVerificationError(
                "Nie udało się potwierdzić zakupu u Google. Spróbuj ponownie."
            ) from exc

    if response.status_code not in (200, 204):
        logger.warning(
            "Konsumowanie zakupu nieudane (status %d): %s",
            response.status_code,
            response.text[:300],
        )
        raise PurchaseVerificationError("Nie udało się potwierdzić zakupu u Google.")
