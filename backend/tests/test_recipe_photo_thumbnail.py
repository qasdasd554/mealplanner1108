import base64
import io
from datetime import datetime, timezone
from types import SimpleNamespace
from uuid import uuid4

from PIL import Image

from app.services.recipe_photo_thumbnail import create_recipe_photo_thumbnail
from app.schemas.recipe import RecipeListItemResponse


def _large_photo_base64() -> str:
    image = Image.new("RGB", (1200, 800), (20, 160, 90))
    output = io.BytesIO()
    image.save(output, format="PNG")
    return base64.b64encode(output.getvalue()).decode()


def test_thumbnail_is_small_valid_jpeg() -> None:
    original = _large_photo_base64()
    thumbnail = create_recipe_photo_thumbnail(original)

    assert thumbnail is not None
    assert len(thumbnail) < len(original)
    decoded = base64.b64decode(thumbnail)
    with Image.open(io.BytesIO(decoded)) as image:
        assert image.format == "JPEG"
        assert image.width <= 480
        assert image.height <= 480


def test_invalid_image_does_not_break_recipe_creation() -> None:
    invalid_but_base64 = base64.b64encode(b"not-an-image").decode()
    assert create_recipe_photo_thumbnail(invalid_but_base64) is None


def test_recipe_list_returns_thumbnail_without_full_photo() -> None:
    row = SimpleNamespace(
        id=uuid4(),
        name="Przepis użytkownika",
        description=None,
        cuisine=None,
        meal_type="obiad",
        prep_time_min=10,
        cook_time_min=10,
        servings=2,
        difficulty="łatwy",
        nutrition_total={"kcal": 300},
        image_url=None,
        photo_thumbnail_base64="miniatura",
        photo_base64="pełne-zdjęcie-nie-może-trafić-na-listę",
        is_active=True,
        tags=[],
        created_at=datetime.now(timezone.utc),
        is_favorite=False,
        is_own_recipe=False,
        visibility="public",
        created_by_user_id=uuid4(),
    )

    payload = RecipeListItemResponse.model_validate(row).model_dump()

    assert payload["photo_thumbnail_base64"] == "miniatura"
    assert "photo_base64" not in payload
