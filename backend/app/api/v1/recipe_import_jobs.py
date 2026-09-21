"""Trwałe zadania importu AI i odczyt ich wyniku przez użytkownika."""

from __future__ import annotations

import uuid
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import defer

from app.api.deps import get_current_user
from app.core.premium import is_premium_active
from app.core.rate_limit import ai_recipe_import_limiter, enforce_user_rate_limit
from app.db.session import get_db
from app.models import RecipeImportJob, User
from app.schemas.recipe import AIRecipeImportRequest
from app.services.recipe_import_worker import schedule_recipe_import

router = APIRouter()


class RecipeImportJobResponse(BaseModel):
    id: uuid.UUID
    status: str
    recipe_id: uuid.UUID | None
    error: str | None
    created_at: datetime
    finished_at: datetime | None


def _response(job: RecipeImportJob) -> RecipeImportJobResponse:
    return RecipeImportJobResponse(
        id=job.id, status=job.status, recipe_id=job.recipe_id,
        error=job.error, created_at=job.created_at, finished_at=job.finished_at,
    )


@router.post("/jobs", response_model=RecipeImportJobResponse, status_code=status.HTTP_202_ACCEPTED)
async def start_recipe_import(
    payload: AIRecipeImportRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> RecipeImportJobResponse:
    if sum(bool(value) for value in (payload.text, payload.photo_base64, payload.url)) != 1:
        raise HTTPException(status_code=400, detail="Podaj dokładnie tekst, zdjęcie albo link.")

    # Blokada wiersza użytkownika serializuje dwa równoczesne kliknięcia.
    await db.execute(select(User.id).where(User.id == current_user.id).with_for_update())
    result = await db.execute(select(RecipeImportJob).options(
        defer(RecipeImportJob.payload)
    ).where(
        RecipeImportJob.user_id == current_user.id,
        RecipeImportJob.status.in_(("queued", "processing")),
    ).limit(1))
    if result.scalar_one_or_none() is not None:
        raise HTTPException(status_code=409, detail="Poprzedni przepis jest jeszcze rozpoznawany.")

    if not is_premium_active(current_user) and current_user.premium_points < 2:
        raise HTTPException(status_code=402, detail="Ta funkcja wymaga Premium albo 2 punktów.")
    enforce_user_rate_limit(
        ai_recipe_import_limiter, current_user.id, "rozpoznawanie przepisu przez AI"
    )

    job = RecipeImportJob(user_id=current_user.id, payload=payload.model_dump(exclude_none=True))
    db.add(job)
    await db.commit()
    # Nie pobieraj ponownie pola payload (może zawierać duże zdjęcie).
    await db.refresh(job, attribute_names=["created_at"])
    schedule_recipe_import(job.id)
    return _response(job)


@router.get("/jobs/recent", response_model=list[RecipeImportJobResponse])
async def recent_recipe_imports(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> list[RecipeImportJobResponse]:
    result = await db.execute(select(RecipeImportJob).options(
        defer(RecipeImportJob.payload)
    ).where(
        RecipeImportJob.user_id == current_user.id,
    ).order_by(RecipeImportJob.created_at.desc()).limit(10))
    return [_response(job) for job in result.scalars().all()]


@router.get("/jobs/{job_id}", response_model=RecipeImportJobResponse)
async def get_recipe_import(
    job_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> RecipeImportJobResponse:
    result = await db.execute(select(RecipeImportJob).options(
        defer(RecipeImportJob.payload)
    ).where(RecipeImportJob.id == job_id))
    job = result.scalar_one_or_none()
    if job is None or job.user_id != current_user.id:
        raise HTTPException(status_code=404, detail="Nie znaleziono importu przepisu.")
    return _response(job)
