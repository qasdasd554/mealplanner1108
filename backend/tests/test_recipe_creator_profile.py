from datetime import datetime, timedelta, timezone
from uuid import uuid4

from app.models.recipe import Recipe
from app.models.user import User
from app.schemas.recipe import RecipeResponse


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
