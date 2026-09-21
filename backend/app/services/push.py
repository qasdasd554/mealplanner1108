"""Wysyłka powiadomień push przez Firebase Cloud Messaging (HTTP v1).

WYŁĄCZONE, gdy `FCM_SERVICE_ACCOUNT_JSON` jest puste — wtedy funkcje
kończą się po cichu i aplikacja działa dokładnie jak dotąd (powiadomienia
w dzwoneczku, bez systemowych). Dzięki temu backend można wdrożyć zanim
Firebase zostanie skonfigurowany.

Dlaczego HTTP v1, a nie starsze "legacy" API z kluczem serwera: Google
wyłączyło legacy w 2024 roku. v1 wymaga tokenu OAuth wygenerowanego
z klucza konta serwisowego — do tego służy biblioteka `google-auth`,
która jest już w requirements.txt (używa jej logowanie Google).
"""

from __future__ import annotations

import json
import logging
from typing import Any

import httpx
from google.auth.transport.requests import Request as GoogleAuthRequest
from google.oauth2 import service_account
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.models.device_token import DeviceToken

logger = logging.getLogger(__name__)

_SCOPES = ["https://www.googleapis.com/auth/firebase.messaging"]

# Poświadczenia trzymamy w pamięci procesu — biblioteka sama odświeża
# token OAuth przed wygaśnięciem, więc nie ma sensu budować ich od nowa
# przy każdym powiadomieniu (to kosztowna operacja kryptograficzna).
_credentials: service_account.Credentials | None = None
_project_id: str | None = None


def is_push_enabled() -> bool:
    return bool(settings.FCM_SERVICE_ACCOUNT_JSON.strip())


def _get_credentials() -> tuple[service_account.Credentials, str] | None:
    global _credentials, _project_id
    if not is_push_enabled():
        return None
    if _credentials is not None and _project_id is not None:
        return _credentials, _project_id
    try:
        info: dict[str, Any] = json.loads(settings.FCM_SERVICE_ACCOUNT_JSON)
        _credentials = service_account.Credentials.from_service_account_info(info, scopes=_SCOPES)
        _project_id = info["project_id"]
        return _credentials, _project_id
    except (json.JSONDecodeError, KeyError, ValueError):
        logger.exception("FCM_SERVICE_ACCOUNT_JSON jest nieprawidłowy — push wyłączony.")
        return None


def _access_token(creds: service_account.Credentials) -> str | None:
    try:
        if not creds.valid:
            creds.refresh(GoogleAuthRequest())
        return creds.token
    except Exception:
        logger.exception("Nie udało się uzyskać tokenu OAuth do FCM.")
        return None


def _fcm_error_code(response: httpx.Response) -> str | None:
    """Zwraca precyzyjny kod FCM, bez zgadywania na podstawie HTTP 4xx."""
    try:
        details = response.json().get("error", {}).get("details", [])
    except (json.JSONDecodeError, AttributeError, TypeError, ValueError):
        return None
    for detail in details:
        if isinstance(detail, dict) and detail.get("errorCode"):
            return str(detail["errorCode"])
    return None


async def send_push_to_user(
    db: AsyncSession,
    user_id,
    title: str,
    body: str,
    data: dict[str, str] | None = None,
) -> int:
    """Wysyła powiadomienie na WSZYSTKIE urządzenia użytkownika.

    Zwraca liczbę urządzeń, do których wysyłka się powiodła.

    ŻADEN błąd nie jest podnoszony na zewnątrz: push to dodatek do
    powiadomienia zapisanego w bazie, a nie operacja krytyczna. Awaria
    Firebase nie może wywrócić dodawania komentarza czy zatwierdzania
    zdjęcia — użytkownik i tak zobaczy powiadomienie w dzwoneczku po
    otwarciu aplikacji.
    """
    if not is_push_enabled():
        return 0

    creds_pair = _get_credentials()
    if creds_pair is None:
        return 0
    creds, project_id = creds_pair

    token_result = await db.execute(
        select(DeviceToken).where(DeviceToken.user_id == user_id)
    )
    devices = list(token_result.scalars().all())
    if not devices:
        return 0

    access_token = _access_token(creds)
    if access_token is None:
        return 0

    url = f"https://fcm.googleapis.com/v1/projects/{project_id}/messages:send"
    headers = {
        "Authorization": f"Bearer {access_token}",
        "Content-Type": "application/json; UTF-8",
    }

    sent = 0
    stale_tokens: list[DeviceToken] = []

    async with httpx.AsyncClient(timeout=10.0) as client:
        for device in devices:
            payload = {
                "message": {
                    "token": device.token,
                    "notification": {"title": title, "body": body},
                    # `data` musi mieć wyłącznie wartości tekstowe —
                    # FCM odrzuca liczby i wartości puste.
                    "data": {k: str(v) for k, v in (data or {}).items()},
                    "android": {"priority": "high"},
                    "apns": {
                        "headers": {
                            "apns-priority": "10",
                            "apns-push-type": "alert",
                        },
                        "payload": {"aps": {"sound": "default", "badge": 1}},
                    },
                }
            }
            try:
                response = await client.post(url, headers=headers, json=payload)
                if response.status_code == 200:
                    sent += 1
                elif _fcm_error_code(response) == "UNREGISTERED":
                    # Usuwamy tylko token jednoznacznie oznaczony przez FCM
                    # jako wygasły. Sam status 400/404 może też oznaczać błąd
                    # konfiguracji APNs; usunięcie wtedy poprawnego tokenu
                    # iPhone'a uniemożliwia kolejne próby po naprawie klucza.
                    logger.info("Usuwam nieaktualny token urządzenia (UNREGISTERED).")
                    stale_tokens.append(device)
                else:
                    logger.warning(
                        "FCM zwrócił %s przy wysyłce push: %s",
                        response.status_code,
                        response.text[:200],
                    )
            except httpx.HTTPError:
                logger.warning("Błąd sieci przy wysyłce push — pomijam to urządzenie.")

    if stale_tokens:
        for device in stale_tokens:
            await db.delete(device)
        await db.commit()

    return sent


# Krótkie tytuły powiadomień systemowych per typ. Tytuł powinien
# natychmiast mówić, CZEGO dotyczy — treść (`message`) jest już gotowa
# w bazie i trafia do dymka jako tekst.
_TITLES: dict[str, str] = {
    "recipe_comment": "Nowy komentarz",
    "comment_like": "Ktoś polubił Twój komentarz",
    "billing": "Meal Planner Polska",
    "shopping_list_share": "Udostępniono Ci listę zakupów",
    "shopping_list_accepted": "Zaproszenie przyjęte",
    "weekly_contest": "Konkurs tygodnia",
    "recipe_photo": "Zdjęcie przepisu",
    "recipe_approved": "Przepis zaakceptowany",
    "recipe_rejected": "Przepis odrzucony",
    "recipe_import_ready": "Przepis jest gotowy",
    "recipe_import_failed": "Nie udało się dodać przepisu",
    "promotion_pending_approval": "Promocja do sprawdzenia",
    "recipe_pending_approval": "Przepis do sprawdzenia",
    "product_pending_approval": "Produkt do sprawdzenia",
    "photo_pending_approval": "Zdjęcie do sprawdzenia",
    "content_report_pending": "Nowe zgłoszenie do moderacji",
    "product_reviewed": "Zgłoszony produkt",
    "broadcast": "Meal Planner Polska",
    "admin_broadcast": "Meal Planner Polska",
    "friend_invitation": "Nowe zaproszenie do znajomych",
    "friend_accepted": "Zaproszenie przyjęte",
}


async def push_for_notification(db: AsyncSession, notification) -> None:
    """Wysyła push odpowiadający powiadomieniu zapisanemu w bazie.

    Wołane PO `db.commit()` na powiadomieniu — gdyby wysyłka szła przed
    zapisem, użytkownik mógłby dostać dymek o czymś, co ostatecznie nie
    zapisało się w bazie (np. transakcja wycofana), i po otwarciu
    aplikacji nie znalazłby tego w dzwoneczku.
    """
    if not is_push_enabled():
        return
    title = _TITLES.get(notification.notification_type, "Meal Planner Polska")
    data = {"type": notification.notification_type}
    if notification.recipe_id:
        data["recipe_id"] = str(notification.recipe_id)
    try:
        await send_push_to_user(db, notification.user_id, title, notification.message, data)
    except Exception:
        logger.exception("Nieoczekiwany błąd przy wysyłce push — pomijam.")
