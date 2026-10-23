import asyncio
from datetime import datetime, timedelta, timezone
from uuid import uuid4

import pytest
from fastapi import HTTPException
from sqlalchemy import create_engine, text
from sqlalchemy.orm import Session
from starlette.requests import Request

from app.db.session import Base
from app.models import User
from app.models.purchase_campaign import PurchaseCampaign
from app.api.v1 import purchase_campaigns as api


def campaign(country, product_id):
    now = datetime.now(timezone.utc)
    item = PurchaseCampaign(
        id=uuid4(), name=f"{country} offer", kind="points", product_id=product_id,
        discount_percent=30, audience="all", starts_at=now - timedelta(days=1),
        ends_at=now + timedelta(days=1), platform="android", is_active=True,
    )
    item.country_code = country
    return item


class AsyncAdapter:
    def __init__(self, db):
        self.db = db

    def add(self, item):
        self.db.add(item)

    async def execute(self, statement):
        return self.db.execute(statement)

    async def scalar(self, statement):
        return self.db.scalar(statement)

    async def commit(self):
        self.db.commit()

    async def refresh(self, item):
        self.db.refresh(item)

    async def delete(self, item):
        self.db.delete(item)


async def scenario(callback):
    engine = create_engine("sqlite://")
    try:
        Base.metadata.create_all(engine)
        with Session(engine, expire_on_commit=False) as db:
            admin = User(id=uuid4(), email="admin@example.invalid", role="admin", country_code="PL", password_hash="fixture")
            users = {country: User(id=uuid4(), email=f"{country.lower()}@example.invalid", country_code=country, password_hash="fixture") for country in ("PL", "GB")}
            rows = [campaign("PL", "points_10"), campaign("GB", "points_20")]
            db.add_all([admin, *users.values(), *rows])
            db.commit()
            await callback(AsyncAdapter(db), admin, users, rows)
    finally:
        engine.dispose()


@pytest.mark.parametrize("country,expected", [("PL", "points_10"), ("GB", "points_20")])
def test_active_campaigns_never_cross_account_markets(country, expected):
    async def check(db, admin, users, rows):
        request = Request({"type": "http", "headers": [(b"x-platform", b"android"), (b"x-market", b"PL" if country == "GB" else b"GB")]})
        result = await api.active_campaigns(request, db, users[country])
        assert [item["product_id"] for item in result] == [expected]
        assert users[country].country_code == country
    asyncio.run(scenario(check))


def test_admin_listing_and_writes_require_the_selected_market():
    async def check(db, admin, users, rows):
        assert len(await api.list_campaigns(db, admin, market="GB")) == 1
        assert len(await api.list_campaigns(db, admin)) == 1
        for operation in (
            lambda: api.set_campaign_active(rows[1].id, False, db, admin, market="PL"),
            lambda: api.delete_campaign(rows[1].id, db, admin, market="PL"),
        ):
            with pytest.raises(HTTPException) as caught:
                await operation()
            assert caught.value.status_code == 404
        await db.refresh(rows[1])
        assert rows[1].is_active is True
        changed = await api.set_campaign_active(rows[1].id, False, db, admin, market="GB")
        assert changed["country_code"] == "GB" and not changed["is_active"]
        assert admin.country_code == "PL"
    asyncio.run(scenario(check))


def test_targeted_campaign_cannot_address_a_different_country():
    async def check(db, admin, users, rows):
        now = datetime.now(timezone.utc)
        payload = api.CampaignCreate(name="Selected user", kind="premium", product_id="premium_monthly",
            discount_percent=30, audience="user", target_email=users["PL"].email,
            starts_at=now, ends_at=now+timedelta(days=1), platform="android",
            android_base_plan_id="monthly", android_offer_id="discount")
        with pytest.raises(HTTPException) as caught:
            await api.create_campaign(payload, db, admin, market="GB")
        assert caught.value.status_code == 404
        payload.target_email = users["GB"].email
        created = await api.create_campaign(payload, db, admin, market="GB")
        assert created["country_code"] == "GB"
        assert created["is_active"] is False
    asyncio.run(scenario(check))


def test_old_campaign_migration_is_idempotent_and_preserves_values():
    async def check():
        from app.db.campaign_market_schema import ensure_campaign_market_schema
        engine = create_engine("sqlite://")
        try:
            with engine.begin() as raw:
                raw.execute(text("CREATE TABLE purchase_campaigns (id TEXT PRIMARY KEY, name TEXT NOT NULL, is_active BOOLEAN NOT NULL)"))
                raw.execute(text("INSERT INTO purchase_campaigns VALUES ('old', 'Original campaign', 1)"))
                connection = AsyncAdapter(raw)
                connection.dialect = raw.dialect
                for _ in range(2):
                    await ensure_campaign_market_schema(connection)
                row = raw.execute(text("SELECT * FROM purchase_campaigns")).mappings().one()
                assert dict(row) == {"id": "old", "name": "Original campaign", "is_active": 1, "country_code": "PL"}
                with pytest.raises(Exception):
                    raw.execute(text("UPDATE purchase_campaigns SET country_code='XX'"))
        finally:
            engine.dispose()
    asyncio.run(check())
