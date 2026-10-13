"""Niepełny lub niewiarygodny koszyk nie może wygrywać porównania cen."""

import uuid
from datetime import date, timedelta
from decimal import Decimal
from types import SimpleNamespace

import pytest

from app.api.v1.price_compare import compare_prices


class _Result:
    def __init__(self, value):
        self.value = value

    def scalar_one_or_none(self):
        return self.value

    def scalars(self):
        return self

    def all(self):
        return self.value


class _Db:
    def __init__(self, plan, stores, prices):
        self.results = iter([_Result(plan), _Result(stores), _Result(prices)])
        self.calls = 0

    async def execute(self, statement):
        self.calls += 1
        return next(self.results)


def _fixture(prices, *, package_known=True):
    user = SimpleNamespace(id=uuid.uuid4())
    product = SimpleNamespace(
        id=uuid.uuid4(), name="Mąka pszenna", unit="g" if package_known else "opak",
        default_quantity=1000 if package_known else 1,
        serving_quantity=None, measure_options=None,
    )
    plan = SimpleNamespace(user_id=user.id, status="active", end_date=date.today() + timedelta(days=6), entries=[SimpleNamespace(
        servings_multiplier=1, recipe=SimpleNamespace(ingredients=[SimpleNamespace(
            product=product, quantity=500, unit="g",
        )]),
    )])
    stores = [SimpleNamespace(id=uuid.uuid4(), name=f"Sklep {i}") for i in range(len(prices))]
    rows = []
    for store, price in zip(stores, prices):
        if price is not None:
            rows.append(SimpleNamespace(
                store_id=store.id, product_id=product.id, price=price,
                is_available=True, store_brand_name=None, last_verified=None,
            ))
    return user, _Db(plan, stores, rows), rows


@pytest.mark.asyncio
async def test_missing_item_does_not_make_store_the_cheapest():
    user, db, _ = _fixture([None, Decimal("5.00"), Decimal("7.00")])
    results = await compare_prices(uuid.uuid4(), db=db, current_user=user)
    assert db.calls == 3
    assert [result.store_name for result in results] == ["Sklep 1", "Sklep 2", "Sklep 0"]
    assert results[0].is_cheapest
    assert results[0].savings_vs_most_expensive == 2.0
    assert not results[-1].is_complete
    assert results[-1].missing_products == ["Mąka pszenna"]
    assert not results[-1].is_cheapest
    assert results[-1].savings_vs_most_expensive == 0


@pytest.mark.asyncio
async def test_unavailable_product_does_not_count_as_complete():
    user, db, rows = _fixture([Decimal("1.00"), Decimal("5.00")])
    rows[0].is_available = False
    results = await compare_prices(uuid.uuid4(), db=db, current_user=user)
    assert results[0].store_name == "Sklep 1"
    assert not results[-1].is_complete
    assert results[-1].items == []


@pytest.mark.asyncio
async def test_reference_prices_are_explicitly_estimated():
    user, db, rows = _fixture([Decimal("5.00"), Decimal("7.00")])
    rows[1].last_verified = date(2026, 10, 1)
    results = await compare_prices(uuid.uuid4(), db=db, current_user=user)
    assert results[0].has_estimated_prices
    assert results[0].items[0].price_is_estimated
    assert results[0].items[0].last_verified is None
    assert not results[1].has_estimated_prices
    assert not results[1].items[0].price_is_estimated
    assert results[1].items[0].last_verified == date(2026, 10, 1)


@pytest.mark.asyncio
async def test_unknown_package_weight_is_not_assumed_to_be_one_package():
    user, db, _ = _fixture([Decimal("5.00")], package_known=False)
    results = await compare_prices(uuid.uuid4(), db=db, current_user=user)
    assert not results[0].is_complete
    assert not results[0].is_cheapest
    assert results[0].missing_products == ["Mąka pszenna"]


@pytest.mark.asyncio
@pytest.mark.parametrize("price", [Decimal("0"), Decimal("-1"), Decimal("NaN"), Decimal("Infinity")])
async def test_invalid_price_is_not_a_free_complete_basket(price):
    user, db, _ = _fixture([price])
    results = await compare_prices(uuid.uuid4(), db=db, current_user=user)
    assert not results[0].is_complete
    assert not results[0].is_cheapest
    assert results[0].items == []


def test_all_seeded_stores_are_supported_by_admin_flyer_scanner():
    from app.db.seed import STORE_NAMES
    from app.services.promo_ai_scanner import _AGGREGATOR_SLUGS

    assert set(STORE_NAMES) == set(_AGGREGATOR_SLUGS)


@pytest.mark.asyncio
async def test_empty_plan_has_no_fake_incomplete_baskets():
    user = SimpleNamespace(id=uuid.uuid4())
    plan = SimpleNamespace(user_id=user.id, status="active", end_date=date.today() + timedelta(days=6), entries=[])
    stores = [SimpleNamespace(id=uuid.uuid4(), name="Stokrotka")]
    db = _Db(plan, stores, [])
    assert await compare_prices(uuid.uuid4(), db=db, current_user=user) == []


@pytest.mark.asyncio
async def test_one_unconvertible_ingredient_makes_product_quantity_incomplete():
    user, db, _ = _fixture([Decimal("5.00")])
    plan = next(db.results).value
    # Ta sama mąka występuje raz w gramach, raz jako opakowanie bez masy.
    # Zignorowanie drugiego składnika zaniżałoby cenę całego koszyka.
    ingredient = plan.entries[0].recipe.ingredients[0]
    plan.entries[0].recipe.ingredients.append(SimpleNamespace(
        product=ingredient.product, quantity=1, unit="opak",
    ))
    remaining = list(db.results)
    db.results = iter([_Result(plan), *remaining])
    results = await compare_prices(uuid.uuid4(), db=db, current_user=user)
    assert not results[0].is_complete
    assert results[0].missing_products == ["Mąka pszenna"]
