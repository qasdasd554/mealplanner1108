"""Regresje wspólnego pola wyszukiwania przepisów."""

from sqlalchemy import select
from sqlalchemy.dialects import postgresql

from app.api.v1.recipes import _recipe_search_filter
from app.models import Recipe


def _compiled_search(term: str) -> str:
    statement = select(Recipe.id).where(_recipe_search_filter(term))
    return str(
        statement.compile(
            dialect=postgresql.dialect(),
            compile_kwargs={"literal_binds": True},
        )
    ).lower()


def test_recipe_search_covers_title_author_tiktok_and_ingredient() -> None:
    sql = _compiled_search("kurczak")

    assert "recipes.name" in sql
    assert "users.display_name" in sql
    assert "users.tiktok_username" in sql
    assert "products.name" in sql
    assert "recipe_ingredients.recipe_id = recipes.id" in sql
    assert "%kurczak%" in sql


def test_recipe_search_treats_like_wildcards_as_plain_text() -> None:
    sql = _compiled_search("100%_fit")

    assert "100\\\\%%\\\\_fit" in sql
    assert "escape" in sql
