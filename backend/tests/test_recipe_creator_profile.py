from datetime import datetime, timedelta, timezone
from uuid import uuid4
import asyncio
import pytest
from sqlalchemy import event, inspect
from app.api.v1.recipes import _recipe_list_options
from sqlalchemy import select
from tests.test_market_recipe_catalog import market_db, catalogue_route_mocks, _catalogue

from app.models.recipe import Recipe
from app.models.user import User
from app.schemas.recipe import RecipeListItemResponse, RecipeResponse


def test_recipe_response_includes_creator_tiktok_username() -> None:
    creator = User(
        id=uuid4(),
        email="autor@example.com",
        password_hash="test",
        display_name="Autor",
        tiktok_username="autor.kuchni",
        is_premium=True,
        premium_expires_at=datetime.now(timezone.utc) + timedelta(days=7),
    )
    recipe = Recipe(
        id=uuid4(),
        name="Przepis użytkownika",
        meal_type="obiad",
        servings=2,
        difficulty="łatwy",
        nutrition_total={"kcal": 300},
        is_active=True,
        created_at=datetime.now(timezone.utc),
        created_by_user_id=creator.id,
        visibility="public",
        creator=creator,
        tags=[],
        ingredients=[],
    )

    response = RecipeResponse.model_validate(recipe)

    assert response.created_by_name == "Autor"
    assert response.created_by_tiktok_username == "autor.kuchni"


def test_recipe_response_hides_creator_tiktok_after_premium_expires() -> None:
    creator = User(
        id=uuid4(),
        email="autor@example.com",
        password_hash="test",
        display_name="Autor",
        tiktok_username="autor.kuchni",
        is_premium=True,
        premium_expires_at=datetime.now(timezone.utc) - timedelta(seconds=1),
    )
    recipe = Recipe(
        id=uuid4(),
        name="Przepis użytkownika",
        meal_type="obiad",
        servings=2,
        difficulty="łatwy",
        nutrition_total={"kcal": 300},
        is_active=True,
        created_at=datetime.now(timezone.utc),
        created_by_user_id=creator.id,
        visibility="public",
        creator=creator,
        tags=[],
        ingredients=[],
    )

    response = RecipeResponse.model_validate(recipe)

    assert response.created_by_name == "Autor"
    assert response.created_by_tiktok_username is None


def test_recipe_list_item_omits_heavy_detail_fields() -> None:
    recipe = Recipe(
        id=uuid4(),
        name="Lekki kafelek przepisu",
        description="Krótki opis widoczny przed odświeżeniem szczegółów.",
        meal_type="obiad",
        servings=2,
        difficulty="łatwy",
        nutrition_total={"kcal": 300, "protein": 20},
        photo_base64="bardzo-duże-zdjęcie-base64",
        instructions=["Krok pierwszy", "Krok drugi"],
        suggested_seasonings=["pieprz"],
        is_active=True,
        created_at=datetime.now(timezone.utc),
        visibility="private",
        tags=[],
        ingredients=[],
    )

    payload = RecipeListItemResponse.model_validate(recipe).model_dump()

    assert payload["name"] == "Lekki kafelek przepisu"
    assert payload["nutrition_total"]["kcal"] == 300
    assert "photo_base64" not in payload
    assert "instructions" not in payload
    assert "suggested_seasonings" not in payload
    assert "ingredients" not in payload


@pytest.mark.parametrize("premium", [True, False])
def test_light_page_already_contains_public_author_without_heavy_or_private_fields(market_db, catalogue_route_mocks, premium):
    creator = User(id=uuid4(), email="private-author@example.invalid", password_hash="private-hash",
        display_name="Autor przepisu", avatar="male", avatar_photo_base64="heavy-avatar" * 10000,
        tiktok_username="autor.kuchni", is_premium=premium, role="user", country_code="PL")
    market_db.add(creator)
    for index in range(30):
        market_db.add(Recipe(id=uuid4(), name=f"Recipe {index:02d}", meal_type="obiad", servings=2,
            difficulty="łatwy", nutrition_total={"kcal": 300}, photo_base64="heavy-recipe" * 10000,
            is_active=True, created_at=datetime.now(timezone.utc), visibility="public", created_by_user_id=creator.id))
    market_db.commit()
    creator_id = creator.id
    market_db.expunge_all()
    statements = []
    @event.listens_for(market_db.get_bind(), "before_cursor_execute")
    def capture(conn, cursor, statement, parameters, context, executemany):
        statements.append(statement)
    user = User(id=uuid4(), email="viewer@example.invalid", password_hash="fixture", country_code="PL")
    rows = asyncio.run(_catalogue(market_db, user))
    data = [RecipeListItemResponse.model_validate(row).model_dump() for row in rows]
    assert len(data) == 30
    assert all(row["created_by_name"] == "Autor przepisu" for row in data)
    assert all(row["created_by_tiktok_username"] == ("autor.kuchni" if premium else None) for row in data)
    assert all(row["created_by_profile_loaded"] is True for row in data)
    assert all("created_by_avatar_photo" not in row and "photo_base64" not in row for row in data)
    assert all("email" not in row and "password_hash" not in row for row in data)
    assert len(statements) == 3  # one page, one tags batch, one small author batch
    author = market_db.get(User, creator_id)
    assert {"email", "password_hash", "avatar_photo_base64"} <= inspect(author).unloaded
    assert not any("users.avatar_photo_base64" in sql or "users.password_hash" in sql or "users.email" in sql for sql in statements)


def test_light_list_hides_expired_tiktok_same_as_detail():
    creator = User(id=uuid4(), display_name="Autor", tiktok_username="not-public-now", role="user", is_premium=True,
        premium_expires_at=datetime.now(timezone.utc) - timedelta(seconds=1))
    row = Recipe(id=uuid4(), name="Recipe", meal_type="obiad", servings=2, difficulty="łatwy",
        nutrition_total={"kcal": 1}, is_active=True, tags=[], created_at=datetime.now(timezone.utc),
        visibility="public", created_by_user_id=creator.id, creator=creator)
    data = RecipeListItemResponse.model_validate(row)
    assert data.created_by_name == "Autor"
    assert data.created_by_tiktok_username is None
