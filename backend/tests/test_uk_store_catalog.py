"""Preparatory UK catalogue must not fabricate stock or mix national IDs."""

import asyncio
from dataclasses import FrozenInstanceError, fields, replace
from datetime import date
from uuid import UUID, uuid4, uuid5

import pytest

from app.db.uk_store_catalog import (
    UK_DEPARTMENT_NAMES,
    UK_STORE_SOURCE,
    UK_STORES,
    UKStoreDefinition,
    seed_uk_stores,
    store_catalogue_id,
)


def test_uk_catalogue_contains_unique_local_retailers() -> None:
    assert {store.name for store in UK_STORES} == {
        "Tesco", "Sainsbury's", "Asda", "Aldi", "Morrisons",
        "Lidl", "Co-op", "Waitrose", "Iceland", "Ocado",
    }
    assert len(UK_STORES) == len({store.slug for store in UK_STORES}) == 10
    assert len({store.id for store in UK_STORES}) == 10


def test_country_scoped_ids_are_deterministic_and_separate_from_polish_seed() -> None:
    # Legacy seed namespace/identity: existing Polish IDs must remain untouched.
    legacy_namespace = UUID("a1b2c3d4-e5f6-7890-abcd-ef1234567890")
    polish_lidl_id = uuid5(legacy_namespace, "store:Lidl")
    uk_lidl = next(store for store in UK_STORES if store.slug == "lidl")

    assert uk_lidl.id == store_catalogue_id("GB", "lidl")
    assert uk_lidl.id == store_catalogue_id(" gb ", " LIDL ")
    assert uk_lidl.id != store_catalogue_id("PL", "lidl")
    assert uk_lidl.id != polish_lidl_id
    assert replace(uk_lidl, name="Lidl UK").id == uk_lidl.id
    assert all(store.id.version == 5 for store in UK_STORES)


def test_catalogue_keeps_gbp_currency_and_traceable_name_source() -> None:
    assert all(store.country_code == "GB" for store in UK_STORES)
    assert all(store.currency == "GBP" for store in UK_STORES)
    assert all(store.source == UK_STORE_SOURCE for store in UK_STORES)
    assert UK_STORE_SOURCE.publisher == "Department for Environment, Food & Rural Affairs"
    assert UK_STORE_SOURCE.url.startswith("https://www.gov.uk/")
    assert UK_STORE_SOURCE.url.endswith("#grocery-market-shares")
    assert UK_STORE_SOURCE.checked_on == date(2026, 10, 15)


def test_department_names_are_shared_generic_english_labels() -> None:
    assert len(UK_DEPARTMENT_NAMES) == len(set(UK_DEPARTMENT_NAMES)) == 9
    assert "Fruit and vegetables" in UK_DEPARTMENT_NAMES
    assert "Dairy and eggs" in UK_DEPARTMENT_NAMES
    assert all(store.department_names == UK_DEPARTMENT_NAMES for store in UK_STORES)
    assert all(label.isascii() for label in UK_DEPARTMENT_NAMES)


def test_preparatory_catalogue_has_no_fabricated_stock_prices_or_store_links() -> None:
    # Name provenance does not imply products are sold or their price verified.
    entry_fields = {field.name for field in fields(UKStoreDefinition)}
    assert not entry_fields & {
        "price", "price_gbp", "is_available", "products", "store_products",
        "last_verified", "stock", "product_ids",
    }


def test_catalogue_entries_and_provenance_are_frozen() -> None:
    assert isinstance(UK_STORES, tuple)
    assert isinstance(UK_DEPARTMENT_NAMES, tuple)
    with pytest.raises(FrozenInstanceError):
        UK_STORES[0].currency = "PLN"  # type: ignore[misc]
    with pytest.raises(FrozenInstanceError):
        UK_STORE_SOURCE.publisher = "Unverified"  # type: ignore[misc]


@pytest.mark.parametrize(
    ("country_code", "currency"),
    [("PL", "GBP"), ("GB", "PLN"), ("UK", "GBP"), ("GB", "EUR")],
)
def test_uk_definition_rejects_other_markets_and_currencies(
    country_code: str, currency: str,
) -> None:
    with pytest.raises(ValueError):
        UKStoreDefinition(
            slug="tesco", name="Tesco", country_code=country_code, currency=currency,
        )


@pytest.mark.parametrize(
    ("country_code", "slug"),
    [("", "lidl"), ("GBR", "lidl"), ("GB", ""), ("GB", "../lidl"),
     ("GB", "lidl/PL"), ("GB", "co op")],
)
def test_ids_reject_ambiguous_or_empty_identity_parts(
    country_code: str, slug: str,
) -> None:
    with pytest.raises(ValueError):
        store_catalogue_id(country_code, slug)


def test_empty_retailer_display_name_is_rejected() -> None:
    with pytest.raises(ValueError):
        UKStoreDefinition(slug="tesco", name=" ")


@pytest.mark.parametrize("autoflush", [True, False])
def test_seed_is_create_only_country_separate_and_creates_no_product_links(
    autoflush: bool,
) -> None:
    from sqlalchemy import create_engine, func, select
    from sqlalchemy.orm import Session

    from app.models import Base
    from app.models.product import StoreProduct
    from app.models.store import Store, StoreDepartment

    class AsyncAdapter:
        def __init__(self, session: Session) -> None:
            self.session = session

        async def get(self, model, identifier):
            return self.session.get(model, identifier)

        def add(self, row) -> None:
            self.session.add(row)

        async def flush(self) -> None:
            self.session.flush()

    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)
    polish_id = uuid5(UUID("a1b2c3d4-e5f6-7890-abcd-ef1234567890"), "store:Lidl")
    polish_department_id = uuid4()
    try:
        with Session(engine, autoflush=autoflush) as session:
            session.add(Store(
                id=polish_id,
                name="Lidl",
                country_code="PL",
                currency_code="PLN",
                logo_url="https://example.com/pl-lidl.png",
                department_order={"Polski dział": 8},
            ))
            session.add(StoreDepartment(
                id=polish_department_id,
                store_id=polish_id,
                name="Polski dział",
                sort_order=8,
            ))
            session.commit()

            asyncio.run(seed_uk_stores(AsyncAdapter(session)))
            session.commit()
            ids_after_first_seed = set(session.scalars(select(Store.id)))
            department_ids_after_first_seed = set(session.scalars(select(StoreDepartment.id)))
            tesco = session.get(Store, UK_STORES[0].id)
            assert tesco.department_order == {
                name: index for index, name in enumerate(UK_DEPARTMENT_NAMES)
            }
            tesco.name = "Tesco (edited by administrator)"
            tesco.department_order = {"Custom department": 4}
            department = session.get(
                StoreDepartment,
                uuid5(UK_STORES[0].id, f"department:{UK_DEPARTMENT_NAMES[0]}"),
            )
            department.name = "Custom department"
            department.sort_order = 4
            session.commit()

        # A fresh identity map proves idempotence across real deployments.
        with Session(engine, autoflush=autoflush) as session:
            asyncio.run(seed_uk_stores(AsyncAdapter(session)))
            session.commit()
            assert set(session.scalars(select(Store.id))) == ids_after_first_seed
            assert set(session.scalars(select(StoreDepartment.id))) == department_ids_after_first_seed
            assert session.scalar(select(func.count()).select_from(Store)) == 11
            assert session.scalar(select(func.count()).select_from(StoreDepartment)) == 91
            assert session.scalar(select(func.count()).select_from(StoreProduct)) == 0
            polish_store = session.get(Store, polish_id)
            assert polish_store.country_code == "PL"
            assert polish_store.currency_code == "PLN"
            assert polish_store.name == "Lidl"
            assert polish_store.logo_url == "https://example.com/pl-lidl.png"
            assert polish_store.department_order == {"Polski dział": 8}
            assert session.get(StoreDepartment, polish_department_id).name == "Polski dział"
            tesco = session.get(Store, UK_STORES[0].id)
            assert tesco.name == "Tesco (edited by administrator)"
            assert tesco.department_order == {"Custom department": 4}
            department = session.get(
                StoreDepartment,
                uuid5(UK_STORES[0].id, f"department:{UK_DEPARTMENT_NAMES[0]}"),
            )
            assert department.name == "Custom department"
            assert department.sort_order == 4
    finally:
        engine.dispose()


def test_seed_rejects_a_deterministic_id_claimed_by_another_market() -> None:
    from sqlalchemy import create_engine, func, select
    from sqlalchemy.orm import Session

    from app.models import Base
    from app.models.store import Store, StoreDepartment

    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)

    class AsyncAdapter:
        def __init__(self, session: Session) -> None:
            self.session = session

        async def get(self, model, identifier):
            return self.session.get(model, identifier)

        def add(self, row) -> None:
            self.session.add(row)

        async def flush(self) -> None:
            self.session.flush()

    try:
        with Session(engine) as session:
            session.add(Store(
                id=UK_STORES[0].id, name="Polish store",
                country_code="PL", currency_code="PLN",
            ))
            session.commit()
            with pytest.raises(ValueError, match="different market or currency"):
                asyncio.run(seed_uk_stores(AsyncAdapter(session)))
            session.rollback()
            assert session.scalar(select(func.count()).select_from(Store)) == 1
            assert session.scalar(select(func.count()).select_from(StoreDepartment)) == 0
    finally:
        engine.dispose()
