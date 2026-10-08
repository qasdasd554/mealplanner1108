from datetime import datetime, timedelta, timezone
from uuid import uuid4

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
