"""Skanowanie gazetki nie utrzymuje wielominutowego żądania HTTP z telefonu."""
import asyncio
import logging
from datetime import datetime, timedelta, timezone
from fastapi import HTTPException
from sqlalchemy import or_, select
from app.db.session import async_session_factory
from app.models.promotion_scan_job import PromotionScanJob

logger = logging.getLogger(__name__)
SCAN_TIMEOUT = 360


async def _claim_job():
    now = datetime.now(timezone.utc)
    async with async_session_factory() as db:
        job = await db.scalar(select(PromotionScanJob).where(or_(
            PromotionScanJob.status == "queued",
            (PromotionScanJob.status == "processing") &
            (PromotionScanJob.started_at < now - timedelta(seconds=SCAN_TIMEOUT + 60)),
        )).order_by(PromotionScanJob.created_at).with_for_update(skip_locked=True).limit(1))
        if job is None:
            return None
        if job.attempts >= 2:
            job.status = "failed"
            job.error = "Skan został przerwany przy ponownym uruchomieniu serwera. Uruchom go ponownie."
            job.finished_at = now
            await db.commit()
            return None
        job.status = "processing"
        job.started_at = now
        job.attempts += 1
        identifier, store = job.id, job.store_name
        await db.commit()
        return identifier, store


async def _run_scan(job_id, store_name):
    from app.api.v1.promotions import _scan_and_queue_promotions
    result, error = None, None
    try:
        async with async_session_factory() as db:
            result = await asyncio.wait_for(_scan_and_queue_promotions(store_name, db), timeout=SCAN_TIMEOUT)
    except asyncio.CancelledError:
        # Trwały rekord zostanie wznowiony po restarcie; nie oznaczaj go jako sukces.
        raise
    except TimeoutError:
        error = "Analiza gazetki przekroczyła limit czasu. Spróbuj ponownie; zapisane promocje nie zostaną zdublowane."
    except HTTPException as exc:
        error = str(exc.detail)
    except Exception:
        logger.exception("Błąd skanowania gazetki %s", store_name)
        error = "Nie udało się przeanalizować gazetki. Spróbuj ponownie później."
    async with async_session_factory() as db:
        job = await db.get(PromotionScanJob, job_id)
        if job is not None:
            job.result = result
            job.error = error
            job.status = "failed" if error else "completed"
            job.finished_at = datetime.now(timezone.utc)
            await db.commit()


async def promotion_scan_worker_loop():
    while True:
        try:
            claimed = await _claim_job()
            if claimed is not None:
                await _run_scan(*claimed)
                continue
        except asyncio.CancelledError:
            raise
        except Exception:
            logger.exception("Błąd workera skanowania gazetek")
        await asyncio.sleep(5)
