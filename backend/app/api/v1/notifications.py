"""Endpointy powiadomień w aplikacji (dzwoneczek)."""

import uuid
from datetime import datetime, timezone
from typing import List

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field
from sqlalchemy import delete, func, select, update
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.api.deps import get_current_admin, get_current_user, get_db
from app.models.notification import Notification
from app.models.user import User
from app.schemas.notification import NotificationResponse, UnreadCountResponse

router = APIRouter()


def _to_response(n: Notification) -> NotificationResponse:
    return NotificationResponse(
        id=n.id,
        notification_type=n.notification_type,
        message=n.message,
        recipe_id=n.recipe_id,
        recipe_name=n.recipe.name if n.recipe_id and n.recipe else None,
        comment_id=n.comment_id,
        is_read=n.is_read,
        created_at=n.created_at,
    )


@router.get("/", response_model=List[NotificationResponse])
async def list_notifications(
    limit: int = 50,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Zwraca powiadomienia bieżącego użytkownika, od najnowszych."""
    result = await db.execute(
        select(Notification)
        .where(Notification.user_id == current_user.id)
        .options(selectinload(Notification.recipe))
        .order_by(Notification.created_at.desc())
        .limit(limit)
    )
    notifications = result.scalars().all()
    return [_to_response(n) for n in notifications]


@router.get("/unread-count", response_model=UnreadCountResponse)
async def get_unread_count(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Sama liczba nieprzeczytanych — do odznaki na dzwoneczku, odpytywane
    częściej niż pełna lista, więc celowo lekkie (samo COUNT, bez ładowania
    treści powiadomień)."""
    result = await db.execute(
        select(func.count(Notification.id)).where(
            Notification.user_id == current_user.id,
            Notification.is_read == False,  # noqa: E712
        )
    )
    return UnreadCountResponse(unread_count=result.scalar_one())


@router.put("/{notification_id}/read", status_code=status.HTTP_204_NO_CONTENT)
async def mark_notification_read(
    notification_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Oznacza jedno powiadomienie jako przeczytane."""
    notification = await db.get(Notification, notification_id)
    if not notification or notification.user_id != current_user.id:
        raise HTTPException(status_code=404, detail="Nie znaleziono powiadomienia")
    notification.is_read = True
    await db.commit()


@router.put("/read-all", status_code=status.HTTP_204_NO_CONTENT)
async def mark_all_notifications_read(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Oznacza wszystkie powiadomienia użytkownika jako przeczytane —
    jedno zapytanie UPDATE, bez ładowania wierszy do Pythona."""
    await db.execute(
        update(Notification)
        .where(Notification.user_id == current_user.id, Notification.is_read == False)  # noqa: E712
        .values(is_read=True)
    )
    await db.commit()


class BroadcastRequest(BaseModel):
    message: str = Field(min_length=1, max_length=500)


@router.post(
    "/admin/broadcast",
    status_code=status.HTTP_201_CREATED,
    summary="Wyślij powiadomienie do WSZYSTKICH użytkowników (admin)",
)
async def send_broadcast_notification(
    payload: BroadcastRequest,
    current_user: User = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Tworzy JEDEN wiersz Notification dla KAŻDEGO konta w bazie —
    zgodnie z istniejącym modelem (jeden wiersz per odbiorca, nie
    współdzielony wpis), więc każdy użytkownik może niezależnie oznaczyć
    to jako przeczytane, bez wpływu na innych."""
    all_users = await db.execute(select(User.id))
    user_ids = [row[0] for row in all_users.all()]

    created = []
    for user_id in user_ids:
        n = Notification(
            user_id=user_id,
            notification_type="broadcast",
            message=payload.message,
        )
        created.append(n)
        db.add(n)
    await db.commit()

    await _send_pushes(db, created)
    return {"sent_to": len(user_ids)}


# ══════════════════════════════════════════════════════════════════
# TOKENY URZĄDZEŃ (powiadomienia push)
# ══════════════════════════════════════════════════════════════════
class DeviceTokenRequest(BaseModel):
    token: str
    platform: str | None = None


@router.post("/device-token", status_code=status.HTTP_204_NO_CONTENT)
async def register_device_token(
    payload: DeviceTokenRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> None:
    """Zapisuje token urządzenia, żeby móc wysyłać na nie powiadomienia
    systemowe. Aplikacja woła to po zalogowaniu i przy każdej zmianie
    tokenu (FCM potrafi go odświeżyć samodzielnie).

    Jeśli token już istnieje, ale należał do INNEGO konta, przepisujemy go
    na bieżące. Token jest własnością urządzenia — gdyby zostawić stare
    przypisanie, poprzedni użytkownik dostawałby cudze powiadomienia na
    telefon, z którego się już wylogował.
    """
    from app.models import DeviceToken

    token = payload.token.strip()
    if not token:
        raise HTTPException(status_code=400, detail="Pusty token urządzenia")

    result = await db.execute(select(DeviceToken).where(DeviceToken.token == token))
    existing = result.scalar_one_or_none()

    if existing is not None:
        existing.user_id = current_user.id
        existing.platform = payload.platform
        existing.last_seen_at = datetime.now(timezone.utc)
        db.add(existing)
    else:
        db.add(
            DeviceToken(
                user_id=current_user.id,
                token=token,
                platform=payload.platform,
            )
        )
    await db.commit()


# POST, nie DELETE: klient wysyła token w ciele żądania, a wspólna metoda
# ApiClient.delete we Flutterze ciała nie obsługuje. Zmiana tamtej metody
# dla jednego przypadku psułaby wszystkie pozostałe wywołania DELETE.
@router.post("/device-token/remove", status_code=status.HTTP_204_NO_CONTENT)
async def unregister_device_token(
    payload: DeviceTokenRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> None:
    """Usuwa token przy wylogowaniu — inaczej po wylogowaniu telefon dalej
    dostawałby powiadomienia konta, z którego użytkownik właśnie wyszedł."""
    from app.models import DeviceToken

    await db.execute(
        delete(DeviceToken).where(
            DeviceToken.token == payload.token.strip(),
            DeviceToken.user_id == current_user.id,
        )
    )
    await db.commit()

async def _send_pushes(db, notifications) -> None:
    """Wysyła push dla listy powiadomień — PO ich zapisaniu w bazie.
    Cicho pomijane, gdy push jest wyłączony (brak klucza FCM)."""
    from app.services.push import is_push_enabled, push_for_notification

    if not is_push_enabled():
        return
    for n in notifications:
        await push_for_notification(db, n)
