"""Regresje wydajności, które nie powinny zmieniać wyników API."""

import uuid
from types import SimpleNamespace

import pytest

from app.api.v1.price_compare import compare_prices


class _OneResult:
    def __init__(self, value):
        self.value = value

    def scalar_one_or_none(self):
        return self.value


class _ManyResult:
    def __init__(self, values):
        self.values = values

    def scalars(self):
        return self

    def all(self):
        return self.values


class _PriceCompareDb:
    def __init__(self, meal_plan, stores, store_products):
        self._results = [
            _OneResult(meal_plan),
            _ManyResult(stores),
            _ManyResult(store_products),
        ]
        self.execute_count = 0

    async def execute(self, _statement):
        result = self._results[self.execute_count]
        self.execute_count += 1
        return result


@pytest.mark.asyncio
async def test_price_compare_loads_all_store_prices_in_one_query() -> None:
    user_id = uuid.uuid4()
    product_id = uuid.uuid4()
    product = SimpleNamespace(
        id=product_id,
        name="Mąka pszenna",
        unit="g",
        default_quantity=100,
    )
    ingredient = SimpleNamespace(product=product, quantity=150, unit="g")
    recipe = SimpleNamespace(ingredients=[ingredient])
    meal_plan = SimpleNamespace(
        user_id=user_id,
        entries=[SimpleNamespace(recipe=recipe, servings_multiplier=1)],
    )
    stores = [
        SimpleNamespace(id=uuid.uuid4(), name="Sklep A"),
        SimpleNamespace(id=uuid.uuid4(), name="Sklep B"),
    ]
    store_products = [
        SimpleNamespace(
            store_id=store.id,
            product_id=product_id,
            price=4.0 + index,
            store_brand_name=None,
        )
        for index, store in enumerate(stores)
    ]
    db = _PriceCompareDb(meal_plan, stores, store_products)

    result = await compare_prices(
        uuid.uuid4(),
        db=db,
        current_user=SimpleNamespace(id=user_id),
    )

    # Plan, sklepy i wszystkie ceny: zawsze trzy zapytania, niezależnie
    # od liczby par sklep–produkt.
    assert db.execute_count == 3
    assert [entry.total_price for entry in result] == [8.0, 10.0]
