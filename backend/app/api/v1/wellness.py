"""Endpointy nawodnienia i aktywności fizycznej (zakładka Śledzenie)."""

from __future__ import annotations

import uuid
from datetime import date as date_type
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy import delete, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user, get_db
from app.models.user import User
from app.models.wellness import ActivityLog, WaterLog, WeightLog

router = APIRouter()

# Domyślny dzienny cel nawodnienia. Świadomie stała, a nie wyliczenie
# z masy ciała: powszechnie zalecane "2 litry" jest zrozumiałe od razu,
# a wzory zależne od wagi i aktywności różnią się między sobą na tyle,
# że dawałyby złudzenie precyzji, której tu nie ma.
DEFAULT_WATER_GOAL_ML = 2000


class WaterResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    date: date_type
    amount_ml: int
    goal_ml: int = DEFAULT_WATER_GOAL_ML


class AddWaterRequest(BaseModel):
    # Ujemna wartość jest DOZWOLONA — służy do cofnięcia omyłkowego
    # dodania (przycisk "cofnij"), bez osobnego endpointu.
    amount_ml: int = Field(..., ge=-2000, le=2000)


class ActivityCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=100)
    kcal_burned: int = Field(..., gt=0, le=10000)
    duration_min: int | None = Field(default=None, ge=0, le=1440)


class ActivityResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    date: date_type
    name: str
    kcal_burned: int
    duration_min: int | None


class DailyWellnessResponse(BaseModel):
    date: date_type
    water: WaterResponse
    activities: list[ActivityResponse]
    total_kcal_burned: int


class WeightLogUpsert(BaseModel):
    weight_kg: float = Field(..., gt=0, le=400)


class WeightLogResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    date: date_type
    weight_kg: float


# Stała ścieżka musi znaleźć się przed GET /{log_date}, ponieważ inaczej
# FastAPI próbowałoby zinterpretować słowo "weight" jako datę i zwracało 422.
@router.get("/weight", response_model=list[WeightLogResponse])
async def list_weight_logs(
    limit: int = Query(default=30, ge=1, le=365),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> list[WeightLog]:
    result = await db.execute(
        select(WeightLog)
        .where(WeightLog.user_id == current_user.id)
        .order_by(WeightLog.date.desc())
        .limit(limit)
    )
    return list(result.scalars().all())


@router.put("/weight/{log_date}", response_model=WeightLogResponse)
async def save_weight_log(
    log_date: date_type,
    payload: WeightLogUpsert,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> WeightLog:
    """Dodaje pomiar albo poprawia istniejący wpis z tego samego dnia.

    Pole `users.weight_kg` jest synchronizowane z najnowszym pomiarem,
    dzięki czemu BMI i kalkulator kalorii korzystają z aktualnej wagi.
    """
    result = await db.execute(
        select(WeightLog).where(
            WeightLog.user_id == current_user.id,
            WeightLog.date == log_date,
        )
    )
    entry = result.scalar_one_or_none()
    if entry is None:
        entry = WeightLog(
            user_id=current_user.id,
            date=log_date,
            weight_kg=payload.weight_kg,
        )
        db.add(entry)
    else:
        entry.weight_kg = payload.weight_kg

    await db.flush()
    latest = await db.scalar(
        select(WeightLog)
        .where(WeightLog.user_id == current_user.id)
        .order_by(WeightLog.date.desc(), WeightLog.updated_at.desc())
        .limit(1)
    )
    if latest is not None:
        current_user.weight_kg = latest.weight_kg

    await db.commit()
    await db.refresh(entry)
    return entry


@router.get("/{log_date}", response_model=DailyWellnessResponse)
async def get_daily_wellness(
    log_date: date_type,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> DailyWellnessResponse:
    """Nawodnienie i aktywności z jednego dnia — jednym zapytaniem,
    żeby ekran śledzenia nie musiał odpytywać serwera dwa razy."""
    water_result = await db.execute(
        select(WaterLog).where(WaterLog.user_id == current_user.id, WaterLog.date == log_date)
    )
    water = water_result.scalar_one_or_none()

    activities_result = await db.execute(
        select(ActivityLog)
        .where(ActivityLog.user_id == current_user.id, ActivityLog.date == log_date)
        .order_by(ActivityLog.created_at.desc())
    )
    activities = list(activities_result.scalars().all())

    return DailyWellnessResponse(
        date=log_date,
        water=WaterResponse(date=log_date, amount_ml=water.amount_ml if water else 0),
        activities=[ActivityResponse.model_validate(a) for a in activities],
        total_kcal_burned=sum(a.kcal_burned for a in activities),
    )


@router.post("/{log_date}/water", response_model=WaterResponse)
async def add_water(
    log_date: date_type,
    payload: AddWaterRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> WaterResponse:
    """Dolewa (lub odejmuje) wodę dla danego dnia.

    Aktualizuje istniejący wiersz zamiast tworzyć nowy — jeden wpis na
    użytkownika i dzień (ograniczenie unikalności na tabeli).
    """
    result = await db.execute(
        select(WaterLog).where(WaterLog.user_id == current_user.id, WaterLog.date == log_date)
    )
    entry = result.scalar_one_or_none()

    if entry is None:
        entry = WaterLog(user_id=current_user.id, date=log_date, amount_ml=0)
        db.add(entry)

    # Poniżej zera nie schodzimy — ujemne nawodnienie nie ma sensu,
    # a mogłoby powstać przez wielokrotne cofnięcie.
    entry.amount_ml = max(0, entry.amount_ml + payload.amount_ml)
    await db.commit()
    await db.refresh(entry)

    return WaterResponse(date=log_date, amount_ml=entry.amount_ml)


@router.post(
    "/{log_date}/activities",
    response_model=ActivityResponse,
    status_code=status.HTTP_201_CREATED,
)
async def add_activity(
    log_date: date_type,
    payload: ActivityCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> ActivityResponse:
    entry = ActivityLog(
        user_id=current_user.id,
        date=log_date,
        name=payload.name.strip(),
        kcal_burned=payload.kcal_burned,
        duration_min=payload.duration_min,
    )
    db.add(entry)
    await db.commit()
    await db.refresh(entry)
    return ActivityResponse.model_validate(entry)


# `response_model=None` jest tu KONIECZNE, mimo że funkcja ma już `-> None`.
#
# Ten plik zaczyna się od `from __future__ import annotations`, przez co
# WSZYSTKIE adnotacje stają się tekstem. FastAPI rozwiązuje wtedy "None"
# do TYPU `NoneType`, a nie do samej wartości `None` — a typ jest
# obiektem prawdziwym logicznie, więc warunek `if self.response_model:`
# przechodzi i odpala się asercja "Status code 204 must not have
# a response body". Bez tego wyjątek leciał przy IMPORCIE modułu, więc
# CAŁA aplikacja nie wstawała: Render zostawiał starą wersję, a wszystkie
# nowe endpointy (nie tylko ten) zwracały 404.
#
# Endpointy 204 w innych plikach działają, bo tamte nie mają
# `from __future__ import annotations`.
@router.delete(
    "/activities/{activity_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    response_model=None,
)
async def delete_activity(
    activity_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> None:
    # Warunek na user_id jest KONIECZNY — bez niego dowolny zalogowany
    # użytkownik mógłby skasować cudzy wpis, znając samo ID.
    result = await db.execute(
        delete(ActivityLog).where(
            ActivityLog.id == activity_id,
            ActivityLog.user_id == current_user.id,
        )
    )
    if result.rowcount == 0:
        raise HTTPException(status_code=404, detail="Nie znaleziono aktywności")
    await db.commit()
