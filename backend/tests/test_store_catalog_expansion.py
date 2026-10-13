"""Additive supermarket seed: full planning catalogue, honest estimates."""

from __future__ import annotations

import asyncio
import uuid
from datetime import date
from decimal import Decimal

from sqlalchemy import create_engine, func, select
from sqlalchemy.dialects import postgresql
from sqlalchemy.orm import Session

from app.db.fast_food_catalog import FAST_FOOD_PRODUCTS
from app.db.seed import (
    DEPARTMENT_NAMES,
    PRODUCTS_DATA,
    STORE_NAMES,
    _uid,
    seed_database,
)
from app.models.product import ProductAllergen, StoreProduct
from app.models.store import Store, StoreDepartment
from app.models import Base


NEW_STORES = {"Stokrotka", "Kaufland", "Auchan"}


class PairResult:
    def __init__(self, pairs):
        self.pairs = pairs

    def all(self):
        return self.pairs


class RecordingSeedSession:
    """Small identity map reproducing merge/unique-pair semantics without DB."""

    def __init__(self, initial_store_products=()):
        self.rows = {}
        self.store_pairs = {}
        self.queries = []
        self.store_product_merges = 0
        self.added_store_products = 0
        self.flushes = 0
        for row in initial_store_products:
            self.rows[(type(row), row.id)] = row
            self.store_pairs[(row.store_id, row.product_id)] = row

    @staticmethod
    def key(row):
        if isinstance(row, ProductAllergen):
            return (type(row), row.product_id, row.allergen_id)
        return (type(row), row.id)

    def _check_store_pair(self, row):
        if not isinstance(row, StoreProduct):
            return
        stored = self.store_pairs.get((row.store_id, row.product_id))
        if stored is not None and stored.id != row.id:
            raise ValueError("Duplicate store/product pair")

    async def merge(self, row):
        self._check_store_pair(row)
        if isinstance(row, StoreProduct):
            self.store_product_merges += 1
        key = self.key(row)
        existing = self.rows.get(key)
        if existing is None:
            self.rows[key] = row
            if isinstance(row, StoreProduct):
                self.store_pairs[(row.store_id, row.product_id)] = row
            return row
        for name, value in vars(row).items():
            if name != "_sa_instance_state":
                setattr(existing, name, value)
        return existing

    async def execute(self, statement):
        self.queries.append(statement)
        return PairResult([
            (row.store_id, row.product_id) for row in self.store_products
        ])

    def add_all(self, rows):
        for row in rows:
            self._check_store_pair(row)
            assert self.key(row) not in self.rows
            self.rows[self.key(row)] = row
            if isinstance(row, StoreProduct):
                self.added_store_products += 1
                self.store_pairs[(row.store_id, row.product_id)] = row

    async def flush(self):
        self.flushes += 1

    @property
    def store_products(self):
        return list(self.store_pairs.values())


def run_seed(session):
    asyncio.run(seed_database(session))


def test_seven_stores_have_all_390_planning_products_and_departments():
    session = RecordingSeedSession()
    run_seed(session)

    assert len(STORE_NAMES) == len(set(STORE_NAMES)) == 7
    assert NEW_STORES <= set(STORE_NAMES)
    assert len(session.store_products) == 390 * 7
    assert len([row for row in session.rows.values() if isinstance(row, Store)]) == 7
    departments = [
        row for row in session.rows.values() if isinstance(row, StoreDepartment)
    ]
    assert len(departments) == 9 * 7
    product_ids = {_uid(f"product:{row[0]}") for row in PRODUCTS_DATA}
    for store_name in STORE_NAMES:
        store_id = _uid(f"store:{store_name}")
        entries = [row for row in session.store_products if row.store_id == store_id]
        assert {row.product_id for row in entries} == product_ids
        assert {row.name for row in departments if row.store_id == store_id} == set(
            DEPARTMENT_NAMES
        )
        for row in entries:
            assert row.price > 0
            assert row.is_available is True
            assert row.withdrawn_at is None
            assert row.department_id in {
                department.id for department in departments
                if department.store_id == store_id
            }


def test_new_stores_use_reference_purchase_prices_not_fictional_verified_prices():
    session = RecordingSeedSession()
    run_seed(session)

    catalogue = {_uid(f"product:{row[0]}"): row for row in PRODUCTS_DATA}
    new_store_ids = {_uid(f"store:{name}") for name in NEW_STORES}
    assert len([
        row for row in session.store_products if row.store_id in new_store_ids
    ]) == 390 * 3
    for row in session.store_products:
        if row.store_id not in new_store_ids:
            continue
        product_name, unit, quantity, _, reference_price, _ = catalogue[row.product_id]
        assert row.price == reference_price.quantize(Decimal("0.01"))
        assert row.store_brand_name is None
        assert row.last_verified is None
        assert row.id in {_uid(f"sp:{name}:{product_name}") for name in NEW_STORES}
        assert unit in {"g", "kg", "ml", "l", "szt"}
        assert quantity > 0


def test_static_catalogue_never_claims_verification_on_deployment_day():
    session = RecordingSeedSession()
    run_seed(session)

    assert all(row.last_verified is None for row in session.store_products)


def test_seed_preserves_verified_manual_price_and_withdrawal_on_redeployment():
    record = StoreProduct(
        id=_uid("sp:Biedronka:Mleko 2%"),
        store_id=_uid("store:Biedronka"),
        product_id=_uid("product:Mleko 2%"),
        department_id=None,
        price=Decimal("9.87"),
        store_brand_name="Zweryfikowana marka",
        is_available=False,
        last_verified=date(2026, 10, 11),
        withdrawn_at=date(2026, 10, 12),
    )
    session = RecordingSeedSession([record])
    run_seed(session)
    run_seed(session)

    assert record.price == Decimal("9.87")
    assert record.store_brand_name == "Zweryfikowana marka"
    assert record.department_id is None
    assert record.last_verified == date(2026, 10, 11)
    assert record.withdrawn_at == date(2026, 10, 12)
    assert record.is_available is False
    assert len(session.store_products) == 390 * 7
    assert session.added_store_products == 390 * 7 - 1
    assert session.store_product_merges == 0
    assert len(session.queries) == 2


def test_existing_store_product_with_non_seed_id_is_not_duplicated_or_changed():
    record = StoreProduct(
        id=uuid.uuid4(),
        store_id=_uid("store:Stokrotka"),
        product_id=_uid("product:Masło extra"),
        price=Decimal("8.99"),
        store_brand_name=None,
        is_available=True,
        last_verified=date(2026, 10, 10),
        withdrawn_at=None,
    )
    session = RecordingSeedSession([record])
    run_seed(session)

    entries = [
        row for row in session.store_products
        if row.store_id == record.store_id and row.product_id == record.product_id
    ]
    assert entries == [record]
    assert record.price == Decimal("8.99")
    assert record.last_verified == date(2026, 10, 10)
    assert len(session.store_products) == 390 * 7


def test_catalogue_lookup_is_batched_and_excludes_restaurant_or_scanned_products():
    session = RecordingSeedSession()
    run_seed(session)

    assert len(session.queries) == 1
    statement = str(session.queries[0].compile(
        dialect=postgresql.dialect(), compile_kwargs={"literal_binds": True}
    ))
    assert "store_products.store_id IN" in statement
    assert "store_products.product_id IN" in statement
    assert session.store_product_merges == 0
    linked_products = {row.product_id for row in session.store_products}
    restaurant_ids = {
        _uid(f"fast-food:{brand}:{name}")
        for name, brand, *_ in FAST_FOOD_PRODUCTS
    }
    assert not linked_products & restaurant_ids
    assert linked_products == {_uid(f"product:{row[0]}") for row in PRODUCTS_DATA}


def test_real_orm_seed_redeployment_preserves_store_product_changes():
    """Exercise real inserts/uniqueness and a fresh identity map, not just mocks."""
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)

    class SyncSessionAdapter:
        def __init__(self, session):
            self.session = session

        async def merge(self, row):
            return self.session.merge(row)

        async def execute(self, statement):
            return self.session.execute(statement)

        def add_all(self, rows):
            self.session.add_all(rows)

        async def flush(self):
            self.session.flush()

    try:
        with Session(engine) as session:
            run_seed(SyncSessionAdapter(session))
            record = session.get(StoreProduct, _uid("sp:Stokrotka:Masło extra"))
            record.id = uuid.uuid4()  # A previous admin-created relation is valid too.
            record_id = record.id
            record.price = Decimal("9.79")
            record.is_available = False
            record.withdrawn_at = date(2026, 10, 12)
            record.last_verified = date(2026, 10, 11)
            session.commit()

        with Session(engine) as session:
            run_seed(SyncSessionAdapter(session))
            session.commit()
            record = session.get(StoreProduct, record_id)
            assert record.price == Decimal("9.79")
            assert record.is_available is False
            assert record.withdrawn_at == date(2026, 10, 12)
            assert record.last_verified == date(2026, 10, 11)
            assert session.scalar(select(func.count()).select_from(StoreProduct)) == 390 * 7
            assert session.scalar(select(func.count()).select_from(StoreDepartment)) == 9 * 7
    finally:
        engine.dispose()
