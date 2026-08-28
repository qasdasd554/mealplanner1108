"""Automatyczne rozliczanie cotygodniowego konkursu przepisów —
wywoływane przez zaplanowane zadanie (patrz app/main.py, APScheduler)
oraz dostępne do ręcznego wywołania w testach.

Tydzień liczony jest jako KALENDARZOWY, poniedziałek-niedziela (nie
"ostatnie 7 dni" jak w ogólnym podglądzie rankingu) — inaczej pojęcie
"koniec tygodnia, wypłata nagród" byłoby niejednoznaczne."""

import logging
from datetime import date, datetime, timedelta, timezone

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import Notification, Recipe, User, WeeklyContestPayout

logger = logging.getLogger(__name__)

# 3 punkty za 1. miejsce, 2 za 2., 1 za 3. — reszta uczestników nic nie
# dostaje automatycznie (to nagroda za TOP 3, nie ogólna premia).
_PLACE_POINTS = [3, 2, 1]


def _previous_week_range(today: date) -> tuple[date, date]:
    """Zwraca (poniedziałek, poniedziałek+7dni) POPRZEDNIEGO tygodnia
    względem podanej daty — czyli tygodnia, który właśnie się skończył
    i czeka na rozliczenie."""
    this_monday = today - timedelta(days=today.weekday())
    previous_monday = this_monday - timedelta(days=7)
    return previous_monday, this_monday


async def process_weekly_contest_payout(db: AsyncSession) -> WeeklyContestPayout | None:
    """Sprawdza, czy POPRZEDNI tydzień został już rozliczony — jeśli
    nie, przyznaje punkty TOP 3 autorom (3/2/1) i wysyła powiadomienie
    broadcast do wszystkich o starcie nowego tygodnia.

    Zwraca utworzony WeeklyContestPayout, albo None jeśli ten tydzień
    był już wcześniej rozliczony (nic nowego się nie stało).
    """
    today = datetime.now(timezone.utc).date()
    week_start, week_end = _previous_week_range(today)

    existing = await db.execute(
        select(WeeklyContestPayout).where(WeeklyContestPayout.week_start_date == week_start)
    )
    if existing.scalar_one_or_none() is not None:
        return None

    result = await db.execute(
        select(User.id, User.display_name, func.count(Recipe.id).label("recipe_count"))
        .join(Recipe, Recipe.created_by_user_id == User.id)
        .where(
            Recipe.visibility == "public",
            Recipe.created_at >= week_start,
            Recipe.created_at < week_end,
        )
        .group_by(User.id, User.display_name)
        .order_by(func.count(Recipe.id).desc())
        .limit(3)
    )
    winners = result.all()

    for place, (user_id, display_name, recipe_count) in enumerate(winners):
        points = _PLACE_POINTS[place]
        user = await db.get(User, user_id)
        if user is None:
            continue
        user.premium_points += points
        db.add(user)
        logger.info(
            "Konkurs tygodniowy: %s miejsce %d, +%d punktow (przepisow: %d)",
            display_name or "Uzytkownik",
            place + 1,
            points,
            recipe_count,
        )

    # Zabezpieczenie przed podwójnym rozliczeniem — zapisujemy NIEZALEŻNIE
    # od tego, czy w ogóle byli jacyś zwycięzcy (pusty tydzień też jest
    # "rozliczony", żeby nie próbować tego ciągle od nowa).
    payout = WeeklyContestPayout(week_start_date=week_start)
    db.add(payout)

    # Powiadomienie broadcast — jeden wiersz PER użytkownik (zgodnie z
    # istniejącym modelem Notification, patrz app/models/notification.py),
    # więc pętla po wszystkich kontach.
    if winners:
        winner_names = ", ".join(name or "Użytkownik" for _, name, _ in winners)
        message = (
            f"Nowy tydzień konkursu przepisów właśnie się zaczął! "
            f"Zwycięzcy poprzedniego tygodnia: {winner_names} — gratulacje! "
            f"Dodawaj przepisy i baw się dobrze w tym tygodniu."
        )
    else:
        message = "Nowy tydzień konkursu przepisów właśnie się zaczął! Dodaj przepis i zawalcz o podium."

    all_users = await db.execute(select(User.id))
    for (user_id,) in all_users.all():
        db.add(Notification(user_id=user_id, notification_type="weekly_contest", message=message))

    await db.commit()
    return payout
