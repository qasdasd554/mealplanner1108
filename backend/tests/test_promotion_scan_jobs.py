import asyncio
from types import SimpleNamespace
from uuid import uuid4
from fastapi import HTTPException
from app.api.deps import get_current_admin
from app.api.v1 import promotions
from app.services import promotion_scan_worker as worker


def test_all_promotion_job_routes_are_admin_only():
    routes = [route for route in promotions.router.routes if '/ai-scan/jobs' in route.path]
    assert len(routes) == 3
    for route in routes:
        assert get_current_admin in [dep.call for dep in route.dependant.dependencies]


class Database:
    def __init__(self):
        self.job = SimpleNamespace(status='processing', result=None, error=None)
        self.commits = 0
    async def __aenter__(self): return self
    async def __aexit__(self, *args): pass
    async def get(self, model, identifier): return self.job
    async def commit(self): self.commits += 1


def test_worker_records_success_after_scan(monkeypatch):
    db = Database()
    monkeypatch.setattr(worker, 'async_session_factory', lambda: db)
    async def scan(store, session): return {'found': 4, 'queued_for_review': 3}
    monkeypatch.setattr(promotions, '_scan_and_queue_promotions', scan)
    asyncio.run(worker._run_scan(uuid4(), 'Carrefour'))
    assert db.job.status == 'completed'
    assert db.job.result['queued_for_review'] == 3


def test_worker_records_real_ai_failure(monkeypatch):
    db = Database()
    monkeypatch.setattr(worker, 'async_session_factory', lambda: db)
    async def scan(store, session): raise HTTPException(422, 'Brak PDF-a')
    monkeypatch.setattr(promotions, '_scan_and_queue_promotions', scan)
    asyncio.run(worker._run_scan(uuid4(), 'Lidl'))
    assert db.job.status == 'failed' and db.job.error == 'Brak PDF-a'


def test_worker_timeout_is_persistent_not_phone_timeout(monkeypatch):
    db = Database()
    monkeypatch.setattr(worker, 'async_session_factory', lambda: db)
    monkeypatch.setattr(worker, 'SCAN_TIMEOUT', 0.01)
    async def scan(store, session): await asyncio.sleep(0.1)
    monkeypatch.setattr(promotions, '_scan_and_queue_promotions', scan)
    asyncio.run(worker._run_scan(uuid4(), 'Dino'))
    assert db.job.status == 'failed' and 'Analiza gazetki' in db.job.error


def test_shutdown_leaves_processing_job_recoverable(monkeypatch):
    db = Database()
    monkeypatch.setattr(worker, 'async_session_factory', lambda: db)
    async def scan(store, session): raise asyncio.CancelledError()
    monkeypatch.setattr(promotions, '_scan_and_queue_promotions', scan)
    import pytest
    with pytest.raises(asyncio.CancelledError):
        asyncio.run(worker._run_scan(uuid4(), 'Biedronka'))
    assert db.job.status == 'processing' and db.commits == 0
