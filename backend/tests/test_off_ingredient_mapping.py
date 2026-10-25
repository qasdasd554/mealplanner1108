"""Reviewed UK evidence for generic ingredients, never SKU/nutrition substitution."""

import asyncio
from datetime import datetime, timedelta, timezone
from types import SimpleNamespace
from uuid import uuid4

import pytest
from sqlalchemy import delete, event, func, select, update
from sqlalchemy.dialects import postgresql
from sqlalchemy.schema import CreateTable

from app.models import Base, Product, Recipe, RecipeIngredient, RegionalProductOffer, StoreProduct, User
from app.models.off_catalogue_product import OffCatalogueProduct
from app.models.off_ingredient_mapping import OffIngredientMapping
from app.services.market_catalog import apply_recipe_market_filter, ensure_recipe_available_in_market
from app.services.off_availability import off_available_product_ids
from app.services.off_catalogue import catalogue_values
from app.services.off_ingredient_mapping import import_reviewed_off_mappings
from tests.test_uk_catalogue_import import AsyncAdapter, catalogue_db


NOW = datetime.now(timezone.utc)
CODE = "5025125000006"


def setup(session, product_id):
    source = catalogue_values({
        "code": CODE, "product_name_en": "Synthetic plain oats",
        "countries_tags": ["en:united-kingdom"], "last_modified_t": 1700000000,
        "product_quantity": 500, "product_quantity_unit": "g",
        "nutriments": {"energy-kcal_100g": 350, "proteins_100g": 10,
                       "fat_100g": 5, "carbohydrates_100g": 60},
    }, retrieved_at=NOW)
    session.add(OffCatalogueProduct(**source))
    recipe = Recipe(id=uuid4(), name="Synthetic oats recipe", meal_type="obiad")
    recipe.ingredients = [RecipeIngredient(id=uuid4(), product_id=product_id,
        quantity=100, unit="g", is_optional=False)]
    session.add(recipe)
    session.commit()
    return recipe


def proposal(session, product_id, **changes):
    product = session.get(Product, product_id)
    return dict(dict(product_id=product_id, product_name=product.name,
        product_unit=product.unit, off_barcode=CODE,
        off_fingerprint=session.get(OffCatalogueProduct, CODE).fingerprint,
        review_note="Synthetic reviewed plain oats identity; not a retailer offer."), **changes)


def imported(session, reviewer, rows, *, now=NOW):
    return asyncio.run(import_reviewed_off_mappings(AsyncAdapter(session), rows,
        reviewer_user_id=reviewer, reviewed_at=now, as_of=now.date()))


def visible(session, country="GB"):
    return set(session.scalars(apply_recipe_market_filter(
        select(Recipe.id), SimpleNamespace(country_code=country))))


def available(session, ids, *, day=None):
    return asyncio.run(off_available_product_ids(AsyncAdapter(session), ids,
        as_of=day or NOW.date()))


def test_review_binds_generic_ingredient_without_replacing_identity_or_product_data(catalogue_db):
    session, reviewer, product_id = catalogue_db
    recipe = setup(session, product_id)
    assert visible(session) == set()  # Same food name alone proves nothing.
    before = dict(session.get(Product, product_id).nutrition_per_100)
    result = imported(session, reviewer, [proposal(session, product_id)])
    assert (result.created, result.updated, result.unchanged) == (1, 0, 0)
    assert visible(session) == {recipe.id}
    assert available(session, [product_id]) == {product_id}
    asyncio.run(ensure_recipe_available_in_market(
        AsyncAdapter(session), recipe, SimpleNamespace(country_code="GB")))
    product = session.get(Product, product_id)
    assert product.barcode is None and product.serving_quantity == 200
    assert product.nutrition_per_100 == before
    assert session.scalar(select(func.count()).select_from(RegionalProductOffer)) == 0
    assert session.scalar(select(func.count()).select_from(StoreProduct)) == 1
    assert recipe.ingredients[0].product_id == product_id
    assert recipe.ingredients[0].quantity == 100


def test_pl_visibility_never_depends_on_mapping_or_off_cache(catalogue_db):
    session, reviewer, product_id = catalogue_db
    recipe = setup(session, product_id)
    assert visible(session, "PL") == {recipe.id}
    imported(session, reviewer, [proposal(session, product_id)])
    session.execute(delete(OffIngredientMapping))
    session.execute(delete(OffCatalogueProduct))
    session.commit()
    assert visible(session, "PL") == {recipe.id}


@pytest.mark.parametrize("changed", ["name", "unit", "brand", "barcode", "status", "owner",
    "off_fingerprint", "off_country", "off_source", "stale_off", "future_off", "future_review"])
def test_changed_or_stale_evidence_invalidates_mapping_in_both_query_paths(catalogue_db, changed):
    session, reviewer, product_id = catalogue_db
    setup(session, product_id)
    imported(session, reviewer, [proposal(session, product_id)])
    session.commit()
    product = session.get(Product, product_id)
    mapping = session.get(OffIngredientMapping, (product_id, CODE))
    off = session.get(OffCatalogueProduct, CODE)
    if changed == "name": product.name += " changed"
    elif changed == "unit": product.unit = "ml"
    elif changed == "brand": product.brand = "New branded identity"
    elif changed == "barcode": product.barcode = "5901234123457"
    elif changed == "status": product.review_status = "rejected"
    elif changed == "owner": product.created_by_user_id = reviewer
    elif changed == "off_fingerprint": off.fingerprint = "a" * 64
    elif changed == "off_country": off.country_code = "PL"
    elif changed == "off_source": off.source_url = "https://example.invalid/food"
    elif changed == "stale_off": off.retrieved_at = NOW - timedelta(days=31)
    elif changed == "future_off": off.retrieved_at = NOW + timedelta(days=2)
    else: mapping.reviewed_at = NOW + timedelta(days=2)
    session.commit()
    assert visible(session) == set()
    assert available(session, [product_id]) == set()


@pytest.mark.parametrize("kind", ["missing", "regular", "banned", "revoked"])
def test_only_current_database_admin_can_review(catalogue_db, kind):
    session, reviewer, product_id = catalogue_db
    setup(session, product_id)
    rows = [proposal(session, product_id)]
    cached = session.get(User, reviewer)
    if kind == "missing": reviewer = uuid4()
    elif kind == "regular": cached.role = "user"
    elif kind == "banned": cached.is_banned = True
    else:
        session.execute(update(User).where(User.id == reviewer).values(role="user")
            .execution_options(synchronize_session=False))
    session.flush()
    with pytest.raises(PermissionError):
        imported(session, reviewer, rows)
    assert session.scalar(select(func.count()).select_from(OffIngredientMapping)) == 0


@pytest.mark.parametrize("bad", ["missing_product", "pending", "authored", "branded", "gtin",
    "name", "unit", "fingerprint", "dimension", "stale", "future", "country", "note"])
def test_invalid_batch_never_stages_a_partial_first_mapping(catalogue_db, bad):
    session, reviewer, product_id = catalogue_db
    setup(session, product_id)
    first = proposal(session, product_id)
    second = dict(first, product_id=uuid4())
    product = Product(id=second["product_id"], name=first["product_name"], unit="g",
        review_status="approved")
    session.add(product)
    session.commit()
    if bad == "missing_product": second["product_id"] = uuid4()
    elif bad == "pending": product.review_status = "pending"
    elif bad == "authored": product.created_by_user_id = reviewer
    elif bad == "branded": product.brand = "Branded product"
    elif bad == "gtin": product.barcode = CODE
    elif bad == "name": second["product_name"] = "Wrong snapshot"
    elif bad == "unit": second["product_unit"] = "ml"
    elif bad == "fingerprint": second["off_fingerprint"] = "0" * 64
    elif bad == "dimension": session.get(OffCatalogueProduct, CODE).base_unit = "ml"
    elif bad == "stale": session.get(OffCatalogueProduct, CODE).retrieved_at = NOW - timedelta(days=31)
    elif bad == "future": session.get(OffCatalogueProduct, CODE).retrieved_at = NOW + timedelta(days=2)
    elif bad == "country": session.get(OffCatalogueProduct, CODE).country_code = "PL"
    else: second["review_note"] = ""
    session.commit()
    with pytest.raises(ValueError):
        imported(session, reviewer, [first, second])
    assert session.scalar(select(func.count()).select_from(OffIngredientMapping)) == 0


def test_import_is_idempotent_and_outer_transaction_can_roll_back(catalogue_db):
    session, reviewer, product_id = catalogue_db
    setup(session, product_id)
    rows = [proposal(session, product_id)]
    imported(session, reviewer, rows)
    second = imported(session, reviewer, rows)
    assert (second.created, second.updated, second.unchanged) == (0, 0, 1)
    session.rollback()
    assert session.scalar(select(func.count()).select_from(OffIngredientMapping)) == 0


def test_explicit_new_review_can_bind_changed_off_revision_but_old_one_cannot_overwrite(catalogue_db):
    session, reviewer, product_id = catalogue_db
    setup(session, product_id)
    rows = [proposal(session, product_id)]
    imported(session, reviewer, rows)
    session.commit()
    session.get(OffCatalogueProduct, CODE).fingerprint = "a" * 64
    session.commit()
    assert available(session, [product_id]) == set()
    revised = [proposal(session, product_id)]
    assert imported(session, reviewer, revised, now=NOW + timedelta(hours=1)).updated == 1
    session.commit()
    assert available(session, [product_id]) == {product_id}
    with pytest.raises(ValueError, match="older review"):
        imported(session, reviewer, revised)


def test_batched_availability_uses_one_local_select_and_empty_input_does_not_query(catalogue_db):
    session, reviewer, product_id = catalogue_db
    setup(session, product_id)
    imported(session, reviewer, [proposal(session, product_id)])
    session.commit()
    queries = []
    def count(connection, cursor, statement, *args): queries.append(statement)
    event.listen(session.bind, "before_cursor_execute", count)
    try:
        assert available(session, []) == set() and queries == []
        assert available(session, [product_id, uuid4(), product_id]) == {product_id}
        assert len([query for query in queries if query.lstrip().upper().startswith("SELECT")]) == 1
        assert all(query == "BEGIN" or query.lstrip().upper().startswith("SELECT") for query in queries)
    finally:
        event.remove(session.bind, "before_cursor_execute", count)


def test_schema_is_additive_and_does_not_store_prices_nutrition_or_users(catalogue_db):
    session, _, _ = catalogue_db
    table = OffIngredientMapping.__table__
    ddl = str(CreateTable(table).compile(dialect=postgresql.dialect()))
    assert "CREATE TABLE off_ingredient_mappings" in ddl
    assert "ON DELETE CASCADE" in ddl and "ON DELETE SET NULL" in ddl
    assert "TIMESTAMP WITH TIME ZONE" in ddl
    assert not {"price", "nutrition_per_100", "package_quantity", "email"}.intersection(table.columns.keys())
    table.create(session.connection(), checkfirst=True)
    assert "ALTER TABLE products" not in ddl and "DROP " not in ddl


def test_unchanged_identity_does_not_need_monthly_review_when_off_facts_are_refreshed(catalogue_db):
    session, reviewer, product_id = catalogue_db
    recipe = setup(session, product_id)
    imported(session, reviewer, [proposal(session, product_id)])
    # Old identity review + a current fetch of the SAME OFF revision is valid.
    session.get(OffIngredientMapping, (product_id, CODE)).reviewed_at = NOW - timedelta(days=90)
    session.commit()
    assert visible(session) == {recipe.id}
    assert available(session, [product_id]) == {product_id}


def test_count_measure_keeps_its_explicit_conversion_and_never_copies_off_package(catalogue_db):
    session, reviewer, product_id = catalogue_db
    recipe = setup(session, product_id)
    product = session.get(Product, product_id)
    product.unit = "szt"
    product.measure_options = [{"code": "szt", "base_unit": "g", "base_quantity": 50}]
    recipe.ingredients[0].quantity, recipe.ingredients[0].unit = 2, "szt"
    session.commit()
    imported(session, reviewer, [proposal(session, product_id)])
    asyncio.run(ensure_recipe_available_in_market(
        AsyncAdapter(session), recipe, SimpleNamespace(country_code="GB")))
    assert product.measure_options[0]["base_quantity"] == 50
    assert product.serving_quantity == 200  # OFF's 500 g pack must not replace it.
    assert recipe.ingredients[0].quantity == 2 and recipe.ingredients[0].unit == "szt"


def test_unknown_count_dimension_is_not_assumed_to_mean_one_gram(catalogue_db):
    session, reviewer, product_id = catalogue_db
    setup(session, product_id)
    product = session.get(Product, product_id)
    product.unit, product.measure_options = "szt", None
    session.commit()
    with pytest.raises(ValueError, match="g/ml dimension"):
        imported(session, reviewer, [proposal(session, product_id)])
    assert available(session, [product_id]) == set()


def test_multiple_reviewed_off_examples_do_not_duplicate_canonical_product(catalogue_db):
    session, reviewer, product_id = catalogue_db
    recipe = setup(session, product_id)
    values = catalogue_values({"code": "5901234123457", "product_name_en": "Another plain oats example",
        "countries_tags": ["en:united-kingdom"], "product_quantity": 1000,
        "product_quantity_unit": "g", "last_modified_t": 1700000001}, retrieved_at=NOW)
    session.add(OffCatalogueProduct(**values))
    session.commit()
    row = proposal(session, product_id, off_barcode=values["barcode"], off_fingerprint=values["fingerprint"])
    imported(session, reviewer, [proposal(session, product_id), row])
    assert visible(session) == {recipe.id} and available(session, [product_id]) == {product_id}
    session.get(OffCatalogueProduct, CODE).retrieved_at = NOW - timedelta(days=31)
    session.commit()
    assert visible(session) == {recipe.id} and available(session, [product_id]) == {product_id}


def test_unmapped_required_ingredient_still_excludes_recipe_before_pagination(catalogue_db):
    session, reviewer, product_id = catalogue_db
    mapped = setup(session, product_id)
    imported(session, reviewer, [proposal(session, product_id)])
    unknown = Product(id=uuid4(), name="Unmapped ingredient", unit="g")
    hidden = Recipe(id=uuid4(), name="A hidden recipe", meal_type="obiad")
    hidden.ingredients = [RecipeIngredient(id=uuid4(), product=unknown,
        quantity=100, unit="g", is_optional=False)]
    session.add(hidden)
    session.commit()
    query = apply_recipe_market_filter(select(Recipe.id).order_by(Recipe.name).limit(1),
        SimpleNamespace(country_code="GB"))
    assert list(session.scalars(query)) == [mapped.id]
    mapped.ingredients.append(RecipeIngredient(id=uuid4(), product=unknown,
        quantity=5, unit="g", is_optional=False))
    session.commit()
    assert visible(session) == set()
    mapped.ingredients[-1].is_optional = True
    session.commit()
    assert visible(session) == {mapped.id}


@pytest.mark.parametrize("change", ["country", "barcode", "fingerprint", "field", "note"])
def test_malformed_proposal_is_rejected_before_any_writes(catalogue_db, change):
    session, reviewer, product_id = catalogue_db
    setup(session, product_id)
    row = proposal(session, product_id)
    if change == "country": row["country_code"] = "PL"
    elif change == "barcode": row["off_barcode"] = "5025125000007"
    elif change == "fingerprint": row["off_fingerprint"] = "z" * 64
    elif change == "field": row["price"] = 0.99
    else: row["review_note"] = "   "
    with pytest.raises(ValueError): imported(session, reviewer, [row])
    assert session.scalar(select(func.count()).select_from(OffIngredientMapping)) == 0


def test_batch_is_bounded_and_requires_no_pending_unrelated_changes(catalogue_db):
    session, reviewer, product_id = catalogue_db
    setup(session, product_id)
    row = proposal(session, product_id)
    with pytest.raises(ValueError, match="500"):
        imported(session, reviewer, (row for _ in range(501)))
    with pytest.raises(ValueError, match="Duplicate"):
        imported(session, reviewer, [row, row])
    product = session.get(Product, product_id)
    product.name = "Pending unrelated edit"
    with pytest.raises(ValueError, match="clean session"):
        imported(session, reviewer, [row])
    assert product in session.dirty
    session.rollback()
    assert session.scalar(select(func.count()).select_from(OffIngredientMapping)) == 0


def test_failure_after_sql_insert_rolls_back_only_import_savepoint(catalogue_db):
    session, reviewer, product_id = catalogue_db
    setup(session, product_id)
    session.get(Product, product_id).nutrition_per_100 = {"kcal": 371}
    session.flush()
    row = proposal(session, product_id)
    inserted = []
    def fail(connection, cursor, statement, *args):
        if statement.lower().startswith("insert into off_ingredient_mappings"):
            inserted.append(True)
            raise RuntimeError("Synthetic failure after SQL")
    event.listen(session.bind, "after_cursor_execute", fail)
    try:
        with pytest.raises(RuntimeError, match="after SQL"):
            imported(session, reviewer, [row])
    finally:
        event.remove(session.bind, "after_cursor_execute", fail)
    assert inserted
    assert session.scalar(select(func.count()).select_from(OffIngredientMapping)) == 0
    assert session.get(Product, product_id).nutrition_per_100 == {"kcal": 371}
    session.commit()


@pytest.mark.parametrize("deleted", ["canonical", "off", "reviewer"])
def test_deletion_does_not_leave_an_orphan_or_block_user_deletion(catalogue_db, deleted):
    session, reviewer, product_id = catalogue_db
    recipe = setup(session, product_id)
    imported(session, reviewer, [proposal(session, product_id)])
    session.commit()
    if deleted == "canonical":
        session.delete(recipe)
        session.flush()
        session.execute(delete(Product).where(Product.id == product_id))
    elif deleted == "off":
        session.execute(delete(OffCatalogueProduct).where(OffCatalogueProduct.barcode == CODE))
    else:
        session.execute(delete(User).where(User.id == reviewer))
    session.commit()
    session.expire_all()
    mapping = session.get(OffIngredientMapping, (product_id, CODE))
    if deleted == "reviewer":
        assert mapping is not None and mapping.reviewed_by_user_id is None
    else:
        assert mapping is None
        assert available(session, [product_id]) == set()


def test_mapping_table_can_be_added_twice_without_changing_existing_rows(catalogue_db):
    from sqlalchemy import create_engine
    from sqlalchemy.orm import Session
    engine = create_engine("sqlite://")
    product_id = uuid4()
    try:
        Base.metadata.create_all(engine, tables=[table for table in Base.metadata.sorted_tables
            if table.name != "off_ingredient_mappings"])
        with Session(engine) as session:
            session.add(Product(id=product_id, name="Existing canonical ingredient", unit="g"))
            session.commit()
        OffIngredientMapping.__table__.create(engine, checkfirst=True)
        OffIngredientMapping.__table__.create(engine, checkfirst=True)
        with Session(engine) as session:
            assert session.get(Product, product_id).name == "Existing canonical ingredient"
            assert session.scalar(select(func.count()).select_from(OffIngredientMapping)) == 0
    finally:
        engine.dispose()
