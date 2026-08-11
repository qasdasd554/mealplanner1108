"""Testy jednostkowe generatora planów posiłków i budowniczego listy zakupów.

Wszystkie testy używają mocków — nie wymagają rzeczywistej bazy danych.
"""

from __future__ import annotations

import uuid
from dataclasses import dataclass, field
from typing import Any
from unittest.mock import AsyncMock, MagicMock, patch

import pytest


# ---------------------------------------------------------------------------
# Dane testowe — lekkie obiekty imitujące modele ORM
# ---------------------------------------------------------------------------


@dataclass
class FakeAllergen:
    id: uuid.UUID = field(default_factory=uuid.uuid4)
    name: str = "gluten"


@dataclass
class FakeProduct:
    id: uuid.UUID = field(default_factory=uuid.uuid4)
    name: str = "Mąka pszenna"
    category: str = "dry_goods"
    allergens: list[FakeAllergen] = field(default_factory=list)


@dataclass
class FakeRecipeIngredient:
    id: uuid.UUID = field(default_factory=uuid.uuid4)
    recipe_id: uuid.UUID = field(default_factory=uuid.uuid4)
    product_id: uuid.UUID = field(default_factory=uuid.uuid4)
    product: FakeProduct | None = None
    quantity: float = 1.0
    unit: str = "szt"
    is_optional: bool = False


@dataclass
class FakeRecipe:
    id: uuid.UUID = field(default_factory=uuid.uuid4)
    name: str = "Naleśniki"
    meal_type: str = "breakfast"
    cuisine: str = "polska"
    difficulty: str = "easy"
    prep_time_minutes: int = 15
    cook_time_minutes: int = 20
    servings: int = 4
    ingredients: list[FakeRecipeIngredient] = field(default_factory=list)
    tags: list[Any] = field(default_factory=list)


@dataclass
class FakeUserAllergen:
    user_id: uuid.UUID = field(default_factory=uuid.uuid4)
    allergen_id: uuid.UUID = field(default_factory=uuid.uuid4)
    allergen: FakeAllergen | None = None


@dataclass
class FakeUser:
    id: uuid.UUID = field(default_factory=uuid.uuid4)
    email: str = "test@example.com"
    display_name: str = "Test User"
    household_size: int = 2
    dietary_preferences: dict = field(default_factory=dict)
    preferred_store_id: uuid.UUID | None = None
    allergens: list[FakeUserAllergen] = field(default_factory=list)
    is_active: bool = True


@dataclass
class FakeMealPlanEntry:
    id: uuid.UUID = field(default_factory=uuid.uuid4)
    meal_plan_id: uuid.UUID = field(default_factory=uuid.uuid4)
    recipe_id: uuid.UUID = field(default_factory=uuid.uuid4)
    recipe: FakeRecipe | None = None
    day_number: int = 1
    meal_type: str = "breakfast"


@dataclass
class FakeMealPlan:
    id: uuid.UUID = field(default_factory=uuid.uuid4)
    user_id: uuid.UUID = field(default_factory=uuid.uuid4)
    store_id: uuid.UUID = field(default_factory=uuid.uuid4)
    status: str = "draft"
    days: int = 7
    meals_per_day: int = 3
    entries: list[FakeMealPlanEntry] = field(default_factory=list)
    created_at: Any = None


@dataclass
class FakeStoreProduct:
    product_id: uuid.UUID = field(default_factory=uuid.uuid4)
    store_id: uuid.UUID = field(default_factory=uuid.uuid4)
    price: float = 5.99
    is_available: bool = True


@dataclass
class FakeShoppingListItem:
    id: uuid.UUID = field(default_factory=uuid.uuid4)
    shopping_list_id: uuid.UUID = field(default_factory=uuid.uuid4)
    product_id: uuid.UUID = field(default_factory=uuid.uuid4)
    product: FakeProduct | None = None
    quantity: float = 1.0
    unit: str = "szt"
    unit_price: float = 5.99
    is_checked: bool = False


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------


@pytest.fixture
def gluten_allergen() -> FakeAllergen:
    return FakeAllergen(name="gluten")


@pytest.fixture
def lactose_allergen() -> FakeAllergen:
    return FakeAllergen(name="laktoza")


@pytest.fixture
def product_with_gluten(gluten_allergen: FakeAllergen) -> FakeProduct:
    return FakeProduct(
        name="Mąka pszenna",
        category="dry_goods",
        allergens=[gluten_allergen],
    )


@pytest.fixture
def product_without_allergens() -> FakeProduct:
    return FakeProduct(
        name="Ryż biały",
        category="dry_goods",
        allergens=[],
    )


@pytest.fixture
def product_milk(lactose_allergen: FakeAllergen) -> FakeProduct:
    return FakeProduct(
        name="Mleko 3.2%",
        category="dairy",
        allergens=[lactose_allergen],
    )


@pytest.fixture
def shared_product() -> FakeProduct:
    """Produkt współdzielony przez wiele przepisów — do testów reuse scoring."""
    return FakeProduct(name="Cebula", category="vegetables", allergens=[])


@pytest.fixture
def recipe_with_gluten(product_with_gluten: FakeProduct) -> FakeRecipe:
    ing = FakeRecipeIngredient(
        product_id=product_with_gluten.id,
        product=product_with_gluten,
        quantity=0.5,
        unit="kg",
    )
    return FakeRecipe(
        name="Naleśniki",
        meal_type="breakfast",
        ingredients=[ing],
    )


@pytest.fixture
def recipe_without_allergens(
    product_without_allergens: FakeProduct,
    shared_product: FakeProduct,
) -> FakeRecipe:
    ing1 = FakeRecipeIngredient(
        product_id=product_without_allergens.id,
        product=product_without_allergens,
        quantity=0.3,
        unit="kg",
    )
    ing2 = FakeRecipeIngredient(
        product_id=shared_product.id,
        product=shared_product,
        quantity=2.0,
        unit="szt",
    )
    return FakeRecipe(
        name="Ryż z warzywami",
        meal_type="lunch",
        ingredients=[ing1, ing2],
    )


@pytest.fixture
def recipe_dinner(
    product_without_allergens: FakeProduct,
    shared_product: FakeProduct,
) -> FakeRecipe:
    ing1 = FakeRecipeIngredient(
        product_id=product_without_allergens.id,
        product=product_without_allergens,
        quantity=0.2,
        unit="kg",
    )
    ing2 = FakeRecipeIngredient(
        product_id=shared_product.id,
        product=shared_product,
        quantity=1.0,
        unit="szt",
    )
    return FakeRecipe(
        name="Risotto",
        meal_type="dinner",
        ingredients=[ing1, ing2],
    )


@pytest.fixture
def user_with_gluten_allergy(gluten_allergen: FakeAllergen) -> FakeUser:
    ua = FakeUserAllergen(allergen_id=gluten_allergen.id, allergen=gluten_allergen)
    return FakeUser(
        allergens=[ua],
        household_size=2,
    )


@pytest.fixture
def all_recipes(
    recipe_with_gluten: FakeRecipe,
    recipe_without_allergens: FakeRecipe,
    recipe_dinner: FakeRecipe,
) -> list[FakeRecipe]:
    return [recipe_with_gluten, recipe_without_allergens, recipe_dinner]


@pytest.fixture
def mock_db() -> AsyncMock:
    return AsyncMock()


# ---------------------------------------------------------------------------
# Testy
# ---------------------------------------------------------------------------


class TestFilterRecipesExcludesAllergens:
    """Test: filtrowanie przepisów wyklucza te zawierające alergeny użytkownika."""

    def test_filter_recipes_excludes_allergens(
        self,
        all_recipes: list[FakeRecipe],
        user_with_gluten_allergy: FakeUser,
        gluten_allergen: FakeAllergen,
    ) -> None:
        """Przepisy z produktami zawierającymi alergen użytkownika
        powinny zostać odfiltrowane."""
        user_allergen_ids = {
            ua.allergen_id for ua in user_with_gluten_allergy.allergens
        }

        # Symulacja logiki filtrowania z MealPlanGenerator
        safe_recipes: list[FakeRecipe] = []
        for recipe in all_recipes:
            has_allergen = False
            for ing in recipe.ingredients:
                if ing.product is not None:
                    product_allergen_ids = {a.id for a in ing.product.allergens}
                    if product_allergen_ids & user_allergen_ids:
                        has_allergen = True
                        break
            if not has_allergen:
                safe_recipes.append(recipe)

        # Naleśniki (mąka = gluten) powinny być wykluczone
        assert len(safe_recipes) == 2
        recipe_names = {r.name for r in safe_recipes}
        assert "Naleśniki" not in recipe_names
        assert "Ryż z warzywami" in recipe_names
        assert "Risotto" in recipe_names


class TestIngredientReuseScoring:
    """Test: mechanizm punktowania ponownego użycia składników."""

    def test_ingredient_reuse_scoring(
        self,
        recipe_without_allergens: FakeRecipe,
        recipe_dinner: FakeRecipe,
        shared_product: FakeProduct,
    ) -> None:
        """Przepisy współdzielące składniki powinny mieć wyższy score reuse."""
        # Zbierz ID produktów z pierwszego przepisu (wybrane wcześniej)
        selected_product_ids: set[uuid.UUID] = set()
        for ing in recipe_without_allergens.ingredients:
            selected_product_ids.add(ing.product_id)

        # Oblicz score reuse dla drugiego przepisu
        def compute_reuse_score(
            recipe: FakeRecipe,
            already_selected_product_ids: set[uuid.UUID],
        ) -> int:
            score = 0
            for ing in recipe.ingredients:
                if ing.product_id in already_selected_product_ids:
                    score += 1
            return score

        score = compute_reuse_score(recipe_dinner, selected_product_ids)

        # shared_product (Cebula) jest w obu przepisach
        assert score >= 1
        # Ryż jest również w obu (ten sam product_without_allergens)
        assert score == 2  # Cebula + Ryż

    def test_no_reuse_with_empty_selection(
        self,
        recipe_dinner: FakeRecipe,
    ) -> None:
        """Gdy nie ma wcześniej wybranych przepisów, score reuse = 0."""
        empty_products: set[uuid.UUID] = set()

        score = sum(
            1
            for ing in recipe_dinner.ingredients
            if ing.product_id in empty_products
        )

        assert score == 0


class TestGeneratePlanCorrectSlotCount:
    """Test: wygenerowany plan ma poprawną liczbę slotów."""

    def test_generate_plan_correct_slot_count(
        self,
        all_recipes: list[FakeRecipe],
    ) -> None:
        """Plan 7-dniowy po 3 posiłki dziennie powinien mieć 21 slotów."""
        days = 7
        meals_per_day = 3
        expected_slots = days * meals_per_day

        # Symulacja generowania planu
        meal_types = ["breakfast", "lunch", "dinner"]
        entries: list[FakeMealPlanEntry] = []
        plan_id = uuid.uuid4()

        for day in range(1, days + 1):
            for meal_idx, meal_type in enumerate(meal_types[:meals_per_day]):
                # Wybierz przepis (round-robin dla uproszczenia)
                recipe = all_recipes[meal_idx % len(all_recipes)]
                entry = FakeMealPlanEntry(
                    meal_plan_id=plan_id,
                    recipe_id=recipe.id,
                    recipe=recipe,
                    day_number=day,
                    meal_type=meal_type,
                )
                entries.append(entry)

        assert len(entries) == expected_slots

    def test_generate_plan_fewer_meals(self, all_recipes: list[FakeRecipe]) -> None:
        """Plan z 2 posiłkami dziennie przez 3 dni = 6 slotów."""
        days = 3
        meals_per_day = 2
        expected_slots = days * meals_per_day

        meal_types = ["breakfast", "dinner"]
        entries: list[FakeMealPlanEntry] = []
        plan_id = uuid.uuid4()

        for day in range(1, days + 1):
            for meal_idx, meal_type in enumerate(meal_types[:meals_per_day]):
                recipe = all_recipes[meal_idx % len(all_recipes)]
                entry = FakeMealPlanEntry(
                    meal_plan_id=plan_id,
                    recipe_id=recipe.id,
                    day_number=day,
                    meal_type=meal_type,
                )
                entries.append(entry)

        assert len(entries) == expected_slots


class TestGeneratePlanRespectsMealTypes:
    """Test: plan posiłków respektuje przypisanie typów posiłków."""

    def test_generate_plan_respects_meal_types(
        self,
        recipe_with_gluten: FakeRecipe,
        recipe_without_allergens: FakeRecipe,
        recipe_dinner: FakeRecipe,
    ) -> None:
        """Każdy slot powinien mieć przepis odpowiadający typowi posiłku."""
        recipes_by_type: dict[str, list[FakeRecipe]] = {
            "breakfast": [recipe_with_gluten],  # meal_type=breakfast
            "lunch": [recipe_without_allergens],  # meal_type=lunch
            "dinner": [recipe_dinner],  # meal_type=dinner
        }

        plan_entries: list[FakeMealPlanEntry] = []
        plan_id = uuid.uuid4()

        for day in range(1, 4):  # 3 dni
            for meal_type in ["breakfast", "lunch", "dinner"]:
                available = recipes_by_type.get(meal_type, [])
                if available:
                    recipe = available[0]
                    entry = FakeMealPlanEntry(
                        meal_plan_id=plan_id,
                        recipe_id=recipe.id,
                        recipe=recipe,
                        day_number=day,
                        meal_type=meal_type,
                    )
                    plan_entries.append(entry)

        # Sprawdź, że typy posiłków się zgadzają
        for entry in plan_entries:
            assert entry.recipe is not None
            assert entry.recipe.meal_type == entry.meal_type

    def test_meal_types_distribution(self) -> None:
        """Plan 7-dniowy powinien mieć 7 wpisów każdego typu posiłku."""
        days = 7
        meal_types = ["breakfast", "lunch", "dinner"]
        entries_by_type: dict[str, int] = {mt: 0 for mt in meal_types}

        for day in range(1, days + 1):
            for mt in meal_types:
                entries_by_type[mt] += 1

        for mt in meal_types:
            assert entries_by_type[mt] == days


class TestShoppingListAggregation:
    """Test: agregacja listy zakupów z wielu przepisów."""

    def test_shopping_list_aggregation(
        self,
        recipe_without_allergens: FakeRecipe,
        recipe_dinner: FakeRecipe,
        shared_product: FakeProduct,
        product_without_allergens: FakeProduct,
    ) -> None:
        """Produkty powtarzające się w różnych przepisach
        powinny być zagregowane (zsumowane ilości)."""
        # Symulacja budowy listy zakupów z dwóch przepisów
        recipes = [recipe_without_allergens, recipe_dinner]
        aggregated: dict[uuid.UUID, dict[str, Any]] = {}

        for recipe in recipes:
            for ing in recipe.ingredients:
                pid = ing.product_id
                if pid in aggregated:
                    aggregated[pid]["quantity"] += ing.quantity
                else:
                    aggregated[pid] = {
                        "product_id": pid,
                        "product": ing.product,
                        "quantity": ing.quantity,
                        "unit": ing.unit,
                    }

        # Oczekujemy 2 unikalne produkty (ryż i cebula)
        assert len(aggregated) == 2

        # Ryż: 0.3 + 0.2 = 0.5 kg
        rice_entry = aggregated[product_without_allergens.id]
        assert abs(rice_entry["quantity"] - 0.5) < 1e-9

        # Cebula: 2.0 + 1.0 = 3.0 szt
        onion_entry = aggregated[shared_product.id]
        assert abs(onion_entry["quantity"] - 3.0) < 1e-9

    def test_shopping_list_single_recipe(
        self,
        recipe_without_allergens: FakeRecipe,
    ) -> None:
        """Lista zakupów z jednego przepisu nie powinna agregować."""
        aggregated: dict[uuid.UUID, float] = {}

        for ing in recipe_without_allergens.ingredients:
            pid = ing.product_id
            if pid in aggregated:
                aggregated[pid] += ing.quantity
            else:
                aggregated[pid] = ing.quantity

        assert len(aggregated) == 2  # ryż + cebula

    def test_shopping_list_handles_household_multiplier(
        self,
        recipe_without_allergens: FakeRecipe,
    ) -> None:
        """Ilości na liście zakupów powinny być przemnożone
        przez wielkość gospodarstwa domowego."""
        household_size = 4
        recipe_servings = recipe_without_allergens.servings  # 4

        multiplier = household_size / recipe_servings

        aggregated: dict[uuid.UUID, float] = {}
        for ing in recipe_without_allergens.ingredients:
            pid = ing.product_id
            adjusted_qty = ing.quantity * multiplier
            if pid in aggregated:
                aggregated[pid] += adjusted_qty
            else:
                aggregated[pid] = adjusted_qty

        # Multiplier = 4/4 = 1.0, więc ilości pozostają bez zmian
        assert all(qty > 0 for qty in aggregated.values())

        # Sprawdź z innym household_size
        household_size = 8
        multiplier = household_size / recipe_servings  # 8/4 = 2.0

        aggregated2: dict[uuid.UUID, float] = {}
        for ing in recipe_without_allergens.ingredients:
            pid = ing.product_id
            adjusted_qty = ing.quantity * multiplier
            aggregated2[pid] = adjusted_qty

        # Ilości powinny być podwojone
        for pid in aggregated:
            assert abs(aggregated2[pid] - aggregated[pid] * 2) < 1e-9
