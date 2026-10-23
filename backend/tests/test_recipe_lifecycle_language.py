"""UK recipe copy must not change PL guards, status codes or write order."""

from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock
from uuid import uuid4

import pytest
from fastapi import HTTPException

from app.api.v1 import recipes
from app.core.exceptions import NotFoundException


def user(country):
    return SimpleNamespace(id=uuid4(), country_code=country, role="user", display_name="Example user")


def database(row=None):
    result = MagicMock()
    result.scalar_one_or_none.return_value = row
    result.scalars.return_value.all.return_value = [] if row is None else [row]
    return SimpleNamespace(get=AsyncMock(return_value=row), execute=AsyncMock(return_value=result),
        commit=AsyncMock(), add=MagicMock(), delete=AsyncMock())


@pytest.mark.asyncio
@pytest.mark.parametrize("country", ["PL", "GB"])
@pytest.mark.parametrize("operation", ["detail", "variant", "approve", "reject", "favorite", "publish", "delete"])
async def test_missing_recipe_is_localised_before_any_mutation(country, operation):
    db, account, identity = database(), user(country), uuid4()
    with pytest.raises(NotFoundException) as failure:
        if operation == "variant":
            await recipes.save_recipe_variant(identity, recipes.RecipeVariantCreate(
                ingredients=[dict(product_id=uuid4(), quantity=100, unit="g")]), account, db)
        else:
            route = {"detail": recipes.get_recipe, "approve": recipes.approve_recipe,
                "reject": recipes.reject_recipe, "favorite": recipes.add_recipe_favorite,
                "publish": recipes.request_publish_recipe, "delete": recipes.delete_recipe}[operation]
            await route(identity, account, db)
    assert failure.value.status_code == 404
    assert failure.value.detail == (f"Recipe {identity} was not found." if country == "GB"
        else f"Przepis o ID {identity} nie został znaleziony")
    db.commit.assert_not_awaited()
    db.add.assert_not_called()
    db.delete.assert_not_awaited()


@pytest.mark.asyncio
@pytest.mark.parametrize("country", ["PL", "GB"])
@pytest.mark.parametrize("visibility", ["pending", "public", "rejected", "other"])
async def test_publish_states_keep_existing_rules(country, visibility):
    account = user(country)
    row = SimpleNamespace(created_by_user_id=account.id, visibility=visibility)
    db = database(row)
    pl = {"pending": "Ten przepis już czeka na przegląd administratora.",
        "public": "Ten przepis jest już publiczny.",
        "rejected": "Ten przepis został odrzucony — skontaktuj się z administratorem, żeby dowiedzieć się dlaczego.",
        "other": "Tego przepisu nie można teraz opublikować."}
    en = {"pending": "This recipe is already awaiting administrator review.",
        "public": "This recipe is already public.",
        "rejected": "This recipe was rejected. Contact the administrator to find out why.",
        "other": "This recipe cannot be published right now."}
    with pytest.raises(HTTPException) as failure:
        await recipes.request_publish_recipe(uuid4(), account, db)
    assert failure.value.status_code == 400
    assert failure.value.detail == (en if country == "GB" else pl)[visibility]
    assert row.visibility == visibility
    db.commit.assert_not_awaited()


@pytest.mark.asyncio
@pytest.mark.parametrize("country", ["PL", "GB"])
@pytest.mark.parametrize("operation", ["publish_foreign", "delete_foreign", "delete_system"])
async def test_ownership_and_system_recipe_denials_are_unchanged(country, operation):
    row = SimpleNamespace(created_by_user_id=None if operation == "delete_system" else uuid4())
    db = database(row)
    en = {"publish_foreign": "You can only publish your own recipe.",
        "delete_foreign": "You can only delete your own recipe.",
        "delete_system": "Official recipes supplied with the app cannot be deleted."}
    pl = {"publish_foreign": "Możesz opublikować tylko własny przepis.",
        "delete_foreign": "Możesz usunąć tylko własny przepis.",
        "delete_system": "Nie można usunąć oficjalnego przepisu dostarczonego z aplikacją."}
    with pytest.raises(HTTPException) as failure:
        route = recipes.request_publish_recipe if operation == "publish_foreign" else recipes.delete_recipe
        await route(uuid4(), user(country), db)
    assert failure.value.status_code == 403
    assert failure.value.detail == (en if country == "GB" else pl)[operation]
    db.commit.assert_not_awaited()
    db.delete.assert_not_awaited()


@pytest.mark.asyncio
@pytest.mark.parametrize("country", ["PL", "GB"])
@pytest.mark.parametrize("scenario", ["missing", "nutrition", "pack"])
async def test_manual_recipe_ingredient_validation_uses_account_language(country, scenario):
    account, identity = user(country), uuid4()
    row = None if scenario == "missing" else SimpleNamespace(id=identity, name="Example product",
        created_by_user_id=None, serving_quantity=None,
        nutrition_per_100={} if scenario == "nutrition" else {"kcal": 100, "protein": 1, "fat": 0, "carbs": 24})
    db = database(row)
    payload = recipes.RecipeCreate(name="Example", meal_type="obiad", ingredients=[dict(
        product_id=identity, quantity=1, unit="opak" if scenario == "pack" else "g")])
    en = {"missing": f"Available product(s) not found: {identity}",
        "nutrition": 'Product "Example product" does not have complete nutrition information. Add the label values.',
        "pack": 'The full pack size of "Example product" is unknown. Choose grams or millilitres.'}
    pl = {"missing": f"Nie znaleziono dostępnego produktu/produktów: {identity}",
        "nutrition": 'Produkt "Example product" nie ma pełnych wartości odżywczych. Uzupełnij dane z etykiety.',
        "pack": 'Nie znamy masy całego opakowania produktu "Example product". Wybierz gramy lub mililitry.'}
    with pytest.raises(HTTPException) as failure:
        await recipes.create_recipe(payload, account, db)
    assert failure.value.status_code == (400 if scenario == "missing" else 422)
    assert failure.value.detail == (en if country == "GB" else pl)[scenario]
    db.add.assert_not_called()
    db.commit.assert_not_awaited()


@pytest.mark.asyncio
@pytest.mark.parametrize("country", ["PL", "GB"])
@pytest.mark.parametrize("scenario", ["missing", "hidden", "pending", "success"])
async def test_photo_submission_language_preserves_visibility_and_pending_guard(monkeypatch, country, scenario):
    account = user(country)
    row = None if scenario == "missing" else SimpleNamespace(id=uuid4(), name="Example",
        created_by_user_id=uuid4() if scenario == "hidden" else account.id,
        visibility="private", pending_photo_base64="existing" if scenario == "pending" else None)
    db = database(row)
    monkeypatch.setattr("app.core.rate_limit.enforce_user_rate_limit", lambda *args: None)
    monkeypatch.setattr("app.services.admin_notifications.notify_admins_pending_review", AsyncMock())
    payload = recipes.RecipePhotoSubmission.model_construct(photo_base64="fixture-only")
    if scenario == "success":
        response = await recipes.submit_recipe_photo(uuid4(), payload, account, db)
        assert response == {"detail": ("Photo submitted. It will appear once approved by an administrator."
            if country == "GB" else "Zdjęcie zgłoszone. Pojawi się po akceptacji przez administratora.")}
        assert row.pending_photo_base64 == "fixture-only"
        assert row.pending_photo_user_id == account.id
        db.commit.assert_awaited_once()
        return
    with pytest.raises((NotFoundException, HTTPException)) as failure:
        await recipes.submit_recipe_photo(uuid4(), payload, account, db)
    assert failure.value.status_code == (409 if scenario == "pending" else 404)
    en = "A photo for this recipe is already awaiting approval." if scenario == "pending" else "Recipe not found."
    pl = "Do tego przepisu zgłoszono już zdjęcie, które czeka na akceptację." if scenario == "pending" else "Nie znaleziono przepisu"
    assert failure.value.detail == (en if country == "GB" else pl)
    db.add.assert_not_called()
    db.commit.assert_not_awaited()


@pytest.mark.asyncio
@pytest.mark.parametrize("country", ["PL", "GB"])
@pytest.mark.parametrize("operation", ["approve", "reject"])
@pytest.mark.parametrize("exists", [False, True])
async def test_missing_pending_photo_keeps_moderation_404(country, operation, exists):
    db = database(SimpleNamespace(pending_photo_base64=None) if exists else None)
    route = recipes.approve_recipe_photo if operation == "approve" else recipes.reject_recipe_photo
    with pytest.raises(NotFoundException) as failure:
        await route(uuid4(), db, user(country))
    assert failure.value.status_code == 404
    assert failure.value.detail == ("No pending photo was found for this recipe." if country == "GB"
        else "Brak zdjęcia oczekującego dla tego przepisu")
    db.add.assert_not_called()
    db.commit.assert_not_awaited()


@pytest.mark.asyncio
@pytest.mark.parametrize("country", ["PL", "GB"])
async def test_empty_pantry_match_does_not_query(country):
    db = database()
    with pytest.raises(HTTPException) as failure:
        await recipes.match_recipes_by_ingredients(recipes.MatchByIngredientsRequest(product_ids=[]), user(country), db)
    assert failure.value.status_code == 400
    assert failure.value.detail == ("Choose at least one ingredient you have." if country == "GB"
        else "Podaj przynajmniej jeden posiadany składnik")
    db.execute.assert_not_awaited()


@pytest.mark.asyncio
@pytest.mark.parametrize("country", ["PL", "GB"])
@pytest.mark.parametrize("operation", ["photo", "report"])
async def test_recipe_rate_limits_keep_retry_header_and_precede_database(monkeypatch, country, operation):
    def denied(*args):
        raise HTTPException(status_code=429, detail="Zbyt wiele prób. Spróbuj ponownie za 42 s.",
            headers={"Retry-After": "42"})
    monkeypatch.setattr("app.core.rate_limit.enforce_user_rate_limit", denied)
    db, account = database(), user(country)
    with pytest.raises(HTTPException) as failure:
        if operation == "photo":
            await recipes.submit_recipe_photo(uuid4(), recipes.RecipePhotoSubmission.model_construct(
                photo_base64="fixture-only"), account, db)
        else:
            await recipes.report_recipe(uuid4(), recipes.ContentReportCreate(reason="spam"), account, db)
    assert failure.value.status_code == 429
    assert failure.value.headers == {"Retry-After": "42"}
    expected = "Too many photo submissions. Please try again later." if operation == "photo" else "Too many content reports. Please try again later."
    assert failure.value.detail == (expected if country == "GB" else "Zbyt wiele prób. Spróbuj ponownie za 42 s.")
    db.get.assert_not_awaited()
    db.execute.assert_not_awaited()
    db.commit.assert_not_awaited()


@pytest.mark.asyncio
@pytest.mark.parametrize("country", ["PL", "GB"])
async def test_missing_report_target_does_not_create_report(monkeypatch, country):
    monkeypatch.setattr("app.core.rate_limit.enforce_user_rate_limit", lambda *args: None)
    db = database()
    with pytest.raises(NotFoundException) as failure:
        await recipes.report_recipe(uuid4(), recipes.ContentReportCreate(reason="spam"), user(country), db)
    assert failure.value.status_code == 404
    assert failure.value.detail == ("Recipe not found." if country == "GB" else "Nie znaleziono przepisu")
    db.add.assert_not_called()
    db.commit.assert_not_awaited()


@pytest.mark.asyncio
@pytest.mark.parametrize("country", ["PL", "GB"])
async def test_foreign_shop_guard_is_localised_without_catalogue_query(monkeypatch, country):
    lookup = AsyncMock(return_value=None)
    monkeypatch.setattr(recipes, "get_store_in_account_market", lookup)
    db, account, shop_id = database(), user(country), uuid4()
    with pytest.raises(NotFoundException) as failure:
        await recipes.list_available_recipes(shop_id, skip=0, limit=30, current_user=account, db=db)
    assert failure.value.status_code == 404
    assert failure.value.detail == ("This shop is not available in your account's country." if country == "GB"
        else "Sklep nie jest dostępny w kraju tego konta.")
    db.execute.assert_not_awaited()
    db.commit.assert_not_awaited()
