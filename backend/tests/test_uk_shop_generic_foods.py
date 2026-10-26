"""UK Shop reuses English system foods, never Polish retailer stock/prices."""
from urllib.parse import quote
from datetime import date
from sqlalchemy import event

from app.db.seed import NUTRITION_DATA, PRODUCTS_DATA, PRODUCT_BRANDS, _uid
from app.db.uk_store_catalog import UK_STORES
from app.models import Product
from tests.test_regional_store_catalogue import state, rows
from tests.test_uk_seed_off_identity import seeded_oats
from tests.uk_regional_fixtures import reviewed_offer, uk_store


def generic_rows(state, suffix=""):
    return rows(state, "?include_generic_foods=true" + suffix)


def test_shop_includes_english_system_food_without_inventing_a_shop_pack(state):
    oats = seeded_oats()
    state.db.add(oats)
    state.db.commit()
    value = next(row for row in generic_rows(state) if row["product_id"] == str(oats.id))
    assert value["catalogue_kind"] == "generic_food"
    assert value["name_en"] == value["product"]["name"] == "Oats"
    assert value["currency_code"] == "GBP"
    assert value["is_available"] is None
    assert value["availability_scope"] == "generic_food_reference"
    assert value["package_quantity"] is None and value["package_unit"] is None
    assert value["product"]["brand"] is None
    assert value["product"]["serving_quantity"] is None
    assert value["product"]["nutrition_per_100"]["kcal"] == 389
    assert value["price_basis"] == "national_quantity_reference"
    assert value["price_quantity"] == 100 and value["price_unit"] == "g"
    assert value["price_source"]["confirms_store_stock"] is False
    assert value["price_source"]["confirms_package"] is False
    assert not state.db.dirty
    assert oats.brand == "Sante" and oats.serving_quantity == 500
    # Old apps cannot parse generic references; the extension is opt-in.
    assert all(row["product_id"] != str(oats.id) for row in rows(state))


def test_all_390_foods_in_every_uk_shop_search_and_stable_pages(state):
    for name, unit, quantity, *_ in PRODUCTS_DATA:
        state.db.add(Product(id=_uid("product:" + name), name=name, unit=unit,
            default_quantity=quantity, brand=PRODUCT_BRANDS.get(name),
            nutrition_per_100=NUTRITION_DATA.get(name), review_status="approved"))
    state.db.commit()
    pages = [row for skip in (0, 200) for row in generic_rows(state, f"&skip={skip}&limit=200")]
    assert len(pages) == 391  # 390 canonical foods + the real reviewed SKU.
    assert len({row["id"] for row in pages}) == len(pages)
    generics = [row for row in pages if row["catalogue_kind"] == "generic_food"]
    assert len(generics) == 390
    assert [r["name_en"] for r in generics] == sorted(r["name_en"] for r in generics)
    assert any(r["price"] is None and r["price_basis"] == "unknown" for r in generics)
    for row in generics:
        assert row["price"] is None or row["price"] > 0
        assert row["package_quantity"] is None and row["is_available"] is None
    percent_rows = generic_rows(state, "&search=" + quote("%"))
    assert len(percent_rows) < 10
    assert all("%" in row["name_en"] for row in percent_rows)
    assert any(row["name_en"] == "Oats" for row in generic_rows(state, "&search=oats"))
    for definition in UK_STORES:
        store = uk_store(state.db, slug=definition.slug)
        state.db.commit()
        response = state.client.get(f"/stores/{store.id}/products?include_generic_foods=true&limit=200")
        assert response.status_code == 200
        assert len(response.json()) == 200
        assert all(row["store_id"] == str(store.id) for row in response.json())


def test_actual_reviewed_offer_replaces_generic_duplicate_and_keeps_pagination(state):
    oats = seeded_oats()
    state.db.add(oats)
    state.db.flush()
    offer = reviewed_offer(state.db, oats, state.gb, quantity="750", price="1.25")
    state.db.commit()
    values = generic_rows(state, "&search=oats")
    assert len(values) == 1 and values[0]["id"] == str(offer.id)
    assert values[0]["catalogue_kind"] == "retailer_offer"
    assert values[0]["package_quantity"] == 750


def test_authored_scanned_pending_and_renamed_seed_do_not_become_uk_generic_foods(state):
    oats = seeded_oats()
    state.db.add(oats)
    state.db.commit()
    for field, value in (("created_by_user_id", state.account.id),
                         ("barcode", "1234567890123"),
                         ("review_status", "pending"), ("name", "A user's product")):
        previous = getattr(oats, field)
        setattr(oats, field, value)
        state.db.flush()
        assert all(row["product_id"] != str(oats.id) for row in generic_rows(state))
        setattr(oats, field, previous)
    state.db.rollback()


def test_polish_shop_ignores_extension_and_preserves_price(state):
    state.account.country_code = "PL"
    response = state.client.get(f"/stores/{state.pl.id}/products?include_generic_foods=true")
    assert response.status_code == 200
    row, = response.json()
    assert row["price"] == 3.99 and row["currency_code"] == "PLN"
    assert row["is_available"] is True


def test_expired_reference_is_unknown_not_zero_or_a_request_failure(state, monkeypatch):
    monkeypatch.setattr("app.api.v1.stores.regional_pricing_date", lambda: date(2030, 1, 1))
    food = seeded_oats()
    state.db.add(food)
    state.db.commit()
    row, = generic_rows(state, "&search=oats")
    assert row["price"] is None and row["price_basis"] == "unknown"
    assert row["price_quantity"] is None and row["price_source"] is None
    assert row["product"]["nutrition_per_100"]["kcal"] == 389


def test_generic_catalogue_is_read_only_and_has_no_query_per_food(state):
    for name, unit, quantity, *_ in PRODUCTS_DATA:
        state.db.add(Product(id=_uid("product:" + name), name=name, unit=unit,
            default_quantity=quantity, review_status="approved"))
    state.db.commit()
    statements = []
    def record(conn, cursor, statement, parameters, context, executemany):
        statements.append(statement)
    engine = state.db.get_bind()
    event.listen(engine, "before_cursor_execute", record)
    try:
        assert len(generic_rows(state, "&limit=200")) == 200
    finally:
        event.remove(engine, "before_cursor_execute", record)
    assert len(statements) == 3  # store guard, reviewed offers, generic page
    assert all(sql.lstrip().upper().startswith("SELECT") for sql in statements)
    assert not state.db.new and not state.db.dirty and not state.db.deleted
