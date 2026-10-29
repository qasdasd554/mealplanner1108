"""Queued work rechecks account authorization before a paid AI call."""

from contextlib import asynccontextmanager
from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock
from uuid import uuid4

import pytest

from app.services import recipe_import_worker as worker


@pytest.mark.asyncio
@pytest.mark.parametrize("country", ["PL", "GB"])
@pytest.mark.parametrize("banned, verified", [(True, True), (False, False)])
async def test_worker_does_not_import_for_account_that_lost_access(monkeypatch, banned, verified, country):
    job_id = uuid4()
    user = SimpleNamespace(id=uuid4(), is_banned=banned, is_email_verified=verified, country_code=country)
    job = SimpleNamespace(user_id=user.id, payload={"text": "Marchew"})
    db = AsyncMock()
    claim = MagicMock()
    claim.scalar_one_or_none.return_value = job_id
    absent = MagicMock()
    absent.scalar_one_or_none.return_value = None
    db.execute.side_effect = [claim, absent, absent]
    db.get.side_effect = [job, user]
    @asynccontextmanager
    async def session():
        yield db
    imported, finished = AsyncMock(), AsyncMock()
    monkeypatch.setattr(worker, "async_session_factory", session)
    monkeypatch.setattr(worker, "_finish_job", finished)
    monkeypatch.setattr("app.api.v1.recipes._create_ai_recipe", imported)
    await worker._process_recipe_import(job_id)
    imported.assert_not_awaited()
    assert finished.await_args.kwargs["error"].startswith("This account" if country == "GB" else "Konto")
