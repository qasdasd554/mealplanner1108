"""Explicit catalogue/profile/access errors are localised without policy changes."""

from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock
from uuid import uuid4

import pytest
from fastapi import BackgroundTasks, HTTPException

from app.api.v1 import products, users
from app.core.exceptions import NotFoundException
from app.services.recipe_access import ensure_recipe_access


def _user(country):
    return SimpleNamespace(id=uuid4(), country_code=country, role="user", is_premium=False)


def _db(value=None):
    result = MagicMock()
    result.scalar_one_or_none.return_value = value
    return SimpleNamespace(get=AsyncMock(return_value=value), execute=AsyncMock(return_value=result),
        scalar=AsyncMock(return_value=None), add=MagicMock(), delete=AsyncMock(), commit=AsyncMock())


@pytest.mark.asyncio
@pytest.mark.parametrize("country", ["PL", "GB"])
@pytest.mark.parametrize("scenario", ["missing", "inactive", "pending", "private"])
async def test_recipe_access_denials_keep_same_404_for_hidden_or_missing(country, scenario):
    user = _user(country)
    recipe = None if scenario == "missing" else SimpleNamespace(id=uuid4(),
        is_active=scenario != "inactive", created_by_user_id=uuid4(),
        visibility="private" if scenario == "private" else "pending")
    db = _db()
    with pytest.raises(NotFoundException) as failure:
        await ensure_recipe_access(db, recipe, user)
    assert failure.value.status_code == 404
    assert failure.value.detail == ("Recipe not found." if country == "GB" else "Przepis nie został znaleziony.")
    assert db.execute.await_count == (1 if scenario == "private" else 0)
    db.commit.assert_not_awaited()


@pytest.mark.asyncio
@pytest.mark.parametrize("country", ["PL", "GB"])
@pytest.mark.parametrize("operation", ["lookup", "recognise", "confirm", "submit"])
async def test_invalid_barcode_guard_precedes_external_lookup_or_writes(monkeypatch, country, operation):
    db, user = _db(), _user(country)
    external = AsyncMock()
    monkeypatch.setattr(products, "lookup_barcode_external", external)
    monkeypatch.setattr("app.core.rate_limit.enforce_user_rate_limit", lambda *args: None)
    with pytest.raises(HTTPException) as failure:
        if operation == "lookup":
            await products.lookup_barcode("123", BackgroundTasks(), db, user)
        elif operation == "recognise":
            await products.recognize_product_from_label(products.ProductLabelRecognitionRequest.model_construct(barcode="123"), user)
        elif operation == "confirm":
            await products.confirm_product_label(products.ProductLabelConfirmation.model_construct(barcode="123"), db, user)
        else:
            await products.submit_product(products.ProductSubmission.model_construct(barcode="123", store_ids=[]), db, user)
    assert failure.value.status_code == 400
    assert failure.value.detail == ("Invalid EAN/UPC barcode." if country == "GB" else "Nieprawidłowy kod EAN/UPC")
    external.assert_not_awaited()
    db.execute.assert_not_awaited()
    db.commit.assert_not_awaited()


@pytest.mark.asyncio
@pytest.mark.parametrize("country", ["PL", "GB"])
@pytest.mark.parametrize("operation", ["read", "substitutes", "edit", "delete", "ingredient"])
async def test_missing_catalogue_product_keeps_visibility_status_and_no_write(country, operation):
    db, user, product_id = _db(), _user(country), uuid4()
    with pytest.raises((HTTPException, NotFoundException)) as failure:
        if operation == "read":
            await products.get_product(product_id, db, user)
        elif operation == "substitutes":
            await products.get_product_substitutes(product_id, None, db, user)
        elif operation == "edit":
            await products.update_own_product(product_id, products.ProductSubmission.model_construct(), db, user)
        elif operation == "delete":
            await products.delete_own_product(product_id, db, user)
        else:
            await products.resolve_recipe_ingredient_product(products.RecipeIngredientProductCreate(name="Original name", existing_product_id=product_id), db, user)
    assert failure.value.status_code == 404
    expected = (f"Product {product_id} was not found." if country == "GB" else f"Produkt o ID {product_id} nie został znaleziony") if operation in {"read", "substitutes"} else (
        "Product not found." if country == "GB" else "Nie znaleziono produktu")
    assert failure.value.detail == expected
    db.commit.assert_not_awaited()


@pytest.mark.asyncio
@pytest.mark.parametrize("country", ["PL", "GB"])
@pytest.mark.parametrize("operation", ["edit", "delete"])
async def test_product_ownership_guard_is_not_relaxed_by_localisation(country, operation):
    db = _db(SimpleNamespace(created_by_user_id=uuid4()))
    with pytest.raises(HTTPException) as failure:
        if operation == "edit":
            await products.update_own_product(uuid4(), products.ProductSubmission.model_construct(), db, _user(country))
        else:
            await products.delete_own_product(uuid4(), db, _user(country))
    assert failure.value.status_code == 403
    assert failure.value.detail == (("You can only edit your own submissions." if operation == "edit" else "You can only delete your own submissions.") if country == "GB" else (
        "Możesz edytować tylko własne zgłoszenia." if operation == "edit" else "Możesz usunąć tylko własne zgłoszenia."))
    db.commit.assert_not_awaited()


@pytest.mark.parametrize("country", ["PL", "GB"])
def test_tiktok_premium_guard_keeps_field_clearing_available(country):
    user = _user(country)
    with pytest.raises(HTTPException) as failure:
        users.ensure_tiktok_premium_access({"tiktok_username": "original_name"}, user)
    assert failure.value.status_code == 403
    assert failure.value.detail == ("Adding a TikTok profile requires Premium." if country == "GB"
        else "Dodanie profilu TikTok jest dostępne wyłącznie w Premium.")
    users.ensure_tiktok_premium_access({"tiktok_username": None}, user)


@pytest.mark.asyncio
@pytest.mark.parametrize("country", ["PL", "GB"])
async def test_profile_store_country_guard_precedes_any_profile_write(monkeypatch, country):
    db = _db()
    monkeypatch.setattr(users, "get_store_in_account_market", AsyncMock(return_value=None))
    with pytest.raises(HTTPException) as failure:
        await users.update_me(users.UserProfileUpdate(preferred_store_id=uuid4()), _user(country), db)
    assert failure.value.status_code == 400
    assert failure.value.detail == ("This shop is not available in your account's country." if country == "GB"
        else "Wskazany sklep nie jest dostępny w kraju tego konta")
    db.commit.assert_not_awaited()


@pytest.mark.asyncio
@pytest.mark.parametrize("country", ["PL", "GB"])
@pytest.mark.parametrize("self_block", [True, False])
async def test_block_user_self_or_missing_target_keeps_existing_rules(country, self_block):
    db, user = _db(), _user(country)
    with pytest.raises(HTTPException) as failure:
        await users.block_user(user.id if self_block else uuid4(), user, db)
    assert failure.value.status_code == (400 if self_block else 404)
    assert failure.value.detail == (("You cannot block yourself." if self_block else "User not found.") if country == "GB" else (
        "Nie można zablokować samego siebie" if self_block else "Użytkownik nie istnieje"))
    db.commit.assert_not_awaited()


@pytest.mark.parametrize("country", ["PL", "GB"])
def test_recipe_ingredient_missing_nutrition_keeps_422_and_completeness_rule(country):
    with pytest.raises(HTTPException) as failure:
        products._require_complete_recipe_nutrition({"kcal": 100}, country_code=country)
    assert failure.value.status_code == 422
    assert failure.value.detail == ("Complete nutrition information was not found. Add the label values before using this product in a recipe." if country == "GB"
        else "Nie odnaleziono pełnych wartości odżywczych produktu. Uzupełnij dane z etykiety przed dodaniem go do przepisu.")
    products._require_complete_recipe_nutrition({"kcal": 100, "protein": 0, "fat": 0, "carbs": 25}, country_code=country)


@pytest.mark.asyncio
@pytest.mark.parametrize("country", ["PL", "GB"])
async def test_product_store_market_validation_keeps_400(monkeypatch, country):
    db = _db()
    lookup = AsyncMock(return_value=None)
    monkeypatch.setattr(products, "get_store_in_account_market", lookup)
    with pytest.raises(HTTPException) as failure:
        await products._validate_submission_stores(db, [uuid4()], _user(country))
    assert failure.value.status_code == 400
    assert failure.value.detail == ("Choose a shop available in your account's country." if country == "GB"
        else "Wybierz sklep dostępny w kraju przypisanym do konta.")
    db.commit.assert_not_awaited()


@pytest.mark.asyncio
@pytest.mark.parametrize("country", ["PL", "GB"])
async def test_duplicate_product_reward_still_stops_before_point_mutation(monkeypatch, country):
    db = _db()
    db.scalar.return_value = uuid4()
    monkeypatch.setattr("app.core.rate_limit.enforce_user_rate_limit", lambda *args: None)
    with pytest.raises(HTTPException) as failure:
        await products.submit_product(products.ProductSubmission(name="Original product"), db, _user(country))
    assert failure.value.status_code == 409
    assert failure.value.detail == ("You have already added this product and received its reward." if country == "GB"
        else "Ten produkt został już przez Ciebie dodany i nagrodzony.")
    db.add.assert_not_called()
    db.commit.assert_not_awaited()


@pytest.mark.asyncio
@pytest.mark.parametrize("country", ["PL", "GB"])
async def test_own_product_edit_invalid_barcode_does_not_commit(country):
    user = _user(country)
    product = SimpleNamespace(created_by_user_id=user.id, review_status="pending", barcode=None)
    db = _db(product)
    with pytest.raises(HTTPException) as failure:
        await products.update_own_product(uuid4(), products.ProductSubmission(name="Original product", barcode="123"), db, user)
    assert failure.value.status_code == 400
    assert failure.value.detail == ("Invalid EAN/UPC barcode." if country == "GB" else "Nieprawidłowy kod EAN/UPC")
    db.add.assert_not_called()
    db.commit.assert_not_awaited()


@pytest.mark.asyncio
@pytest.mark.parametrize("country", ["PL", "GB"])
@pytest.mark.parametrize("operation", ["ban_self", "ban_admin", "ban_missing", "unban_missing", "report_missing", "content_missing", "content_unknown"])
async def test_administrator_errors_keep_status_and_do_not_modify_records(country, operation):
    user = _user(country)
    db = _db(SimpleNamespace(role="admin") if operation == "ban_admin" else
        SimpleNamespace(content_type="unknown") if operation == "content_unknown" else None)
    with pytest.raises(HTTPException) as failure:
        if operation.startswith("ban"):
            await users.ban_user(user.id if operation == "ban_self" else uuid4(), users.BanUserRequest(), db, user)
        elif operation == "unban_missing":
            await users.unban_user(uuid4(), db, user)
        elif operation == "report_missing":
            await users.update_report_status(uuid4(), users.ReportStatusUpdate(status="resolved"), db, user)
        else:
            await users.delete_reported_content(uuid4(), db, user)
    messages = {
        "ban_self": (400, "Nie można zablokować własnego konta", "You cannot ban your own account."),
        "ban_admin": (400, "Nie można zablokować konta administratora", "You cannot ban an administrator account."),
        "ban_missing": (404, "Użytkownik nie istnieje", "User not found."),
        "unban_missing": (404, "Użytkownik nie istnieje", "User not found."),
        "report_missing": (404, "Nie znaleziono zgłoszenia", "Submission not found."),
        "content_missing": (404, "Nie znaleziono zgłoszenia", "Submission not found."),
        "content_unknown": (400, "Nieznany typ zgłoszonej treści", "Unknown reported content type."),
    }
    status, polish, english = messages[operation]
    assert failure.value.status_code == status
    assert failure.value.detail == (english if country == "GB" else polish)
    db.add.assert_not_called()
    db.delete.assert_not_awaited()
    db.commit.assert_not_awaited()
