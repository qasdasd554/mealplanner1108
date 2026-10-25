"""Local OFF aliases save network calls without changing food identity/access."""

from datetime import datetime, timedelta, timezone
from unittest.mock import AsyncMock
from uuid import uuid4

import pytest
from sqlalchemy import event

from app.models import OffCatalogueProduct, Product
from app.services import barcode_lookup
from app.services.off_catalogue import import_off_catalogue
from app.services.recipe_ingredient_catalogue import resolve_recipe_ingredients
from tests.test_recipe_off_on_demand_parity import CODE, external
from tests.test_regional_shopping import db, run
from tests.test_uk_existing_gtin_recipe import existing


def seed_cache(session, adapter):
    result = external()
    run(import_off_catalogue(adapter, [result.off_product],
        retrieved_at=datetime.fromisoformat(result.off_retrieved_at)))
    session.commit()
    return session.get(OffCatalogueProduct, CODE)


@pytest.mark.parametrize("unsafe", [None, "pending", "rejected", "expired", "future", "foreign",
    "wrong_source", "wrong_fingerprint", "wrong_dimension", "not_in_catalogue", "different_name"])
def test_only_current_exact_public_alias_can_avoid_external_lookup(db, monkeypatch, unsafe):
    session, adapter, user, *_ = db
    original = existing(session, user)
    cached = seed_cache(session, adapter)
    if unsafe in {"pending", "rejected"}: original.review_status = unsafe
    if unsafe == "expired": cached.retrieved_at = datetime.now(timezone.utc) - timedelta(days=31)
    if unsafe == "future": cached.retrieved_at = datetime.now(timezone.utc) + timedelta(minutes=5)
    if unsafe == "foreign": cached.country_code = "PL"
    if unsafe == "wrong_source": cached.source_url = "https://example.invalid/product/" + CODE
    if unsafe == "wrong_fingerprint": cached.fingerprint = "X" * 64
    if unsafe == "wrong_dimension": cached.base_unit = "ml"
    if unsafe == "different_name": cached.name = "Cooked chicken breast"
    session.commit()
    search = AsyncMock(return_value=[])
    monkeypatch.setattr(barcode_lookup, "search_products_external", search)
    pairs = run(resolve_recipe_ingredients([dict(product_name="Filo pastry", quantity=100, unit="g")],
        [] if unsafe == "not_in_catalogue" else [original], country="GB", db=adapter))
    assert (pairs[0][1] is original) == (unsafe is None)
    assert search.await_count == (0 if unsafe is None else 1)
    assert original.name == "Ciasto filo" and original.serving_quantity == 200
    assert original.nutrition_per_100["kcal"] == 290
    assert not session.dirty and not session.new


def test_many_occurrences_use_one_local_query_and_no_network(db, monkeypatch):
    session, adapter, user, *_ = db
    original = existing(session, user)
    seed_cache(session, adapter)
    reads = []
    def count(_, __, statement, *args):
        if "FROM off_catalogue_products" in statement: reads.append(statement)
    engine = session.get_bind()
    event.listen(engine, "before_cursor_execute", count)
    search = AsyncMock(return_value=[])
    monkeypatch.setattr(barcode_lookup, "search_products_external", search)
    try:
        pairs = run(resolve_recipe_ingredients([dict(product_name="Filo pastry", quantity=100, unit="g")] * 30,
            [original], country="GB", db=adapter))
    finally:
        event.remove(engine, "before_cursor_execute", count)
    assert len(reads) == 1 and all(product is original for _, product in pairs)
    search.assert_not_awaited()


def test_ambiguous_equal_labels_do_not_choose_the_first_barcode(db, monkeypatch):
    session, adapter, user, *_ = db
    first = existing(session, user)
    seed_cache(session, adapter)
    second = Product(id=uuid4(), name="Inne ciasto filo", unit="g", barcode="5449000000996",
        review_status="approved", nutrition_per_100=dict(first.nutrition_per_100))
    session.add(second)
    result = external()
    raw = dict(result.off_product, code=second.barcode)
    run(import_off_catalogue(adapter, [raw],
        retrieved_at=datetime.fromisoformat(result.off_retrieved_at)))
    session.commit()
    search = AsyncMock(return_value=[])
    monkeypatch.setattr(barcode_lookup, "search_products_external", search)
    pairs = run(resolve_recipe_ingredients([dict(product_name="Filo pastry", quantity=100, unit="g")],
        [first, second], country="GB", db=adapter))
    assert pairs[0][1] is None
    search.assert_awaited_once()


def test_polish_resolver_does_not_read_the_new_uk_alias_cache(db, monkeypatch):
    session, adapter, user, *_ = db
    original = existing(session, user)
    seed_cache(session, adapter)
    unavailable_db = AsyncMock()
    unavailable_db.execute.side_effect = AssertionError("PL must not query UK facts")
    search = AsyncMock(return_value=[])
    monkeypatch.setattr(barcode_lookup, "search_products_external", search)
    pairs = run(resolve_recipe_ingredients([dict(product_name="Filo pastry", quantity=100, unit="g")],
        [original], country="PL", db=unavailable_db))
    assert pairs[0][1] is None
    unavailable_db.execute.assert_not_awaited()
    search.assert_awaited_once()


def test_english_cached_alias_does_not_charge_for_an_unchanged_ai_edit(db, monkeypatch):
    from fastapi import HTTPException
    from app.api.v1.recipes import edit_recipe_with_ai
    from app.models import Recipe, RecipeIngredient
    from app.schemas.recipe import AIRecipeEditRequest
    from app.services import ai_recipe_import

    session, adapter, user, *_ = db
    user.premium_points = 3
    product = existing(session, user)
    seed_cache(session, adapter)
    recipe = Recipe(id=uuid4(), name="Synthetic filo dish", meal_type="obiad", servings=1,
        difficulty="łatwy", visibility="private", created_by_user_id=user.id, instructions=["Prepare it."])
    session.add(recipe)
    session.flush()
    session.add(RecipeIngredient(id=uuid4(), recipe_id=recipe.id, product_id=product.id,
        quantity=100, unit="g", is_optional=False))
    session.commit()
    async def unchanged(snapshot, *args, **kwargs):
        return {**snapshot, "ingredients": [{"product_name": "Filo pastry", "quantity": 100, "unit": "g"}]}
    monkeypatch.setattr(ai_recipe_import, "revise_recipe_with_ai", AsyncMock(side_effect=unchanged))
    monkeypatch.setattr("app.core.rate_limit.enforce_user_rate_limit", lambda *args: None)
    search, spend = AsyncMock(return_value=[]), AsyncMock()
    monkeypatch.setattr(barcode_lookup, "search_products_external", search)
    monkeypatch.setattr("app.services.premium_points.spend_points", spend)
    async def rollback(): session.rollback()
    adapter.rollback = rollback
    with pytest.raises(HTTPException) as failure:
        run(edit_recipe_with_ai(recipe.id, AIRecipeEditRequest(prompt="Keep everything"), user, adapter))
    assert failure.value.status_code == 422 and failure.value.detail == "AI made no changes. No point was charged."
    search.assert_not_awaited()
    spend.assert_not_awaited()
