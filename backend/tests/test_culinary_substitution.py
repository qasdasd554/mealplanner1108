"""Nutrition similarity alone must not change an ingredient's cooking role."""
import asyncio
from uuid import UUID, uuid4

import pytest

from app.models import Product, ShoppingListItem, Store, StoreProduct
from app.services.product_substitution import ProductSubstitutionService
from tests.test_uk_ons_shopping import food
from tests.test_uk_pricing_availability_integration import db, Database
from tests.uk_regional_fixtures import reviewed_offer, uk_store


@pytest.mark.parametrize("country", ["PL", "GB"])
@pytest.mark.parametrize("original,valid,invalid", [
    ("Jajka", "Jajka przepiórcze", "Parmezan"),
    ("Ryż biały", "Ryż basmati", "Mąka tempura"),
    ("Mleko 2%", "Mleko bez laktozy", "Sos sojowy"),
    ("Mleko 2%", "Mleko kozie", "Śmietana 30%"),
    ("Oliwa z oliwek", "Olej rzepakowy", "Ocet winny czerwony"),
    ("Pierś z kurczaka", "Polędwiczki z kurczaka", "Szynka konserwowa"),
])
def test_automatic_substitutes_keep_the_ingredients_cooking_role(db, country, original, valid, invalid):
    reference, alternative, unrelated = [food(name) for name in (original, valid, invalid)]
    db.add_all([reference, alternative, unrelated])
    if country == "GB":
        shop = uk_store(db, slug="tesco")
        for product in (reference, alternative, unrelated):
            reviewed_offer(db, product, shop)
    else:
        shop = Store(id=uuid4(), name="Fixture", country_code="PL", currency_code="PLN")
        db.add(shop)
        db.flush()
        for product in (reference, alternative, unrelated):
            db.add(StoreProduct(id=uuid4(), store_id=shop.id, product_id=product.id,
                                price=3, is_available=True))
    db.commit()
    rows = asyncio.run(ProductSubstitutionService(Database(db)).auto_find_similar(reference.id, shop.id))
    assert [row["product"].id for row in rows] == [alternative.id]


def test_uk_ranking_does_not_drop_the_valid_food_after_arbitrary_first_200_ids(db):
    reference = food("Ryż biały")
    alternative = food("Ryż basmati")
    alternative.id = UUID(int=2**128 - 1)
    db.add_all([reference, alternative])
    shop = uk_store(db, slug="tesco")
    reviewed_offer(db, alternative, shop)
    for index in range(205):
        unrelated = Product(id=UUID(f"00000000-0000-0000-0000-a{index:011x}"), name=f"Unrelated dessert {index}",
            unit="g", default_quantity=100, review_status="approved",
            nutrition_per_100={"kcal": 350, "carbs": 80, "protein": 7, "fat": 1})
        db.add(unrelated)
        reviewed_offer(db, unrelated, shop)
    db.commit()
    rows = asyncio.run(ProductSubstitutionService(Database(db)).auto_find_similar(reference.id, shop.id))
    assert [row["product"].id for row in rows] == [alternative.id]


@pytest.mark.parametrize("original,candidate,allowed", [
    ("Milk", "Mleko bez laktozy", True),
    ("White rice", "Ryż basmati", True),
    ("Chicken breast", "Filet z indyka", True),
    ("Milk", "Soy sauce", False),
    ("Rice", "Rice flour", False),
    ("Ryż biały", "Makaron ryżowy", False),
    ("Mleko 2%", "Mleko skondensowane słodzone", False),
    ("Mleko 2%", "Milk chocolate", False),
    ("Pierś z kurczaka", "Breaded chicken breast", False),
    ("Schab z kością", "Schab bez kości", False),
    ("Ciecierzyca sucha", "Ciecierzyca konserwowa", False),
    ("Bazylia świeża", "Bazylia suszona", False),
    ("Mąka pszenna", "Mąka kokosowa", False),
    ("Rice pudding", "Rice pudding", True),
    ("", "", False),
])
def test_bilingual_roles_do_not_erase_preparation_or_unknown_food_identity(original, candidate, allowed):
    from app.services.culinary_substitution import same_cooking_role
    assert same_cooking_role(original, candidate) is allowed


@pytest.mark.parametrize("country", ["PL", "GB"])
def test_swapping_different_sized_pieces_preserves_food_amount_not_piece_count(db, country):
    from decimal import Decimal
    from app.services.regional_shopping import apply_regional_item_quote, regional_pricing_date
    original, selected = food("Tortilla pszenna"), food("Tortilla kukurydziana")
    for product, weight in ((original, 40), (selected, 80)):
        product.unit, product.default_quantity = "szt", 1
        product.measure_options = [{"code": "szt", "base_quantity": weight, "base_unit": "g"}]
    db.add_all([original, selected])
    item = ShoppingListItem(id=uuid4(), required_quantity=Decimal(2), unit="szt", is_checked=True)
    if country == "GB":
        shop = uk_store(db, slug="tesco")
        reviewed_offer(db, selected, shop)
        apply_regional_item_quote(item, product=original, quantity=Decimal(2), unit="szt",
            offers=[], store_id=shop.id, as_of=regional_pricing_date())
    else:
        shop = Store(id=uuid4(), name="Fixture", country_code="PL", currency_code="PLN")
        db.add(shop)
        db.flush()
        old = StoreProduct(id=uuid4(), product_id=original.id, store_id=shop.id, price=3)
        db.add_all([old, StoreProduct(id=uuid4(), product_id=selected.id,
            store_id=shop.id, price=4, is_available=True)])
        item.store_product_id = old.id
    db.commit()
    asyncio.run(ProductSubstitutionService(Database(db)).substitute_shopping_list_item(item, selected.id, shop.id))
    assert item.required_quantity == (80 if country == "GB" else 1)
    assert item.unit == ("g" if country == "GB" else "szt")
    assert not item.is_checked


@pytest.mark.parametrize("state", ["needed", "bought", "pantry", "completed"])
def test_withdrawal_preserves_bought_and_pantry_foods_and_prices_all_required_packs(db, state):
    from datetime import date
    from decimal import Decimal
    from app.models import MealPlan, ShoppingList, User
    original, selected = food("Makaron penne"), food("Makaron spaghetti")
    original.default_quantity = selected.default_quantity = 500
    owner = User(id=uuid4(), email="withdrawal@example.invalid", password_hash="test")
    shop = Store(id=uuid4(), name="Fixture", country_code="PL", currency_code="PLN")
    db.add_all([owner, shop, original, selected])
    db.flush()
    old = StoreProduct(id=uuid4(), store_id=shop.id, product_id=original.id, price=3)
    replacement = StoreProduct(id=uuid4(), store_id=shop.id, product_id=selected.id, price=4,
                               is_available=True)
    plan = MealPlan(id=uuid4(), user_id=owner.id, store_id=shop.id, start_date=date(2026, 10, 28),
                    duration_days=1, meals_per_day=1, status="active")
    shopping = ShoppingList(id=uuid4(), meal_plan_id=plan.id, store_id=shop.id,
        status="completed" if state == "completed" else "pending")
    item = ShoppingListItem(id=uuid4(), shopping_list_id=shopping.id, store_product_id=old.id,
        required_quantity=750, unit="g", estimated_price=0 if state == "pantry" else 6,
        is_checked=state == "bought", is_from_pantry=state == "pantry")
    db.add_all([old, replacement, plan, shopping, item])
    db.commit()
    changed = asyncio.run(ProductSubstitutionService(Database(db))._auto_swap_in_shopping_lists(
        original.id, selected.id, replacement, [plan]))
    if state == "needed":
        assert item.store_product_id == replacement.id and item.required_quantity == 750
        assert item.estimated_price == Decimal(8)  # Two 500 g packs, not one pack.
        assert changed == [str(shopping.id)]
    else:
        assert item.store_product_id == old.id
        assert item.estimated_price == (0 if state == "pantry" else 6)
        assert changed == []
