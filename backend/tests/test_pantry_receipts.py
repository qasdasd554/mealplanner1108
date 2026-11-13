import base64
import json
from datetime import datetime, timedelta, timezone
from io import BytesIO
from unittest.mock import AsyncMock
from uuid import uuid4

import httpx
import pytest
from fastapi import FastAPI
from PIL import Image
from sqlalchemy import select

from app.api.deps import get_current_user
from app.api.v1.pantry import router
from app.db.session import get_db
from app.models import PantryItem, PantryReceipt, Product, User
from app.services import pantry_receipt_recognition as recognition
from tests.test_meal_plan_lifecycle import db


def _user(db, country, *, premium=True):
    user = User(id=uuid4(), email=f"{uuid4()}@example.test", password_hash="fixture",
                country_code=country, role="user", is_premium=premium)
    db.session.add(user)
    db.session.commit()
    return user


def _app(db, user):
    app = FastAPI()
    app.include_router(router, prefix="/pantry")
    app.dependency_overrides[get_current_user] = lambda: user
    db.close = AsyncMock()
    app.dependency_overrides[get_db] = lambda: db
    return app


def _photo():
    file = BytesIO()
    image = Image.new("RGB", (120, 240), "white")
    exif = image.getexif()
    exif[315] = "Fixture metadata"
    image.save(file, format="JPEG", exif=exif)
    return base64.b64encode(file.getvalue()).decode("ascii")


@pytest.mark.asyncio
@pytest.mark.parametrize("country,food", [("PL", "Marchew"), ("GB", "Carrots"), ("DE", "Karotten")])
async def test_receipt_flow_filters_and_imports_only_confirmed_food_once(db, monkeypatch, country, food):
    user = _user(db, country)
    other = _user(db, country)
    product = Product(id=uuid4(), name=food, unit="kg", submitted_country_code=country)
    db.add(product)
    await db.flush()
    db.add(PantryItem(user_id=user.id, product_id=product.id, quantity=0.3, unit="kg"))
    await db.commit()

    calls = []

    async def gemini(parts, **options):
        calls.append(options["country_code"])
        assert {"PL": "Polish", "GB": "British English", "DE": "German"}[country] in parts[0]["text"]
        image = Image.open(BytesIO(base64.b64decode(parts[1]["inlineData"]["data"])))
        assert not image.getexif()
        return json.dumps({"items": [
            {"kind": "human_food", "receipt_line": food, "name": food, "quantity": 200, "unit": "g"},
            {"kind": "human_food", "receipt_line": food, "name": food, "quantity": 100, "unit": "g"},
            {"kind": "human_food", "receipt_line": "OAT DRINK", "name": "Oat drink", "quantity": 2, "unit": "opak"},
            {"kind": "human_food", "receipt_line": "HUNDEFUTTER" if country == "DE" else "DOG FOOD",
             "name": "Hundefutter" if country == "DE" else "Dog food", "quantity": 1, "unit": "opak"},
            {"kind": "non_food", "receipt_line": "DETERGENT", "name": "Detergent", "quantity": 1, "unit": "opak"},
            {"kind": "unknown", "receipt_line": "ABC", "name": "ABC", "quantity": 1, "unit": "opak"},
        ]})

    monkeypatch.setattr(recognition, "_call_gemini", gemini)
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=_app(db, user)), base_url="http://test") as client:
        response = await client.post("/pantry/receipt/scan", json={"photo": _photo()})
        assert response.status_code == 200, response.text
        preview = response.json()
        assert [row["name"] for row in preview["items"]] == [food, food, "Oat drink"]
        assert calls == [country]
        assert len(db.session.scalars(select(PantryItem)).all()) == 1
        payload = {"token": preview["token"], "items": [
            {"index": 0, "quantity": 225, "unit": "g"},
            {"index": 1, "quantity": 100, "unit": "g"},
            {"index": 2, "quantity": 2, "unit": "opak"},
        ]}
        async with httpx.AsyncClient(transport=httpx.ASGITransport(app=_app(db, other)), base_url="http://test") as foreign:
            assert (await foreign.post("/pantry/receipt/save", json=payload)).status_code == 422
        response = await client.post("/pantry/receipt/save", json=payload)
        assert response.status_code == 200, response.text
        assert response.json() == {"saved_count": 2, "skipped_count": 0, "already_saved": False}
        retry = await client.post("/pantry/receipt/save", json=payload)
        assert retry.status_code == 200 and retry.json()["already_saved"] is True
        pantry = await client.get("/pantry/")
        assert pantry.status_code == 200, pantry.text
        items = {item["product"]["name"]: item for item in pantry.json()}
        assert items[food]["quantity"] == 625 and items[food]["unit"] == "g"
        assert items["Oat drink"]["quantity"] == 2 and items["Oat drink"]["unit"] == "opak"
        assert items["Oat drink"]["product"]["review_status"] == "private"
        assert items["Oat drink"]["product"]["serving_quantity"] is None
        assert len(db.session.scalars(select(PantryReceipt)).all()) == 1


@pytest.mark.asyncio
@pytest.mark.parametrize("country,expired", [("PL", False), ("GB", True), ("DE", False), ("DE", True)])
async def test_standard_and_expired_accounts_cannot_scan_or_save(db, monkeypatch, country, expired):
    user = _user(db, country, premium=expired)
    if expired:
        user.premium_expires_at = datetime.now(timezone.utc) - timedelta(hours=1)

    async def unexpected(*args, **kwargs):
        pytest.fail("Premium checks must run before calling Gemini")

    monkeypatch.setattr(recognition, "_call_gemini", unexpected)
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=_app(db, user)), base_url="http://test") as client:
        scan = await client.post("/pantry/receipt/scan", json={"photo": _photo()})
        save = await client.post("/pantry/receipt/save", json={"token": "invalid", "items": [
            {"index": 0, "quantity": 1, "unit": "opak"},
        ]})
        assert scan.status_code == save.status_code == 403
        assert db.session.scalar(select(PantryReceipt)) is None


@pytest.mark.asyncio
async def test_invalid_photo_is_not_sent_to_ai(db, monkeypatch):
    user = _user(db, "GB")

    async def unexpected(*args, **kwargs):
        pytest.fail("Non-image input must not reach Gemini")

    monkeypatch.setattr(recognition, "_call_gemini", unexpected)
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=_app(db, user)), base_url="http://test") as client:
        response = await client.post("/pantry/receipt/scan", json={"photo": "Zml4dHVyZQ=="})
        assert response.status_code == 422
        assert "Zml4dHVyZQ==" not in response.text
