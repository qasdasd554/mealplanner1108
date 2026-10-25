"""A community price remains an estimate throughout the existing UK pipeline."""

import asyncio
from copy import deepcopy
from datetime import datetime, timezone
from decimal import Decimal
from uuid import uuid4

import pytest
from pydantic import ValidationError
from sqlalchemy import select

from app.db.uk_product_catalog import UKProductProposal
from app.models import OffCatalogueProduct, PantryItem, Product, RegionalProductOffer, Store, User
from app.db.uk_store_catalog import UK_STORES
from app.services import open_prices_reference as references
from app.services.regional_offer_pricing import reviewed_uk_offer, select_uk_offer_quote
from app.services.uk_catalogue_import import import_reviewed_uk_catalogue
from tests.test_open_prices_reference import example, prepare
from tests.test_uk_reviewed_staples import EVIDENCE, RETRIEVED
from tests.test_uk_catalogue_import import AsyncAdapter, catalogue_db
from tests.test_regional_shopping import AsyncDB, loaded, make_plan
from tests.sqlite_uuid_compat import supply_sqlite_uuid_defaults


def proposal():
    reference = prepare(*example(1))  # Real passata: 500g, observed £0.45 in Lidl.
    return references.community_price_proposal(reference,
        package_basis_note="Reviewed homogeneous passata: ingredient and source package both use mass as sold.")


def cache_review(session, reviewer, now):
    from app.services.off_catalogue import import_off_catalogue
    from app.services.off_ingredient_mapping import import_reviewed_off_mappings
    raw = next(value["product"] for value in EVIDENCE["products"] if value["barcode_requested"] == "20522605")
    link = next(value for value in EVIDENCE["proposals"] if value["off_barcode"] == "20522605")
    asyncio.run(import_off_catalogue(AsyncAdapter(session), [raw], retrieved_at=RETRIEVED))
    session.commit()
    asyncio.run(import_reviewed_off_mappings(AsyncAdapter(session), [link], reviewer_user_id=reviewer,
        reviewed_at=now, as_of=now.date()))
    session.commit()


def test_reference_becomes_an_explicitly_reviewed_estimate_not_online_stock():
    row = proposal()
    assert row.availability_scope == "store_observation"
    assert row.availability_status == "reported_available"
    assert row.price.kind == "estimate"
    assert row.price.source.provider == "open_prices"
    assert row.price.source.observation_id == 336462
    assert row.price.source.checked_on.isoformat() == "2026-09-27"
    assert row.price.source.package_basis == "as_sold"
    assert row.package.source.url == "https://world.openfoodfacts.org/product/20522605"
    assert row.retailer_sku == "off-20522605"  # External GTIN key, not invented merchant SKU.
    assert row.package.quantity == 500


@pytest.mark.parametrize("path,value", [
    ("availability_scope", "online_catalogue"), ("availability_status", "available_online"),
    ("retailer_slug", "tesco"), ("retailer_sku", "merchant-sku-without-proof"),
    ("price.source.url", "https://prices.openfoodfacts.org.evil.test/prices/336462"),
    ("price.source.observation_id", 1), ("price.source.product_code", "20071974"),
    ("price.source.proof_id", True), ("price.source.package_basis", "drained_unknown"),
    ("price.source.package_basis_note", ""), ("package.source.url", "https://world.openfoodfacts.org/product/20071974"),
])
def test_proposal_rejects_source_market_identity_or_package_basis_corruption(path, value):
    row = proposal().model_dump(mode="json")
    target = row
    parts = path.split(".")
    for part in parts[:-1]: target = target[part]
    target[parts[-1]] = value
    with pytest.raises(ValidationError):
        UKProductProposal.model_validate(row)


def test_current_review_is_not_a_new_price_observation(catalogue_db):
    session, reviewer, _ = catalogue_db
    row = proposal()
    definition = next(store for store in UK_STORES if store.id == row.store_id)
    session.add(Store(id=definition.id, name=definition.name, country_code="GB", currency_code="GBP"))
    canonical = example(1)[3]
    session.add(canonical)
    session.commit()
    now = datetime(2026, 10, 23, 18, tzinfo=timezone.utc)
    cache_review(session, reviewer, now)
    result = asyncio.run(import_reviewed_uk_catalogue(AsyncAdapter(session), [row],
        reviewer_user_id=reviewer, reviewed_at=now, as_of=now.date()))
    assert result.created == 1
    session.commit()
    stored = session.scalar(select(RegionalProductOffer).where(RegionalProductOffer.id == row.proposal_id))
    assert reviewed_uk_offer(stored, as_of=now.date()) is not None
    quote = select_uk_offer_quote([stored], product_id=canonical.id, store_id=row.store_id,
        quantity=Decimal("600"), unit="g", as_of=now.date())
    assert quote is not None
    assert (quote.package_count, quote.purchased_quantity, quote.total_price) == (2, 1000, Decimal("0.90"))
    assert quote.price_is_estimated and quote.last_verified is None
    assert quote.availability_scope == "store_observation"
    assert quote.price_source["provider"] == "open_prices"
    assert quote.price_source["checked_on"] == "2026-09-27"
    assert select_uk_offer_quote([stored], product_id=canonical.id, store_id=row.store_id,
        quantity=Decimal("600"), unit="g", as_of=now.date().replace(month=11)) is None
    assert session.get(Product, canonical.id).brand == "Dawtona"


def setup_community_catalogue(session, reviewer, *, review=True):
    row = proposal()
    definition = next(store for store in UK_STORES if store.id == row.store_id)
    session.add(Store(id=definition.id, name=definition.name, country_code="GB", currency_code="GBP"))
    canonical = example(1)[3]
    session.add(canonical)
    session.commit()
    now = datetime(2026, 10, 23, 18, tzinfo=timezone.utc)
    if review:
        cache_review(session, reviewer, now)
    return row, canonical, now


@pytest.mark.parametrize("change", ["missing_mapping", "fingerprint", "pack", "identity"])
def test_import_rejects_unreviewed_or_changed_off_data_without_partial_write(catalogue_db, change):
    session, reviewer, _ = catalogue_db
    row, canonical, now = setup_community_catalogue(session, reviewer, review=change != "missing_mapping")
    if change == "fingerprint":
        session.get(OffCatalogueProduct, "20522605").fingerprint = "f" * 64
    elif change == "pack":
        session.get(OffCatalogueProduct, "20522605").package_quantity = Decimal("400")
    elif change == "identity":
        canonical.name = "Different food"
    session.commit()
    with pytest.raises(ValueError, match="OFF"):
        asyncio.run(import_reviewed_uk_catalogue(AsyncDB(session), [row],
            reviewer_user_id=reviewer, reviewed_at=now, as_of=now.date()))
    session.commit()  # Even a caller catching the error cannot commit a partial import.
    assert session.scalar(select(RegionalProductOffer.id).where(RegionalProductOffer.id == row.proposal_id)) is None


def test_community_price_survives_store_switch_purchase_and_pantry_once(catalogue_db, monkeypatch):
    from app.api.v1 import price_compare, shopping_lists as api
    from app.schemas.shopping_list import ShoppingListResponse
    from app.services import market_catalog, regional_shopping, shopping_list_builder

    session, reviewer, _ = catalogue_db
    supply_sqlite_uuid_defaults(session)
    connection = session.connection().connection.driver_connection
    connection.create_function("gen_random_uuid", 0, lambda: uuid4().hex)
    connection.create_function("hashtext", 1, lambda _: 0)
    connection.create_function("pg_advisory_xact_lock", 1, lambda _: None)
    row, canonical, now = setup_community_catalogue(session, reviewer)
    for module, name in [(market_catalog, "utc_market_date"),
                         (regional_shopping, "regional_pricing_date"),
                         (shopping_list_builder, "regional_pricing_date"),
                         (price_compare, "utc_market_date"), (api, "regional_pricing_date")]:
        monkeypatch.setattr(module, name, lambda: now.date())
    adapter = AsyncDB(session)
    asyncio.run(import_reviewed_uk_catalogue(adapter, [row], reviewer_user_id=reviewer,
        reviewed_at=now, as_of=now.date()))
    user = User(id=uuid4(), email="community-quote@example.test", password_hash="fixture",
        country_code="GB", is_premium=True)
    session.add(user)
    session.commit()
    plan = make_plan(session, user, canonical, quantity="600", include_pantry=False, store_id=row.store_id)
    shopping = asyncio.run(shopping_list_builder.ShoppingListBuilder(adapter).build_from_meal_plan(plan.id))
    list_id, plan_id, product_id = shopping.id, plan.id, canonical.id

    def assert_priced():
        shopping = loaded(session, list_id)
        response = ShoppingListResponse.model_validate(shopping)
        assert response.total_estimated_price == .90 and not response.has_unpriced_items
        item = shopping.items[0]
        assert item.regional_snapshot.quote_data["price_source"]["provider"] == "open_prices"
        assert item.regional_snapshot.quote_data["availability_scope"] == "store_observation"
        assert item.regional_snapshot.quote_data["price_is_estimated"] is True
        return item

    assert_priced()
    comparisons = asyncio.run(price_compare.compare_shopping_list_prices(plan_id, adapter, user))
    lidl = next(result for result in comparisons if result.store_id == row.store_id)
    tesco = next(result for result in comparisons if result.store_id == UK_STORES[0].id)
    assert lidl.total_price == .90 and lidl.is_complete
    assert tesco.total_price is None and not tesco.is_complete
    asyncio.run(api.update_shopping_list_store(plan_id,
        api.ShoppingListStoreRequest(store_id=UK_STORES[0].id), user, adapter))
    assert ShoppingListResponse.model_validate(loaded(session, list_id)).total_estimated_price is None
    asyncio.run(api.update_shopping_list_store(plan_id,
        api.ShoppingListStoreRequest(store_id=row.store_id), user, adapter))
    item = assert_priced()
    item.is_checked = True
    frozen = deepcopy(item.regional_snapshot.quote_data)
    session.delete(session.get(RegionalProductOffer, row.proposal_id))
    session.commit()
    asyncio.run(api.update_shopping_list_store(plan_id,
        api.ShoppingListStoreRequest(store_id=UK_STORES[0].id), user, adapter))
    item = assert_priced()
    assert item.regional_snapshot.quote_data == frozen
    assert item.regional_snapshot.store_id == row.store_id  # Bought at Lidl, not rewritten to Tesco.
    comparisons = asyncio.run(price_compare.compare_shopping_list_prices(plan_id, adapter, user))
    assert all(result.is_complete and result.total_price == .90 for result in comparisons)
    for _ in range(2):
        asyncio.run(api.complete_shopping_list(plan_id, True, user, adapter))
    pantry = session.scalar(select(PantryItem).where(PantryItem.product_id == product_id))
    assert pantry.quantity == 1000 and pantry.unit == "g"
