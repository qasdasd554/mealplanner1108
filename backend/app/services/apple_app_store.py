"""Weryfikacja zakupów (subskrypcji i punktów) z App Store po stronie
serwera — odpowiednik google_play_billing.py, ale dla iOS.

Dlaczego to osobny plik, nie rozszerzenie google_play_billing.py: Apple
i Google mają architektonicznie RÓŻNE API — inny sposób uwierzytelniania
(Apple: JWT podpisany kluczem prywatnym .p8, ważny max. kilka minut na
każde zapytanie; Google: token OAuth z konta serwisowego), inny format
odpowiedzi (Apple zwraca JWS — podpisany token do zdekodowania — zamiast
zwykłego JSON), i Apple W OGÓLE NIE MA koncepcji "skonsumowania" zakupu
jednorazowego (patrz app/models/processed_apple_purchase.py — musimy
sami pilnować, żeby nie przyznać punktów dwa razy za tę samą transakcję).

Używa App Store Server API:
https://developer.apple.com/documentation/appstoreserverapi

Wymaga klucza API wygenerowanego w App Store Connect (Users and Access
-> Integrations -> App Store Connect API, typ "In-App Purchase") — patrz
APPLE_ISSUER_ID / APPLE_KEY_ID / APPLE_PRIVATE_KEY w konfiguracji.
"""

from __future__ import annotations

import logging
import time
from datetime import datetime, timezone

import httpx
from jose import jwt as jose_jwt

from app.core.config import settings

logger = logging.getLogger(__name__)

_PRODUCTION_URL = "https://api.storekit.itunes.apple.com"
_SANDBOX_URL = "https://api.storekit-sandbox.itunes.apple.com"

# Apple wymaga krótko żyjących tokenów — max. 60 minut, ale krótszy czas
# życia to lepsza praktyka bezpieczeństwa (nie ma powodu, żeby token
# ważny był dłużej niż potrzeba na pojedyncze zapytanie).
_JWT_LIFETIME_SECONDS = 300


class PurchaseVerificationError(Exception):
    """Weryfikacja zakupu nie powiodła się — nieprawidłowa/nieznana
    transakcja, brak konfiguracji, albo błąd komunikacji z Apple."""


def _generate_apple_jwt() -> str:
    """Buduje JWT podpisany NASZYM kluczem prywatnym — to Apple
    weryfikuje, że TO MY (a nie ktoś inny) pytamy o dane transakcji."""
    if not (settings.APPLE_ISSUER_ID and settings.APPLE_KEY_ID and settings.APPLE_PRIVATE_KEY):
        raise PurchaseVerificationError(
            "Weryfikacja płatności Apple nie jest skonfigurowana na serwerze "
            "(brak APPLE_ISSUER_ID / APPLE_KEY_ID / APPLE_PRIVATE_KEY)."
        )

    now = int(time.time())
    payload = {
        "iss": settings.APPLE_ISSUER_ID,
        "iat": now,
        "exp": now + _JWT_LIFETIME_SECONDS,
        "aud": "appstoreconnect-v1",
        "bid": settings.APPLE_BUNDLE_ID,
    }
    headers = {"alg": "ES256", "kid": settings.APPLE_KEY_ID, "typ": "JWT"}
    return jose_jwt.encode(payload, settings.APPLE_PRIVATE_KEY, algorithm="ES256", headers=headers)


async def _fetch_transaction_info(transaction_id: str) -> dict:
    """Pobiera dane transakcji z App Store Server API — próbuje NAJPIERW
    środowisko produkcyjne, a jeśli Apple odpowie "nie znaleziono",
    dopiero wtedy sandbox. To zalecany przez Apple wzorzec: nie ma
    sposobu, żeby z góry wiedzieć, czy dana transakcja jest testowa
    (sandbox) czy prawdziwa (produkcja), więc próbujemy po kolei."""
    token = _generate_apple_jwt()
    headers = {"Authorization": f"Bearer {token}"}

    async with httpx.AsyncClient(timeout=15.0) as client:
        for base_url in (_PRODUCTION_URL, _SANDBOX_URL):
            try:
                response = await client.get(
                    f"{base_url}/inApps/v1/transactions/{transaction_id}",
                    headers=headers,
                )
            except httpx.HTTPError as exc:
                logger.warning("Błąd połączenia z Apple (%s): %s", base_url, exc)
                continue

            if response.status_code == 200:
                data = response.json()
                signed_info = data.get("signedTransactionInfo")
                if not signed_info:
                    raise PurchaseVerificationError("Apple zwróciło odpowiedź bez danych transakcji.")
                # UWAGA (świadome uproszczenie): dekodujemy JWS BEZ
                # kryptograficznej weryfikacji podpisu Apple — sam token
                # dotarł do nas przez uwierzytelnione HTTPS z oficjalnego
                # API Apple (wywołanego NASZYM podpisanym zapytaniem), co
                # daje rozsądny poziom zaufania. Pełna weryfikacja
                # łańcucha certyfikatów (x5c) jest bardziej rygorystyczna,
                # ale znacząco bardziej złożona — do rozważenia w
                # przyszłości, jeśli skala/wymogi bezpieczeństwa tego
                # zażądają.
                claims = jose_jwt.get_unverified_claims(signed_info)
                return claims

            if response.status_code == 404:
                # Nie znaleziono w TYM środowisku — spróbuj kolejnego
                # (produkcja -> sandbox), zanim ostatecznie zrezygnujemy.
                continue

            logger.warning(
                "Weryfikacja transakcji Apple nieudana (status %d, %s): %s",
                response.status_code,
                base_url,
                response.text[:300],
            )

    raise PurchaseVerificationError("Nie znaleziono takiej transakcji u Apple.")


async def _fetch_subscription_status(transaction_id: str) -> dict:
    """Pobiera NAJNOWSZY stan całej subskrypcji, także po odnowieniu.

    Endpoint pojedynczej transakcji zwraca wyłącznie okres wskazany przez
    przekazany transaction ID. Po automatycznym odnowieniu dawałby więc
    starą datę. Get All Subscription Statuses przyjmuje dowolny transaction
    ID z łańcucha i zwraca ostatnią transakcję każdego planu.
    """
    token = _generate_apple_jwt()
    headers = {"Authorization": f"Bearer {token}"}

    async with httpx.AsyncClient(timeout=15.0) as client:
        for base_url in (_PRODUCTION_URL, _SANDBOX_URL):
            try:
                response = await client.get(
                    f"{base_url}/inApps/v1/subscriptions/{transaction_id}",
                    headers=headers,
                )
            except httpx.HTTPError as exc:
                logger.warning("Błąd pobierania statusu Apple (%s): %s", base_url, exc)
                continue

            if response.status_code == 200:
                payload = response.json()
                bundle_id = payload.get("bundleId")
                if settings.APPLE_BUNDLE_ID and bundle_id != settings.APPLE_BUNDLE_ID:
                    raise PurchaseVerificationError(
                        "Transakcja Apple należy do innej aplikacji."
                    )
                return payload

            if response.status_code == 404:
                continue

            logger.warning(
                "Pobieranie statusu Apple nieudane (status %d, %s): %s",
                response.status_code,
                base_url,
                response.text[:300],
            )

    raise PurchaseVerificationError("Nie znaleziono tej subskrypcji u Apple.")


async def verify_apple_subscription(transaction_id: str, expected_product_id: str) -> dict:
    """Zwraca {"is_active": bool, "expiry_time": datetime | None,
    "product_id": str | None} — odpowiednik verify_subscription_purchase
    z google_play_billing.py, ale dla App Store."""
    payload = await _fetch_subscription_status(transaction_id)
    candidates: list[dict] = []

    for group in payload.get("data") or []:
        for item in group.get("lastTransactions") or []:
            signed_transaction = item.get("signedTransactionInfo")
            if not signed_transaction:
                continue
            claims = jose_jwt.get_unverified_claims(signed_transaction)
            if claims.get("productId") != expected_product_id:
                continue

            renewal_claims: dict = {}
            if item.get("signedRenewalInfo"):
                renewal_claims = jose_jwt.get_unverified_claims(
                    item["signedRenewalInfo"]
                )

            expiry_values = [
                value
                for value in (
                    claims.get("expiresDate"),
                    renewal_claims.get("gracePeriodExpiresDate"),
                )
                if isinstance(value, (int, float))
            ]
            expires_ms = max(expiry_values) if expiry_values else None
            expiry_time = (
                datetime.fromtimestamp(expires_ms / 1000, tz=timezone.utc)
                if expires_ms is not None
                else None
            )
            try:
                status = int(item.get("status"))
            except (TypeError, ValueError):
                status = 0

            candidates.append(
                {
                    "status": status,
                    "expiry_time": expiry_time,
                    "revoked": claims.get("revocationDate") is not None,
                    "product_id": claims.get("productId"),
                    "purchase_token": item.get("originalTransactionId")
                    or claims.get("originalTransactionId")
                    or transaction_id,
                }
            )

    if not candidates:
        raise PurchaseVerificationError(
            f"Apple nie potwierdziło subskrypcji produktu {expected_product_id}."
        )

    # Przy ewentualnych zmianach planu wybieramy najpóźniejszy okres dla
    # oczekiwanego produktu, nie przypadkowy pierwszy element odpowiedzi.
    result = max(
        candidates,
        key=lambda value: value["expiry_time"]
        or datetime.min.replace(tzinfo=timezone.utc),
    )
    expiry_time = result["expiry_time"]
    if expiry_time is None:
        raise PurchaseVerificationError(
            "Apple nie zwróciło daty wygaśnięcia płatnej subskrypcji."
        )

    # Apple: 1 = active, 4 = billing grace period. Pozostałe stany nie
    # dają dostępu. Sama data też musi być przyszła, a zakup niezwrócony.
    result["is_active"] = (
        result["status"] in {1, 4}
        and not result["revoked"]
        and expiry_time > datetime.now(timezone.utc)
    )
    return result


async def verify_apple_consumable(transaction_id: str, expected_product_id: str) -> dict:
    """Zwraca {"is_purchased": bool, "product_id": str} — odpowiednik
    verify_consumable_purchase z google_play_billing.py. Apple NIE MA
    koncepcji "consumptionState" jak Google — sama obecność ważnej,
    niecofniętej transakcji o właściwym productId JEST potwierdzeniem
    zakupu. Idempotencję (żeby nie przyznać punktów dwa razy za TĘ SAMĄ
    transakcję) zapewnia ProcessedApplePurchase w warstwie endpointu,
    nie tutaj."""
    claims = await _fetch_transaction_info(transaction_id)

    product_id = claims.get("productId")
    if product_id != expected_product_id:
        raise PurchaseVerificationError(
            f"Identyfikator produktu nie zgadza się (oczekiwano {expected_product_id}, "
            f"otrzymano {product_id})."
        )
    if claims.get("revocationDate") is not None:
        raise PurchaseVerificationError("Ten zakup został zwrócony/anulowany.")

    return {"is_purchased": True, "product_id": product_id}
