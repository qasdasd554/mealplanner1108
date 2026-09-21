"""Wykonuje import AI poza czasem życia żądania HTTP i wznawia kolejkę."""

from __future__ import annotations

import asyncio
import logging
import uuid
from contextlib import suppress
from datetime import datetime, timedelta, timezone

from fastapi import HTTPException
from sqlalchemy import select, update

from app.db.session import async_session_factory
from app.models import Recipe, RecipeImportJob, User
from app.models.notification import Notification
from app.schemas.recipe import AIRecipeImportRequest
from app.services.push import push_for_notification

logger = logging.getLogger(__name__)
_active_tasks: dict[uuid.UUID, asyncio.Task] = {}
_parallel_imports = asyncio.Semaphore(2)


def schedule_recipe_import(job_id: uuid.UUID) -> None:
    """Uruchom w tym procesie; status w bazie chroni przed drugim workerem."""
    if job_id in _active_tasks:
        return
    task = asyncio.create_task(_process_recipe_import(job_id))
    _active_tasks[job_id] = task
    task.add_done_callback(lambda _: _active_tasks.pop(job_id, None))


async def _finish_job(
    job_id: uuid.UUID, *, recipe: Recipe | None = None, error: str | None = None
) -> None:
    async with async_session_factory() as db:
        job = await db.get(RecipeImportJob, job_id)
        if job is None or job.status == "completed":
            return
        job.status = "completed" if recipe is not None else "failed"
        job.recipe_id = recipe.id if recipe is not None else None
        job.error = error[:500] if error else None
        job.payload = None
        job.finished_at = datetime.now(timezone.utc)
        notification = Notification(
            user_id=job.user_id,
            notification_type=("recipe_import_ready" if recipe else "recipe_import_failed"),
            message=(
                f'Przepis „{recipe.name[:180]}” jest gotowy w zakładce Moje.'
                if recipe else f'Nie udało się dodać przepisu: {(error or "spróbuj ponownie")[:380]}'
            ),
            recipe_id=recipe.id if recipe else None,
        )
        db.add(notification)
        await db.commit()
        await push_for_notification(db, notification)


async def _heartbeat(job_id: uuid.UUID) -> None:
    while True:
        await asyncio.sleep(20)
        try:
            async with async_session_factory() as db:
                await db.execute(update(RecipeImportJob).where(
                    RecipeImportJob.id == job_id,
                    RecipeImportJob.status == "processing",
                ).values(heartbeat_at=datetime.now(timezone.utc)))
                await db.commit()
        except asyncio.CancelledError:
            raise
        except Exception:
            logger.warning("Nie zapisano heartbeat importu %s", job_id, exc_info=True)


async def _process_recipe_import(job_id: uuid.UUID) -> None:
    async with _parallel_imports:
        heartbeat_task: asyncio.Task | None = None
        try:
            async with async_session_factory() as db:
                claim = await db.execute(
                    update(RecipeImportJob)
                    .where(RecipeImportJob.id == job_id, RecipeImportJob.status == "queued")
                    .values(
                        status="processing",
                        started_at=datetime.now(timezone.utc),
                        heartbeat_at=datetime.now(timezone.utc),
                    )
                    .returning(RecipeImportJob.id)
                )
                claimed = claim.scalar_one_or_none()
                await db.commit()
                if claimed is None:
                    return
            heartbeat_task = asyncio.create_task(_heartbeat(job_id))

            async with async_session_factory() as db:
                job = await db.get(RecipeImportJob, job_id)
                if job is None:
                    return
                existing = await db.execute(select(Recipe).where(Recipe.import_job_id == job_id))
                recipe = existing.scalar_one_or_none()
                if recipe is None:
                    user = await db.get(User, job.user_id)
                    if user is None or job.payload is None:
                        raise ValueError("Brak danych potrzebnych do importu.")
                    payload = AIRecipeImportRequest.model_validate(job.payload)
                    from app.api.v1.recipes import _create_ai_recipe

                    recipe = await _create_ai_recipe(
                        payload, user, db, import_job_id=job_id, skip_rate_limit=True
                    )
            await _finish_job(job_id, recipe=recipe)
        except asyncio.CancelledError:
            # Przy deployu procesu kolejka zostaje w Neon; kolejny proces
            # może wznowić import. Jeśli przepis już istnieje, odczyta go
            # po import_job_id i nie pobierze punktów ponownie.
            async with async_session_factory() as db:
                await db.execute(update(RecipeImportJob).where(
                    RecipeImportJob.id == job_id,
                    RecipeImportJob.status == "processing",
                ).values(status="queued"))
                await db.commit()
            raise
        except Exception as exc:
            logger.exception("Import przepisu %s nie powiódł się", job_id)
            # Wyjątek po zapisie przepisu nie powinien oznaczać porażki ani
            # powtórnego naliczenia punktów po restarcie workera.
            async with async_session_factory() as db:
                existing = await db.execute(select(Recipe).where(Recipe.import_job_id == job_id))
                recipe = existing.scalar_one_or_none()
            if recipe is not None:
                await _finish_job(job_id, recipe=recipe)
            else:
                detail = exc.detail if isinstance(exc, HTTPException) else "Spróbuj ponownie później."
                await _finish_job(job_id, error=str(detail))
        finally:
            if heartbeat_task is not None:
                heartbeat_task.cancel()
                with suppress(asyncio.CancelledError):
                    await heartbeat_task


async def recipe_import_worker_loop() -> None:
    """Odzyskuje zadania po restarcie Rendera; DB jest źródłem prawdy."""
    while True:
        try:
            async with async_session_factory() as db:
                stale_before = datetime.now(timezone.utc) - timedelta(seconds=90)
                await db.execute(update(RecipeImportJob).where(
                    RecipeImportJob.status == "processing",
                    RecipeImportJob.heartbeat_at < stale_before,
                ).values(status="queued"))
                await db.commit()
                result = await db.execute(select(RecipeImportJob.id).where(
                    RecipeImportJob.status == "queued"
                ).order_by(RecipeImportJob.created_at).limit(10))
                for job_id in result.scalars().all():
                    schedule_recipe_import(job_id)
        except asyncio.CancelledError:
            raise
        except Exception:
            logger.exception("Nie udało się wznowić kolejki importów AI")
        await asyncio.sleep(10)
