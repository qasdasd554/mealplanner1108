"""Przypomnienia i zakończenie planów, niezależnie od otwierania aplikacji.

Koniec to północ po ostatnim dniu w Europe/Warsaw. Status ``expired``
usuwa plan z widoków użytkownika standardowego, ale zachowuje techniczny
wiersz właściciela listy zakupów. Fizyczne DELETE usunęłoby również listę
przez istniejący klucz obcy ON DELETE CASCADE.
"""

from __future__ import annotations

import logging
from dataclasses import dataclass
from datetime import datetime, time, timedelta, timezone
from uuid import UUID
from zoneinfo import ZoneInfo

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.premium import PAID_SUBSCRIPTION_PRODUCT_IDS, is_premium_active
from app.models import MealPlan, Notification, User
from app.services.push import push_for_notification
from app.services.subscription_sync import refresh_subscription_if_needed

logger = logging.getLogger(__name__)
WARSAW = ZoneInfo("Europe/Warsaw")
CURRENT_STATUSES = ("draft", "active", "completed")


@dataclass
class LifecycleResult:
    reminders: int = 0
    archived: int = 0
    removed: int = 0


def _expiry_from_dates(start_date, duration_days: int) -> datetime:
    return datetime.combine(
        start_date + timedelta(days=max(1, duration_days)), time.min, tzinfo=WARSAW
    ).astimezone(timezone.utc)


def plan_expires_at(plan: MealPlan) -> datetime:
    """Zwraca dokładny moment końca w UTC, uwzględniając zmianę czasu."""
    return datetime.combine(
        plan.end_date + timedelta(days=1), time.min, tzinfo=WARSAW
    ).astimezone(timezone.utc)


def plan_has_expired(plan: MealPlan, *, now: datetime | None = None) -> bool:
    current = now or datetime.now(timezone.utc)
    if current.tzinfo is None:
        current = current.replace(tzinfo=timezone.utc)
    return current >= plan_expires_at(plan)


def _expiry_is_verified(owner: User, current: datetime) -> bool:
    """Nie usuwaj historii po niezweryfikowanym automatycznym odnowieniu."""
    if (
        owner.role == "admin"
        or owner.premium_product_id not in PAID_SUBSCRIPTION_PRODUCT_IDS
        or not owner.premium_purchase_token
        or is_premium_active(owner)
    ):
        return True
    expiry = owner.premium_expires_at
    verified = owner.premium_last_verified_at
    if expiry is None or verified is None:
        return False
    if expiry.tzinfo is None:
        expiry = expiry.replace(tzinfo=timezone.utc)
    if verified.tzinfo is None:
        verified = verified.replace(tzinfo=timezone.utc)
    return expiry <= current and verified >= expiry


async def process_due_meal_plans(
    db: AsyncSession,
    *,
    now: datetime | None = None,
    user_id: UUID | None = None,
    send_reminders: bool = True,
) -> LifecycleResult:
    """Jedno przejście serwerowego zadania (wywoływane również po restarcie).

    Każdy plan ma własną transakcję i blokadę wiersza. SKIP LOCKED chroni
    przed równoległym workerem; zapis znacznika i powiadomienia jest atomowy.
    Push następuje dopiero po zatwierdzeniu tego zapisu. Błąd jednego planu
    nie blokuje reszty. Odczyty API używają ``send_reminders=False``, aby nie
    czekać na zewnętrzne FCM; przypomnienia obsługuje worker w tle.
    """
    current = now or datetime.now(timezone.utc)
    if current.tzinfo is None:
        current = current.replace(tzinfo=timezone.utc)
    current = current.astimezone(timezone.utc)
    local_today = current.astimezone(WARSAW).date()
    query = select(MealPlan.id, MealPlan.start_date, MealPlan.duration_days).where(
        MealPlan.status.in_(CURRENT_STATUSES),
        MealPlan.start_date <= local_today,
    )
    if user_id is not None:
        query = query.where(MealPlan.user_id == user_id)
    deadline = current + timedelta(hours=24) if send_reminders else current
    identifiers = [
        plan_id
        for plan_id, start_date, duration in (await db.execute(query)).all()
        if _expiry_from_dates(start_date, duration) <= deadline
    ]
    # Zwolnij transakcję odczytu przed blokowaniem pojedynczych planów.
    await db.commit()
    result = LifecycleResult()
    for plan_id in identifiers:
        try:
            candidate = (
                await db.execute(
                    select(MealPlan, User)
                    .join(User, User.id == MealPlan.user_id)
                    .where(MealPlan.id == plan_id, MealPlan.status.in_(CURRENT_STATUSES))
                    .execution_options(populate_existing=True)
                )
            ).one_or_none()
            if candidate is None:
                await db.rollback()
                continue
            candidate_plan, candidate_owner = candidate
            if current >= plan_expires_at(candidate_plan) and not _expiry_is_verified(candidate_owner, current):
                # Synchronizator sklepu zatwierdza własną transakcję, dlatego
                # wywołujemy go PRZED blokadą planu. Odczyt API nie czeka na sklep.
                if send_reminders:
                    await refresh_subscription_if_needed(db, candidate_owner)
                if not _expiry_is_verified(candidate_owner, current):
                    await db.rollback()
                    continue
            locked = await db.execute(
                select(MealPlan, User)
                .join(User, User.id == MealPlan.user_id)
                .where(
                    MealPlan.id == plan_id,
                    MealPlan.status.in_(CURRENT_STATUSES),
                )
                .execution_options(populate_existing=True)
                .with_for_update(skip_locked=True, of=MealPlan)
            )
            row = locked.one_or_none()
            if row is None:
                await db.rollback()
                continue
            plan, owner = row
            expires_at = plan_expires_at(plan)
            notification = None
            action = None
            if current >= expires_at:
                if is_premium_active(owner):
                    plan.status = "archived"
                    plan.archived_at = current
                    action = "archived"
                else:
                    plan.status = "expired"
                    action = "removed"
            elif (
                send_reminders
                and plan.expiration_reminder_sent_at is None
                and current >= expires_at - timedelta(hours=24)
            ):
                plan.expiration_reminder_sent_at = current
                notification = Notification(
                    user_id=owner.id,
                    meal_plan_id=plan.id,
                    notification_type="meal_plan_expiring",
                    message=(
                        f"Twój plan posiłków kończy się {plan.end_date:%d.%m.%Y}. "
                        "Przygotuj kolejny plan, aby mieć posiłki zaplanowane na następne dni."
                    ),
                )
                db.add(notification)
                action = "reminders"
            await db.commit()
            if action:
                setattr(result, action, getattr(result, action) + 1)
            if notification is not None:
                try:
                    await push_for_notification(db, notification)
                except Exception:
                    # Nie wycofuj już zapisanego przypomnienia i nie wysyłaj
                    # ponownie przy każdym cyklu, jeżeli zewnętrzny push zawiódł.
                    logger.exception("Nie udało się wysłać push o końcu planu %s", plan_id)
                    await db.rollback()
        except Exception:
            await db.rollback()
            logger.exception("Nie udało się zakończyć cyklu planu %s", plan_id)
    return result
