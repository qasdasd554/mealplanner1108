"""Powiadomienia o elementach oczekujących na moderację.

Wszystkie kolejki administratora korzystają z jednego mechanizmu, żeby
nowy wpis pojawiał się zarówno w dzwoneczku aplikacji, jak i jako push.
"""

from __future__ import annotations

from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.notification import Notification
from app.models.user import User


async def notify_admins_pending_review(
    db: AsyncSession,
    *,
    notification_type: str,
    message: str,
    recipe_id: UUID | None = None,
) -> int:
    """Zapisuje powiadomienie dla każdego administratora i wysyła push.

    Zapis w bazie jest operacją podstawową. Awaria zewnętrznej wysyłki FCM
    nie może cofnąć zgłoszenia użytkownika ani ukryć go w panelu admina.
    """

    admins_result = await db.execute(select(User.id).where(User.role == "admin"))
    admin_ids = list(admins_result.scalars().all())
    if not admin_ids:
        return 0

    notifications: list[Notification] = []
    for admin_id in admin_ids:
        notification = Notification(
            user_id=admin_id,
            notification_type=notification_type,
            message=message,
            recipe_id=recipe_id,
        )
        notifications.append(notification)
        db.add(notification)
    await db.commit()

    try:
        from app.services.push import is_push_enabled, push_for_notification

        if is_push_enabled():
            for notification in notifications:
                await push_for_notification(db, notification)
    except Exception:
        # Powiadomienie w aplikacji zostało już zapisane. Push jest
        # dodatkiem i nie może wywrócić właściwej operacji moderacyjnej.
        pass

    return len(notifications)
