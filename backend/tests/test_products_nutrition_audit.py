"""Regressions for the 2026-10-14 products/nutrition audit (no live services)."""

import asyncio
import json
import uuid
from datetime import date
from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock

import pytest
from fastapi import HTTPException
from pydantic import ValidationError
from sqlalchemy.dialects import postgresql

from app.api.v1.food_log import create_food_log_entry, read_food_log_entries, get_recent_food_log_entries
from app.api.v1.pantry import AddPantryItemsRequest, UpdatePantryItemQuantityRequest, AddPantryBarcodeRequest, add_pantry_items
from app.api.v1.products import ProductSubmission, update_own_product
from app.api.v1.products import BarcodeLookupResponse, RecipeIngredientProductCreate, resolve_recipe_ingredient_product, lookup_barcode
from app.api.v1.pantry import add_pantry_item_from_barcode
from app.schemas.food_log import FoodLogEntryCreate
from app.core.exceptions import NotFoundException
from app.services.barcode_lookup import _number, _result_from_off_product, barcode_variants, BarcodeLookupResult, has_complete_nutrition, merge_lookup_results
from app.services.product_label_ai import _parse_label_json
from app.services.nutrition_calculator import grams_to_quantity, quantity_to_grams, NutritionCalculator, compute_recipe_nutrition_total
from app.services.pantry_shopping_sync import split_required_quantity
from decimal import Decimal


def sql_text(statement):
    return str(statement.compile(dialect=postgresql.dialect(), compile_kwargs={"literal_binds": True})).lower()


@pytest.mark.parametrize("schema,extra", [
    (AddPantryItemsRequest, {"product_ids": [uuid.uuid4()]}),
    (UpdatePantryItemQuantityRequest, {}),
    (AddPantryBarcodeRequest, {"barcode": "5901234123457", "unit": "g"}),
])
@pytest.mark.parametrize("quantity", [-1, 0, float("nan"), float("inf")])
def test_pantry_rejects_invalid_quantity(schema, extra, quantity):
    with pytest.raises(ValidationError):
        schema(quantity=quantity, **extra)


@pytest.mark.parametrize("value", ["nan", "Infinity", -12, True])
def test_external_nutrients_reject_nonfinite_negative_or_boolean(value):
    assert _number({"kcal": value}, "kcal") is None


def test_off_does_not_mislabel_nutrients_per_serving_as_per_100():
    result = _result_from_off_product({
        "product_name": "Batony", "nutrition_data_per": "serving",
        "nutriments": {"energy-kcal": 120, "proteins": 2, "fat": 4, "carbohydrates": 15},
    })
    assert result.kcal_per_100 is None
    assert result.protein_per_100 is None


def test_ocr_zero_package_weight_stays_unknown():
    result = _parse_label_json(json.dumps({"name": "Woda", "serving_quantity": 0}), "5901234123457")
    assert result["serving_quantity"] is None


def test_gtin_variants_preserve_upc_leading_zero():
    assert "036000291452" in barcode_variants("00036000291452")
    assert "0036000291452" in barcode_variants("00036000291452")


def test_product_names_are_validated_after_trimming():
    with pytest.raises(ValidationError):
        ProductSubmission(name="  ")


def test_update_product_preserves_unknown_macros_and_rebuilds_package(monkeypatch):
    user = SimpleNamespace(id=uuid.uuid4())
    product = SimpleNamespace(
        created_by_user_id=user.id, review_status="pending", barcode=None,
        serving_quantity=None, unit="g", default_quantity=100, measure_options=[],
    )
    db = SimpleNamespace(get=AsyncMock(return_value=product), add=MagicMock(), commit=AsyncMock(), refresh=AsyncMock())
    asyncio.run(update_own_product(
        uuid.uuid4(), ProductSubmission(name="Jogurt", protein_per_100=5, barcode=" ]E05901234123457 ", serving_quantity=400, serving_unit="g"), db, user,
    ))
    assert product.barcode == "5901234123457"
    assert product.nutrition_per_100["kcal"] is None
    assert product.nutrition_per_100["protein"] == 5
    assert product.serving_quantity == 400
    assert product.unit == "opak"
    assert next(m for m in product.measure_options if m["code"] == "opak")["base_quantity"] == 400


def test_pantry_uuid_addition_applies_product_visibility(monkeypatch):
    result = MagicMock()
    result.scalars.return_value.all.return_value = []
    db = SimpleNamespace(execute=AsyncMock(return_value=result), flush=AsyncMock(), commit=AsyncMock())
    asyncio.run(add_pantry_items(AddPantryItemsRequest(product_ids=[uuid.uuid4()]), SimpleNamespace(id=uuid.uuid4()), db))
    sql = sql_text(db.execute.await_args_list[0].args[0])
    assert "products.review_status" in sql
    assert "products.created_by_user_id" in sql


@pytest.mark.parametrize("endpoint,args", [(read_food_log_entries, {"entry_date": None}), (get_recent_food_log_entries, {"limit": 8})])
def test_undated_food_history_still_applies_free_history_bound(endpoint, args):
    result = MagicMock()
    result.scalars.return_value.all.return_value = []
    db = SimpleNamespace(execute=AsyncMock(return_value=result))
    user = SimpleNamespace(id=uuid.uuid4(), role="user", is_premium=False)
    asyncio.run(endpoint(db=db, current_user=user, **args))
    assert "food_log_entries.date >=" in sql_text(db.execute.await_args.args[0])


def test_food_log_private_recipe_does_not_disclose_macros():
    user = SimpleNamespace(id=uuid.uuid4(), role="user")
    recipe = SimpleNamespace(id=uuid.uuid4(), created_by_user_id=uuid.uuid4(), visibility="private", servings=2, nutrition_total={"kcal": 600})
    empty = MagicMock()
    empty.scalar_one_or_none.return_value = None
    db = SimpleNamespace(get=AsyncMock(return_value=recipe), execute=AsyncMock(return_value=empty))
    with pytest.raises(NotFoundException) as exc:
        asyncio.run(create_food_log_entry(FoodLogEntryCreate(date=date.today(), meal_type="obiad", recipe_id=recipe.id), db, user))
    assert exc.value.status_code == 404


def test_barcode_pantry_cannot_mutate_someone_elses_pending_product(monkeypatch):
    user = SimpleNamespace(id=uuid.uuid4())
    product = SimpleNamespace(id=uuid.uuid4(), created_by_user_id=uuid.uuid4(), review_status="pending")
    monkeypatch.setattr("app.api.v1.products.lookup_barcode", AsyncMock(return_value=BarcodeLookupResponse(found=False)))
    result = MagicMock()
    result.scalar_one_or_none.return_value = product
    db = SimpleNamespace(execute=AsyncMock(return_value=result))
    payload = AddPantryBarcodeRequest(barcode="5901234123457", quantity=1, unit="opak", name="Jogurt", serving_quantity=400, kcal_per_100=60, protein_per_100=4, fat_per_100=2, carbs_per_100=6)
    with pytest.raises(NotFoundException):
        asyncio.run(add_pantry_item_from_barcode(payload, user, db))


def test_untrusted_recipe_payload_cannot_fill_shared_product(monkeypatch):
    user = SimpleNamespace(id=uuid.uuid4())
    product = SimpleNamespace(name="Jogurt", brand=None, created_by_user_id=None, nutrition_per_100=None, serving_quantity=None, barcode=None, measure_options=[{}])
    payload = RecipeIngredientProductCreate(name="Jogurt", existing_product_id=uuid.uuid4(), kcal_per_100=900, protein_per_100=1, fat_per_100=99, carbs_per_100=0, serving_quantity=50000)
    monkeypatch.setattr("app.api.v1.products.find_nutrition_by_name", AsyncMock(return_value=None))
    result = MagicMock()
    result.scalar_one_or_none.return_value = product
    db = SimpleNamespace(execute=AsyncMock(return_value=result), commit=AsyncMock(), refresh=AsyncMock())
    with pytest.raises(HTTPException) as exc:
        asyncio.run(resolve_recipe_ingredient_product(payload, db, user))
    assert exc.value.status_code == 422
    assert product.nutrition_per_100 is None
    assert product.serving_quantity is None
    db.commit.assert_not_awaited()


def test_explicit_external_zero_macros_are_complete_and_not_replaced():
    water = BarcodeLookupResult(name="Woda", brand=None, unit="ml", kcal_per_100=0, protein_per_100=0, fat_per_100=0, carbs_per_100=0, price_min=1, price_max=5, source="open_food_facts")
    alternative = BarcodeLookupResult(name="Napój", brand=None, unit="ml", kcal_per_100=40, protein_per_100=0, fat_per_100=0, carbs_per_100=10, price_min=1, price_max=5, source="usda_fooddata_central")
    assert has_complete_nutrition(water)
    assert merge_lookup_results(water, alternative).kcal_per_100 == 0


def test_local_name_enrichment_never_inherits_another_package(monkeypatch):
    from fastapi import BackgroundTasks
    product = SimpleNamespace(id=uuid.uuid4(), name="Jogurt", brand="Marka", unit="g", serving_quantity=None, nutrition_per_100=None)
    result = MagicMock()
    result.scalar_one_or_none.return_value = product
    supplement = BarcodeLookupResult(name="Jogurt", brand="Marka", unit="g", kcal_per_100=60, protein_per_100=4, fat_per_100=2, carbs_per_100=6, price_min=2, price_max=8, source="open_food_facts", serving_quantity=150, barcode="036000291452")
    monkeypatch.setattr("app.api.v1.products.lookup_barcode_external", AsyncMock(return_value=None))
    monkeypatch.setattr("app.api.v1.products.find_nutrition_by_name", AsyncMock(return_value=supplement))
    db = SimpleNamespace(execute=AsyncMock(return_value=result), commit=AsyncMock())
    response = asyncio.run(lookup_barcode("5901234123457", BackgroundTasks(), db, SimpleNamespace(id=uuid.uuid4())))
    assert response.serving_quantity is None


def test_package_piece_count_is_not_a_physical_weight():
    result = _result_from_off_product({"product_name": "Jajka", "product_quantity": 6, "product_quantity_unit": "pieces"})
    assert result.serving_quantity is None


def test_custom_piece_conversion_is_invertible_and_pantry_remains_idempotent():
    options = [{"code": "szt", "base_quantity": 40, "base_unit": "g"}]
    product = SimpleNamespace(name="Tortilla", unit="szt", measure_options=options)
    rows = [SimpleNamespace(required_quantity=Decimal("2"), unit="szt")]
    pantry = SimpleNamespace(quantity=Decimal("1"), unit="szt")
    assert split_required_quantity(product, rows, pantry) == (Decimal("1"), Decimal("1"))


def test_generator_nutrition_matches_persisted_recipe_total():
    product = SimpleNamespace(name="Olej rzepakowy", nutrition_per_100={"kcal": 884, "fat": 100})
    ingredient = SimpleNamespace(product=product, quantity=500, unit="ml")
    assert NutritionCalculator.calculate_recipe_nutrition([ingredient]) == compute_recipe_nutrition_total([ingredient])


@pytest.mark.parametrize("without_returning", [False, True], ids=["default", "without_returning"])
def test_submission_reward_refreshes_locked_user_before_increment(monkeypatch, without_returning):
    """An already-loaded auth User can be stale even after SELECT FOR UPDATE."""
    from sqlalchemy import create_engine, event
    from sqlalchemy.orm import Session
    from app.models import Base, User
    from app.api.v1.products import submit_product

    engine = create_engine("sqlite:///:memory:")
    if without_returning:
        engine.dialect.insert_returning = False

    @event.listens_for(engine, "connect")
    def configure(connection, _record):
        connection.create_function("gen_random_uuid", 0, lambda: uuid.uuid4().hex)

    Base.metadata.create_all(engine)
    monkeypatch.setattr("app.core.rate_limit.enforce_user_rate_limit", lambda *_args: None)
    monkeypatch.setattr("app.services.admin_notifications.notify_admins_pending_review", AsyncMock())

    class Database:
        def __init__(self, session):
            self.session = session

        async def scalar(self, query):
            return self.session.scalar(query)

        def add(self, item):
            self.session.add(item)

        async def flush(self):
            self.session.flush()

        async def commit(self):
            self.session.commit()

        async def rollback(self):
            self.session.rollback()

        async def refresh(self, item):
            self.session.refresh(item)

    with Session(engine, expire_on_commit=False) as session:
        if not engine.dialect.insert_returning:
            # Older SQLite cannot return PostgreSQL server-generated UUIDs.
            # Supply IDs only in this local test session, never in app models.
            @event.listens_for(session, "before_flush")
            def supply_test_uuid(test_session, _flush_context, _instances):
                for row in test_session.new:
                    column = type(row).__table__.c.get("id")
                    if column is not None and isinstance(column.type, postgresql.UUID) and row.id is None:
                        row.id = uuid.uuid4()

        user = User(id=uuid.uuid4(), email="counter@example.test", password_hash="test", premium_points=4)
        session.add(user)
        session.commit()
        with engine.begin() as other_transaction:
            other_transaction.execute(User.__table__.update().where(User.id == user.id).values(premium_points=6))
        assert user.premium_points == 4  # Cached identity from authentication.
        response = asyncio.run(submit_product(ProductSubmission(name="Nowy jogurt"), Database(session), user))
        assert response.premium_points == 7
    engine.dispose()


def test_automatic_name_enrichment_rejects_another_flavour_or_light_variant(monkeypatch):
    from app.services.barcode_lookup import find_nutrition_by_name
    alternative = BarcodeLookupResult(name="Jogurt naturalny light", brand="Marka", unit="g", kcal_per_100=30, protein_per_100=3, fat_per_100=0, carbs_per_100=5, price_min=2, price_max=8, source="open_food_facts")
    monkeypatch.setattr("app.services.barcode_lookup.search_products_external", AsyncMock(return_value=[alternative]))
    assert asyncio.run(find_nutrition_by_name("Jogurt naturalny", "Marka")) is None


def test_automatic_name_enrichment_rejects_another_brand(monkeypatch):
    from app.services.barcode_lookup import find_nutrition_by_name
    alternative = BarcodeLookupResult(name="Jogurt naturalny", brand="Marka Inna", unit="g", kcal_per_100=30, protein_per_100=3, fat_per_100=0, carbs_per_100=5, price_min=2, price_max=8, source="open_food_facts")
    monkeypatch.setattr("app.services.barcode_lookup.search_products_external", AsyncMock(return_value=[alternative]))
    assert asyncio.run(find_nutrition_by_name("Jogurt naturalny", "Marka")) is None


def test_automatic_barcode_enrichment_requires_same_gtin(monkeypatch):
    from app.services.barcode_lookup import find_nutrition_by_name
    other = BarcodeLookupResult(name="Jogurt", brand="Marka", unit="g", kcal_per_100=30, protein_per_100=3, fat_per_100=0, carbs_per_100=5, price_min=2, price_max=8, source="open_food_facts", barcode="036000291452")
    exact = BarcodeLookupResult(name="Jogurt", brand="Marka", unit="g", kcal_per_100=60, protein_per_100=4, fat_per_100=2, carbs_per_100=6, price_min=2, price_max=8, source="open_food_facts", barcode="5901234123457")
    search = AsyncMock(return_value=[other])
    monkeypatch.setattr("app.services.barcode_lookup.search_products_external", search)
    assert asyncio.run(find_nutrition_by_name("Jogurt", "Marka", barcode="5901234123457")) is None
    search.return_value = [other, exact]
    assert asyncio.run(find_nutrition_by_name("Jogurt", "Marka", barcode="5901234123457")) is exact


def test_usda_nonfinite_nutrient_remains_unknown():
    from app.services.barcode_lookup import _product_from_usda_response
    result = _product_from_usda_response({"foods": [{"gtinUpc": "036000291452", "description": "Jogurt", "foodNutrients": [{"nutrientId": 1008, "value": "NaN"}]}]}, "036000291452")
    assert result.kcal_per_100 is None


def test_name_suggestions_do_not_mix_two_barcodes_or_package_sizes(monkeypatch):
    from app.api.v1.products import search_products_by_name
    product = SimpleNamespace(id=uuid.uuid4(), name="Jogurt", brand="Marka", unit="g", barcode="5901234123457", serving_quantity=None, nutrition_per_100=None)
    catalog, cache = MagicMock(), MagicMock()
    catalog.scalars.return_value.all.return_value = [product]
    cache.scalars.return_value.all.return_value = []
    db = SimpleNamespace(execute=AsyncMock(side_effect=[catalog, cache]))
    other = BarcodeLookupResult(name="Jogurt", brand="Marka", unit="g", barcode="036000291452", serving_quantity=150, kcal_per_100=30, protein_per_100=3, fat_per_100=0, carbs_per_100=5, price_min=2, price_max=8, source="open_food_facts")
    monkeypatch.setattr("app.services.barcode_lookup.search_products_external", AsyncMock(return_value=[other]))
    suggestions = asyncio.run(search_products_by_name("Jogurt", 10, db, SimpleNamespace(id=uuid.uuid4())))
    original = next(value for value in suggestions if value.existing_product_id == product.id)
    assert original.serving_quantity is None
    assert original.kcal_per_100 is None
