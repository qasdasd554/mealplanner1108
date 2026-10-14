"""Runtime HTTP contracts and bounded startup maintenance; never call production."""

from __future__ import annotations

from types import SimpleNamespace
from unittest.mock import AsyncMock
from uuid import UUID

import pytest
from fastapi.testclient import TestClient
from sqlalchemy.dialects import postgresql

from app import main
from app.db import session as session_module


def test_head_health_checks_connection_without_scanning_catalog():
    db = SimpleNamespace(scalar=AsyncMock(return_value=1))
    main.app.dependency_overrides[main.get_db] = lambda: db
    try:
        response = TestClient(main.app).head('/health')
    finally:
        main.app.dependency_overrides.clear()
    assert response.status_code == 200 and response.content == b''
    assert db.scalar.await_count == 1
    statement = str(db.scalar.await_args.args[0]).lower()
    assert 'count(' not in statement
    assert 'products' not in statement


def test_public_health_does_not_advertise_hardcoded_database_hostname(monkeypatch):
    monkeypatch.setattr(main.settings, 'DATABASE_URL', 'postgresql://audit:audit@example.neon.tech/audit')
    db = SimpleNamespace(scalar=AsyncMock(return_value=42))
    main.app.dependency_overrides[main.get_db] = lambda: db
    try:
        response = TestClient(main.app).get('/health')
    finally:
        main.app.dependency_overrides.clear()
    assert response.status_code == 200
    assert response.json()['catalog_products'] == '42'
    assert '.neon.tech' not in response.text


class Result:
    def __init__(self, rows):
        self.rows = rows

    def scalars(self):
        return self

    def all(self):
        return self.rows


class MaintenanceSession:
    def __init__(self, rows, *, photos=True):
        self.rows = rows
        self.photos = photos
        self.statements = []
        self.added = []
        self.commit = AsyncMock()

    async def __aenter__(self):
        return self

    async def __aexit__(self, *args):
        pass

    async def execute(self, statement):
        self.statements.append(statement)
        parameters = statement.compile().params
        cursor = parameters.get('id_1')
        rows = [row for row in self.rows if cursor is None or row.id > cursor]
        if self.photos:
            rows = [row for row in rows if row.photo_thumbnail_base64 is None]
        limit = statement._limit_clause
        if limit is not None:
            rows = rows[:limit.value]
        return Result(rows)

    def add(self, row):
        self.added.append(row)


@pytest.mark.asyncio
async def test_thumbnail_backfill_is_bounded_and_moves_past_invalid_photo(monkeypatch):
    rows = [SimpleNamespace(id=UUID(int=i), photo_base64='invalid' if i == 1 else 'valid',
                            photo_thumbnail_base64=None) for i in range(1, 6)]
    db = MaintenanceSession(rows)
    monkeypatch.setattr(session_module, 'async_session_factory', lambda: db)
    monkeypatch.setattr(main, 'BACKFILL_BATCH_SIZE', 2, raising=False)
    monkeypatch.setattr('app.services.recipe_photo_thumbnail.create_recipe_photo_thumbnail',
                        lambda photo: 'thumbnail' if photo == 'valid' else None)
    await main._backfill_recipe_photo_thumbnails()
    assert rows[0].photo_thumbnail_base64 is None
    assert all(row.photo_thumbnail_base64 == 'thumbnail' for row in rows[1:])
    assert len(db.statements) >= 3
    assert all(statement._limit_clause.value == 2 for statement in db.statements)
    for statement in db.statements:
        sql = str(statement.compile(dialect=postgresql.dialect()))
        assert 'recipes.instructions' not in sql
        assert 'recipes.nutrition_total' not in sql


@pytest.mark.asyncio
async def test_nutrition_backfill_never_loads_full_photos_and_has_bounded_pages(monkeypatch):
    rows = [SimpleNamespace(id=UUID(int=i), nutrition_total=None if i % 2 else {'kcal': 3},
                            ingredients=[]) for i in range(1, 6)]
    db = MaintenanceSession(rows, photos=False)
    monkeypatch.setattr(session_module, 'async_session_factory', lambda: db)
    monkeypatch.setattr(main, 'BACKFILL_BATCH_SIZE', 2, raising=False)
    monkeypatch.setattr('app.services.nutrition_calculator.compute_recipe_nutrition_total',
                        lambda _: {'kcal': 7})
    await main._backfill_missing_nutrition_totals()
    assert rows[0].nutrition_total == {'kcal': 7}
    assert rows[1].nutrition_total == {'kcal': 3}
    assert len(db.statements) >= 3
    for statement in db.statements:
        assert statement._limit_clause.value == 2
        sql = str(statement.compile(dialect=postgresql.dialect()))
        assert 'recipes.photo_base64' not in sql
        assert 'recipes.photo_thumbnail_base64' not in sql
