"""Reviewed SKU writes remain atomic and separate from global/Polish products."""

import asyncio
from copy import deepcopy
from datetime import date, datetime, timedelta, timezone
from decimal import Decimal
from uuid import uuid4

import pytest
from pydantic import ValidationError
from sqlalchemy import create_engine, delete, event, func, select, update
from sqlalchemy.dialects import postgresql
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session
from sqlalchemy.schema import CreateTable

from app.db.uk_product_catalog import UKCatalogueWriteBlocked, UKProductProposal, apply_uk_product_catalogue
from app.db.uk_store_catalog import UK_STORES
from app.models import Base
from app.models.product import Product, StoreProduct
from app.models.regional_product_offer import RegionalProductOffer
from app.models.store import Store
from app.models.user import User
from app.services.uk_catalogue_import import (
    UKCataloguePermissionError, canonical_base_unit, import_reviewed_uk_catalogue,
)


AS_OF = date(2026, 10, 16)
REVIEWED_AT = datetime(2026, 10, 16, 12, tzinfo=timezone.utc)


class AsyncAdapter:
    """Use actual SQLite ORM transactions without any production connection."""

    def __init__(self, session):
        self.session = session

    def __getattr__(self, name):
        return getattr(self.session, name)

    def begin_nested(self):
        session = self.session

        class Savepoint:
            async def __aenter__(self):
                self.transaction = session.begin_nested()
                return self.transaction.__enter__()

            async def __aexit__(self, *args):
                return self.transaction.__exit__(*args)

        return Savepoint()

    async def execute(self, query):
        return self.session.execute(query)

    async def scalars(self, query):
        return self.session.scalars(query)

    async def flush(self):
        self.session.flush()


@pytest.fixture(params=[True, False], ids=["autoflush", "no-autoflush"])
def catalogue_db(request):
    engine = create_engine("sqlite:///:memory:")

    @event.listens_for(engine, "connect")
    def configure_sqlite(dbapi_connection, _):
        # SQLite's legacy driver otherwise releases the first SAVEPOINT as a
        # committed transaction. Explicit BEGIN gives real outer rollback tests.
        dbapi_connection.isolation_level = None
        dbapi_connection.execute("PRAGMA foreign_keys=ON")

    @event.listens_for(engine, "begin")
    def begin_sqlite(connection):
        connection.exec_driver_sql("BEGIN")

    Base.metadata.create_all(engine)
    with Session(engine, autoflush=request.param) as session:
        admin_id, product_id, polish_store_id = uuid4(), uuid4(), uuid4()
        session.add(User(
            id=admin_id, email="reviewer@example.test", password_hash="not-a-real-hash",
            role="admin", country_code="PL", is_email_verified=True,
        ))
        session.add(Product(
            id=product_id, name="Synthetic canonical oats", unit="g",
            default_quantity=Decimal("100"), serving_quantity=200.0,
            nutrition_per_100={"kcal": 370, "protein": 12, "fat": 7, "carbs": 60},
            measure_options=[{"code": "g", "base_unit": "g", "base_quantity": 1}],
            review_status="approved", submitted_country_code="PL",
        ))
        session.add(Store(id=polish_store_id, name="Polish fixture", country_code="PL", currency_code="PLN"))
        for definition in UK_STORES[:2]:
            session.add(Store(
                id=definition.id, name=definition.name,
                country_code="GB", currency_code="GBP",
            ))
        session.flush()
        session.add(StoreProduct(
            id=uuid4(), store_id=polish_store_id, product_id=product_id,
            price=Decimal("3.99"), is_available=True,
        ))
        session.commit()
        yield session, admin_id, product_id
    engine.dispose()


def proposal(product_id, *, sku="synthetic-500", retailer="tesco"):
    # Purely synthetic observations; not a real retailer pack/price dataset.
    host = "tesco.com" if retailer == "tesco" else "sainsburys.co.uk"
    source = {"url": f"https://www.{host}/synthetic-fixture", "publisher": "Synthetic test", "checked_on": AS_OF.isoformat()}
    return {
        "country_code": "GB", "retailer_slug": retailer, "retailer_sku": sku,
        "canonical_product_id": str(product_id), "name_en": "Synthetic oats",
        "package": {"quantity": "500", "unit": "g", "source": deepcopy(source)},
        "price": {"amount": "1.25", "currency_code": "GBP", "kind": "observed", "source": deepcopy(source)},
        "availability_status": "available_online", "availability_scope": "online_catalogue",
        "availability_source": deepcopy(source),
    }


def run_import(session, reviewer, rows, **kwargs):
    return asyncio.run(import_reviewed_uk_catalogue(
        AsyncAdapter(session), rows, reviewer_user_id=reviewer,
        reviewed_at=kwargs.pop("reviewed_at", REVIEWED_AT),
        as_of=kwargs.pop("as_of", AS_OF), **kwargs,
    ))


def count_offers(session):
    return session.scalar(select(func.count()).select_from(RegionalProductOffer))


def test_writes_local_pack_sources_review_and_price_without_mutating_polish_data(catalogue_db):
    session, reviewer, product_id = catalogue_db
    result = run_import(session, reviewer, [proposal(product_id)])
    assert (result.created, result.updated, result.unchanged) == (1, 0, 0)
    offer = session.get(RegionalProductOffer, result.offer_ids[0])
    expected = UKProductProposal.model_validate(proposal(product_id))
    assert offer.id == expected.proposal_id
    assert offer.store_id == expected.store_id
    assert offer.product_id == product_id
    assert (offer.country_code, offer.currency_code) == ("GB", "GBP")
    assert (offer.package_quantity, offer.package_unit) == (Decimal("500"), "g")
    assert (offer.price, offer.price_kind, offer.estimate_reason) == (Decimal("1.25"), "observed", None)
    assert offer.package_source == expected.package.source.model_dump(mode="json")
    assert offer.price_source == expected.price.source.model_dump(mode="json")
    assert offer.availability_source == expected.availability_source.model_dump(mode="json")
    assert offer.availability_status == "available_online"
    assert offer.availability_scope == "online_catalogue"
    assert offer.reviewed_by_user_id == reviewer
    assert offer.reviewed_at.replace(tzinfo=timezone.utc) == REVIEWED_AT
    assert offer.fingerprint == expected.fingerprint
    canonical = session.get(Product, product_id)
    assert canonical.name == "Synthetic canonical oats"
    assert canonical.default_quantity == Decimal("100")
    assert canonical.serving_quantity == 200
    assert canonical.nutrition_per_100["kcal"] == 370
    assert session.scalar(select(func.count()).select_from(StoreProduct)) == 1
    assert session.scalar(select(StoreProduct.price)) == Decimal("3.99")


def test_no_hidden_commit_and_caller_can_rollback_the_whole_import(catalogue_db):
    session, reviewer, product_id = catalogue_db
    run_import(session, reviewer, [proposal(product_id)])
    assert count_offers(session) == 1
    session.rollback()
    assert count_offers(session) == 0


def test_identical_retries_are_idempotent_even_across_a_new_identity_map(catalogue_db):
    session, reviewer, product_id = catalogue_db
    rows = [proposal(product_id), proposal(product_id)]
    first = run_import(session, reviewer, rows)
    session.commit()
    session.expunge_all()
    second = run_import(session, reviewer, rows, reviewed_at=REVIEWED_AT + timedelta(hours=1))
    assert first.offer_ids == second.offer_ids
    assert (second.created, second.updated, second.unchanged) == (0, 0, 1)
    assert count_offers(session) == 1
    assert session.get(RegionalProductOffer, second.offer_ids[0]).reviewed_at.replace(tzinfo=timezone.utc) == REVIEWED_AT


def test_reviewed_revision_updates_same_sku_and_preserves_estimate_metadata(catalogue_db):
    session, reviewer, product_id = catalogue_db
    first = run_import(session, reviewer, [proposal(product_id)])
    session.commit()
    row = proposal(product_id)
    row["price"].update(amount="1.50", kind="estimate", estimate_reason="Local reviewer estimate of this UK package.")
    row["package"]["quantity"] = "750"
    row["availability_status"] = "out_of_stock"
    second = run_import(session, reviewer, [row], reviewed_at=REVIEWED_AT + timedelta(hours=1))
    assert (second.created, second.updated, second.unchanged) == (0, 1, 0)
    assert second.offer_ids == first.offer_ids
    offer = session.get(RegionalProductOffer, first.offer_ids[0])
    assert offer.package_quantity == Decimal("750")
    assert offer.price == Decimal("1.50")
    assert offer.price_kind == "estimate"
    assert offer.estimate_reason.startswith("Local reviewer")
    assert offer.availability_status == "out_of_stock"
    assert offer.fingerprint == UKProductProposal.model_validate(row).fingerprint


def test_two_sizes_of_same_canonical_product_remain_distinct_skus(catalogue_db):
    session, reviewer, product_id = catalogue_db
    rows = [proposal(product_id), proposal(product_id, sku="synthetic-250")]
    rows[1]["package"]["quantity"] = "250"
    result = run_import(session, reviewer, rows)
    assert result.created == 2
    assert len(set(result.offer_ids)) == 2
    assert {offer.package_quantity for offer in session.scalars(select(RegionalProductOffer))} == {Decimal("250"), Decimal("500")}


def test_persisted_offers_round_trip_into_whole_pack_quotes_with_estimate_preserved(catalogue_db):
    from app.services.regional_offer_pricing import select_uk_offer_quote

    session, reviewer, product_id = catalogue_db
    rows = [proposal(product_id), proposal(product_id, sku="synthetic-250")]
    rows[1]["package"]["quantity"] = "250"
    rows[1]["price"].update(
        amount="0.70", kind="estimate",
        estimate_reason="Local reviewer estimate for the smaller UK package.",
    )
    run_import(session, reviewer, rows)
    session.commit()
    session.expunge_all()
    offers = session.scalars(select(RegionalProductOffer)).all()
    store_id = UK_STORES[0].id
    quote = select_uk_offer_quote(
        offers, product_id=product_id, store_id=store_id,
        quantity=Decimal("600"), unit="g", as_of=AS_OF,
    )
    assert quote is not None
    assert (quote.package_quantity, quote.package_count) == (Decimal("250"), 3)
    assert quote.total_price == Decimal("2.10")
    assert quote.purchased_quantity == Decimal("750")
    assert quote.price_is_estimated is True
    assert quote.last_verified is None
    assert quote.currency_code == "GBP"
    observed_quote = select_uk_offer_quote(
        offers, product_id=product_id, store_id=store_id,
        quantity=Decimal("900"), unit="g", as_of=AS_OF,
    )
    assert observed_quote is not None
    assert (observed_quote.package_quantity, observed_quote.package_count) == (Decimal("500"), 2)
    assert observed_quote.total_price == Decimal("2.50")
    assert observed_quote.price_is_estimated is False
    canonical = session.get(Product, product_id)
    assert canonical.default_quantity == Decimal("100")
    assert canonical.serving_quantity == 200
    assert canonical.nutrition_per_100["kcal"] == 370


@pytest.mark.parametrize("reviewer_kind", ["missing", "ordinary", "banned", "revoked-in-db"])
def test_reviewer_is_reloaded_from_database_not_trusted_from_cached_role(catalogue_db, reviewer_kind):
    session, reviewer, product_id = catalogue_db
    cached_admin = session.get(User, reviewer)
    if reviewer_kind == "missing":
        reviewer = uuid4()
    elif reviewer_kind == "ordinary":
        cached_admin.role = "user"
        session.commit()
    elif reviewer_kind == "banned":
        cached_admin.is_banned = True
        session.commit()
    else:
        session.execute(update(User).where(User.id == reviewer).values(role="user").execution_options(synchronize_session=False))
        assert cached_admin.role == "admin"
    with pytest.raises(UKCataloguePermissionError):
        run_import(session, reviewer, [proposal(product_id)])
    assert count_offers(session) == 0


@pytest.mark.parametrize("invalid", ["missing-product", "pending-product", "unit-mismatch", "missing-store", "pl-store", "stale-source", "conflicting-sku"])
def test_invalid_entire_batch_stages_no_first_row(catalogue_db, invalid):
    session, reviewer, product_id = catalogue_db
    rows = [proposal(product_id), proposal(product_id, sku="second-synthetic")]
    if invalid == "missing-product":
        rows[1]["canonical_product_id"] = str(uuid4())
    elif invalid == "pending-product":
        session.get(Product, product_id).review_status = "pending"
        session.commit()
    elif invalid == "unit-mismatch":
        rows[1]["package"]["unit"] = "ml"
    elif invalid == "missing-store":
        session.execute(delete(Store).where(Store.id == UK_STORES[0].id))
        session.commit()
    elif invalid == "pl-store":
        session.execute(update(Store).where(Store.id == UK_STORES[0].id).values(country_code="PL", currency_code="PLN"))
        session.commit()
    elif invalid == "stale-source":
        rows[1]["price"]["source"]["checked_on"] = (AS_OF - timedelta(days=31)).isoformat()
    else:
        rows[1]["retailer_sku"] = rows[0]["retailer_sku"]
        rows[1]["package"]["quantity"] = "250"
    with pytest.raises((ValueError, ValidationError)):
        run_import(session, reviewer, rows)
    assert count_offers(session) == 0


def test_database_failure_rolls_back_own_batch_without_rolling_back_caller_work(catalogue_db):
    session, reviewer, product_id = catalogue_db
    # A separately flushed caller edit belongs to the outer transaction.
    session.get(Product, product_id).brand = "Caller edit"
    session.flush()

    def fail_before_offer_insert(mapper, connection, target):
        if target.retailer_sku == "fail-fixture":
            raise RuntimeError("Synthetic database flush failure")

    event.listen(RegionalProductOffer, "before_insert", fail_before_offer_insert)
    try:
        with pytest.raises(RuntimeError, match="Synthetic database"):
            run_import(session, reviewer, [proposal(product_id), proposal(product_id, sku="fail-fixture")])
    finally:
        event.remove(RegionalProductOffer, "before_insert", fail_before_offer_insert)
    assert count_offers(session) == 0
    assert session.get(Product, product_id).brand == "Caller edit"
    session.commit()


def test_failure_after_insert_sql_reverts_already_executed_rows(catalogue_db):
    session, reviewer, product_id = catalogue_db
    inserted = []

    def fail_after_insert(connection, cursor, statement, parameters, context, executemany):
        if statement.lower().startswith("insert into regional_product_offers"):
            inserted.append(True)
            raise RuntimeError("Synthetic failure after SQL inserted the rows")

    event.listen(session.bind, "after_cursor_execute", fail_after_insert)
    try:
        with pytest.raises(RuntimeError, match="after SQL"):
            run_import(session, reviewer, [proposal(product_id), proposal(product_id, sku="second-synthetic")])
    finally:
        event.remove(session.bind, "after_cursor_execute", fail_after_insert)
    assert inserted
    assert count_offers(session) == 0
    # The enclosing transaction stays usable without the writer rolling it back.
    assert session.get(Product, product_id).name == "Synthetic canonical oats"


def test_failed_revision_reverts_all_prior_offer_values(catalogue_db):
    session, reviewer, product_id = catalogue_db
    initial = run_import(session, reviewer, [proposal(product_id)])
    session.commit()
    changed = proposal(product_id)
    changed["price"]["amount"] = "1.80"
    bad = proposal(product_id, sku="synthetic-bad")
    bad["package"]["quantity"] = "0"
    with pytest.raises(ValidationError):
        run_import(session, reviewer, [changed, bad])
    assert session.get(RegionalProductOffer, initial.offer_ids[0]).price == Decimal("1.25")
    assert count_offers(session) == 1


def test_stale_review_cannot_overwrite_newer_data(catalogue_db):
    session, reviewer, product_id = catalogue_db
    result = run_import(session, reviewer, [proposal(product_id)])
    session.commit()
    changed = proposal(product_id)
    changed["price"]["amount"] = "1.80"
    with pytest.raises(ValueError, match="older review"):
        run_import(session, reviewer, [changed], reviewed_at=REVIEWED_AT - timedelta(hours=1))
    assert session.get(RegionalProductOffer, result.offer_ids[0]).price == Decimal("1.25")


def test_manual_corruption_is_repaired_even_if_fingerprint_was_not_updated(catalogue_db):
    session, reviewer, product_id = catalogue_db
    result = run_import(session, reviewer, [proposal(product_id)])
    session.commit()
    offer = session.get(RegionalProductOffer, result.offer_ids[0])
    offer.package_quantity = Decimal("1")
    session.commit()
    result = run_import(session, reviewer, [proposal(product_id)])
    assert result.updated == 1
    assert offer.package_quantity == Decimal("500")


def test_deleting_reviewer_does_not_delete_offer_or_block_account_deletion(catalogue_db):
    session, reviewer, product_id = catalogue_db
    result = run_import(session, reviewer, [proposal(product_id)])
    session.commit()
    session.execute(delete(User).where(User.id == reviewer))
    session.commit()
    session.expire_all()
    offer = session.get(RegionalProductOffer, result.offer_ids[0])
    assert offer.reviewed_by_user_id is None
    assert offer.reviewed_at is not None
    assert offer.package_source["publisher"] == "Synthetic test"
    with pytest.raises(UKCataloguePermissionError):
        run_import(session, reviewer, [proposal(product_id)])


def test_pending_unrelated_changes_are_rejected_without_implicit_flush(catalogue_db):
    session, reviewer, product_id = catalogue_db
    product = session.get(Product, product_id)
    product.brand = "Pending caller edit"
    with pytest.raises(ValueError, match="clean session"):
        run_import(session, reviewer, [proposal(product_id)])
    assert product in session.dirty
    session.rollback()
    assert count_offers(session) == 0


@pytest.mark.parametrize(("reviewed_at", "as_of"), [
    (datetime(2026, 10, 16), AS_OF),
    (datetime(2026, 10, 16, tzinfo=timezone(timedelta(hours=1))), AS_OF),
    (REVIEWED_AT, AS_OF - timedelta(days=1)),
    (REVIEWED_AT, REVIEWED_AT),
])
def test_review_clock_must_be_explicit_utc_and_consistent_date(catalogue_db, reviewed_at, as_of):
    session, reviewer, product_id = catalogue_db
    with pytest.raises(ValueError):
        run_import(session, reviewer, [proposal(product_id)], reviewed_at=reviewed_at, as_of=as_of)
    assert count_offers(session) == 0


@pytest.mark.parametrize(("unit", "options", "expected"), [
    ("g", None, "g"), ("kg", None, "g"), ("ml", None, "ml"), ("l", None, "ml"),
    ("opak", [{"base_unit": "ml"}], "ml"), ("szt", [{"base_unit": "g"}], "g"),
])
def test_canonical_dimension_uses_persisted_units_not_translated_name(unit, options, expected):
    product = Product(name="Nazwa nie służy do zgadywania gęstości", unit=unit, measure_options=options)
    assert canonical_base_unit(product) == expected


@pytest.mark.parametrize(("unit", "options"), [
    ("opak", None), ("szt", None), ("cup", [{"base_unit": "g"}]),
    ("g", [{"base_unit": "ml"}]), ("opak", [{"base_unit": "g"}, {"base_unit": "ml"}]),
])
def test_ambiguous_or_conflicting_dimensions_are_rejected(unit, options):
    with pytest.raises(ValueError):
        canonical_base_unit(Product(name="Mleko", unit=unit, measure_options=options))


@pytest.mark.parametrize(("field", "value"), [
    ("country_code", "PL"), ("currency_code", "PLN"), ("package_quantity", Decimal("0")),
    ("package_unit", "kg"), ("price", Decimal("0")), ("price_kind", "unknown"),
    ("price_kind", "estimate"), ("package_source", None), ("price_source", None),
    ("availability_source", None),
    ("availability_status", "all_branches"), ("availability_scope", "national_stock"),
    ("fingerprint", "bad"), ("name_en", "  "), ("retailer_sku", "  "),
])
def test_database_constraints_reject_invalid_direct_writes(catalogue_db, field, value):
    session, reviewer, product_id = catalogue_db
    result = run_import(session, reviewer, [proposal(product_id)])
    session.commit()
    with pytest.raises(IntegrityError):
        with session.begin_nested():
            session.execute(update(RegionalProductOffer).where(RegionalProductOffer.id == result.offer_ids[0]).values({field: value}))


def test_store_and_sku_are_unique_independently_of_offer_uuid(catalogue_db):
    session, reviewer, product_id = catalogue_db
    result = run_import(session, reviewer, [proposal(product_id)])
    session.commit()
    first = session.get(RegionalProductOffer, result.offer_ids[0])
    values = {column.name: getattr(first, column.name) for column in RegionalProductOffer.__table__.columns if column.name != "id"}
    with pytest.raises(IntegrityError):
        with session.begin_nested():
            session.add(RegionalProductOffer(id=uuid4(), **values))
            session.flush()


def test_pg_ddl_is_additive_and_keeps_exact_numeric_types_sources_and_uniqueness():
    ddl = str(CreateTable(RegionalProductOffer.__table__).compile(dialect=postgresql.dialect()))
    assert "CREATE TABLE regional_product_offers" in ddl
    assert "NUMERIC(9, 3)" in ddl and "NUMERIC(10, 2)" in ddl
    assert "UNIQUE (store_id, retailer_sku)" in ddl
    assert "package_source JSON NOT NULL" in ddl
    assert "price_source JSON NOT NULL" in ddl
    assert "availability_source JSON NOT NULL" in ddl
    assert "TIMESTAMP WITH TIME ZONE NOT NULL" in ddl
    assert "ON DELETE SET NULL" in ddl
    assert "DROP " not in ddl and "ALTER TABLE products" not in ddl


def test_new_table_can_be_created_idempotently_beside_existing_sqlite_tables():
    engine = create_engine("sqlite:///:memory:")
    existing_tables = [table for table in Base.metadata.sorted_tables if table.name != "regional_product_offers"]
    try:
        Base.metadata.create_all(engine, tables=existing_tables)
        with Session(engine) as session:
            old_user_id, old_store_id, old_product_id = uuid4(), uuid4(), uuid4()
            session.add(User(id=old_user_id, email="existing@example.test", password_hash="test"))
            session.add(Store(id=old_store_id, name="Existing Polish store", country_code="PL", currency_code="PLN"))
            session.add(Product(id=old_product_id, name="Existing Polish product", unit="g", default_quantity=Decimal("100")))
            session.commit()
        RegionalProductOffer.__table__.create(engine, checkfirst=True)
        RegionalProductOffer.__table__.create(engine, checkfirst=True)
        with Session(engine) as session:
            assert session.get(User, old_user_id).country_code == "PL"
            assert session.get(Store, old_store_id).currency_code == "PLN"
            assert session.get(Product, old_product_id).default_quantity == Decimal("100")
            assert count_offers(session) == 0
    finally:
        engine.dispose()


def test_legacy_apply_entrypoint_is_still_blocked():
    with pytest.raises(UKCatalogueWriteBlocked):
        asyncio.run(apply_uk_product_catalogue(None, None))
