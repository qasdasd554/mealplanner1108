"""Generator planów posiłków — główny algorytm Smart Meal Planner.

Implementuje zachłanny algorytm selekcji przepisów maksymalizujący
ponowne użycie składników, uwzględniając przy tym:
- alergeny użytkownika,
- preferencje dietetyczne,
- dostępność produktów w wybranym sklepie,
- zbilansowanie makroskładników,
- różnorodność posiłków.
"""

from __future__ import annotations

import logging
from collections import defaultdict
from typing import Any, Sequence
from uuid import UUID

from sqlalchemy import and_, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import joinedload, selectinload

from app.models import (
    Allergen,
    MealPlan,
    MealPlanEntry,
    Product,
    ProductAllergen,
    Recipe,
    RecipeIngredient,
    RecipeTag,
    StoreProduct,
    User,
    UserAllergen,
)
from app.services.exceptions import (
    InsufficientRecipesError,
    StoreNotFoundError,
    UserNotFoundError,
)
from app.services.nutrition_calculator import NutritionCalculator
from app.services.shopping_list_builder import ShoppingListBuilder

logger = logging.getLogger(__name__)

# ── Typy posiłków i domyślna dystrybucja ────────────────────────────
MEAL_TYPES: list[str] = ["śniadanie", "obiad", "kolacja", "przekąska"]

# Dystrybucja posiłków wg ilości posiłków dziennie
MEAL_DISTRIBUTION: dict[int, list[str]] = {
    1: ["obiad"],
    2: ["śniadanie", "obiad"],
    3: ["śniadanie", "obiad", "kolacja"],
    4: ["śniadanie", "obiad", "kolacja", "przekąska"],
    5: ["śniadanie", "obiad", "kolacja", "przekąska", "przekąska"],
}

# Wagi algorytmu scoringowego
WEIGHT_REUSE: float = 0.50
WEIGHT_VARIETY: float = 0.25
WEIGHT_NUTRITION: float = 0.25

# Maksymalna liczba powtórzeń tego samego przepisu
MAX_RECIPE_REPEATS: int = 14


class MealPlanGenerator:
    """Generuje zbilansowany plan posiłków z zachłannym reuse składników."""

    def __init__(self, db: AsyncSession) -> None:
        self.db = db
        self.nutrition = NutritionCalculator()

    # ==================================================================
    # Publiczny interfejs
    # ==================================================================

    async def generate(
        self,
        user_id: UUID,
        store_id: UUID,
        duration_days: int,
        meals_per_day: int,
        max_budget: float | None = None,
        preferences: dict[str, Any] | None = None,
    ) -> MealPlan:
        """Generuje kompletny plan posiłków.

        Args:
            user_id: identyfikator użytkownika.
            store_id: identyfikator sklepu (do weryfikacji dostępności).
            duration_days: ile dni obejmuje plan.
            meals_per_day: ile posiłków dziennie (1-5).
            max_budget: opcjonalny budżet w PLN.
            preferences: opcjonalne preferencje (np. ``{'diet': 'vegetarian'}``).

        Returns:
            Utworzony obiekt ``MealPlan`` ze statusem ``'draft'``.
        """
        preferences = preferences or {}
        meals_per_day = min(max(meals_per_day, 1), 5)

        # Krok 1 — profil użytkownika
        user, allergen_ids = await self._load_user_profile(user_id)

        # Krok 2 — przepisy kwalifikujące się
        eligible_recipes = await self._filter_eligible_recipes(
            allergen_ids=allergen_ids,
            store_id=store_id,
            diet=preferences.get("diet"),
        )

        # Krok 3 — zachłanna selekcja
        slot_distribution = self._build_slot_distribution(duration_days, meals_per_day)
        selected = self._greedy_select(
            eligible_recipes=eligible_recipes,
            slot_distribution=slot_distribution,
            max_budget=max_budget,
            store_id=store_id,
        )

        # Krok 4 — macierz dzień × slot
        entries_data = self._assign_to_slots(
            selected=selected,
            slot_distribution=slot_distribution,
            user=user,
        )

        # Krok 5 — zapis do bazy
        meal_plan = await self._persist_plan(
            user_id=user_id,
            store_id=store_id,
            duration_days=duration_days,
            meals_per_day=meals_per_day,
            entries_data=entries_data,
        )

        # Krok 6 — automatyczna lista zakupów
        builder = ShoppingListBuilder(self.db)
        await builder.build_from_meal_plan(meal_plan.id)

        # Obiekt meal_plan wygasł po commicie z ShoppingListBuilder, trzeba przeładować
        from sqlalchemy import select
        from sqlalchemy.orm import selectinload
        from app.models import MealPlan, MealPlanEntry, Recipe, RecipeIngredient

        result = await self.db.execute(
            select(MealPlan)
            .options(
                selectinload(MealPlan.entries)
                .selectinload(MealPlanEntry.recipe)
                .selectinload(Recipe.ingredients)
                .selectinload(RecipeIngredient.product)
            )
            .where(MealPlan.id == meal_plan.id)
        )
        meal_plan_reloaded = result.scalar_one()

        return meal_plan_reloaded

    # ==================================================================
    # Krok 1 — profil użytkownika
    # ==================================================================

    async def _load_user_profile(
        self,
        user_id: UUID,
    ) -> tuple[User, set[UUID]]:
        """Ładuje użytkownika z alergenami.

        Returns:
            Krotka (User, set identyfikatorów alergenów).
        """
        stmt = (
            select(User)
            .where(User.id == user_id)
            .options(selectinload(User.allergens))
        )
        result = await self.db.execute(stmt)
        user = result.scalar_one_or_none()
        if user is None:
            raise UserNotFoundError(user_id)

        allergen_ids: set[UUID] = set()
        for ua in user.allergens:
            # relacja UserAllergen → allergen_id lub bezpośrednio Allergen.id
            aid = getattr(ua, "allergen_id", None) or getattr(ua, "id", None)
            if aid is not None:
                allergen_ids.add(aid)

        logger.info(
            "Użytkownik %s: %d alergenów",
            user_id,
            len(allergen_ids),
        )
        return user, allergen_ids

    # ==================================================================
    # Krok 2 — filtracja przepisów
    # ==================================================================

    async def _filter_eligible_recipes(
        self,
        allergen_ids: set[UUID],
        store_id: UUID,
        diet: str | None = None,
    ) -> list[Recipe]:
        """Zwraca przepisy kwalifikujące się do planu.

        Kryteria:
        - przepis nie zawiera alergenów użytkownika,
        - wszystkie nieopcjonalne składniki są dostępne w sklepie,
        - opcjonalnie filtr po tagu dietetycznym.
        """
        # Bazowe zapytanie z eager-load składników i produktów
        stmt = (
            select(Recipe)
            .options(
                selectinload(Recipe.ingredients).joinedload(RecipeIngredient.product),
                selectinload(Recipe.tags),
            )
        )

        # Filtr po tagu dietetycznym
        if diet:
            stmt = stmt.where(
                Recipe.id.in_(
                    select(RecipeTag.recipe_id).where(RecipeTag.tag == diet)
                )
            )

        result = await self.db.execute(stmt)
        all_recipes: Sequence[Recipe] = result.scalars().unique().all()

        # Pobranie identyfikatorów produktów dostępnych w sklepie
        avail_stmt = select(StoreProduct.product_id).where(
            and_(
                StoreProduct.store_id == store_id,
                StoreProduct.is_available.is_(True),
                StoreProduct.withdrawn_at.is_(None),
            )
        )
        avail_result = await self.db.execute(avail_stmt)
        available_product_ids: set[UUID] = {row[0] for row in avail_result.all()}

        # Pobranie mapowania produkt → alergeny
        if allergen_ids:
            pa_stmt = select(ProductAllergen.product_id, ProductAllergen.allergen_id)
            pa_result = await self.db.execute(pa_stmt)
            product_allergens: dict[UUID, set[UUID]] = defaultdict(set)
            for pid, aid in pa_result.all():
                product_allergens[pid].add(aid)
        else:
            product_allergens = {}

        eligible: list[Recipe] = []
        for recipe in all_recipes:
            if self._recipe_has_allergen(recipe, allergen_ids, product_allergens):
                continue
            if not self._recipe_ingredients_available(recipe, available_product_ids):
                continue
            eligible.append(recipe)

        logger.info(
            "Znaleziono %d kwalifikujących się przepisów (z %d ogółem)",
            len(eligible),
            len(all_recipes),
        )
        return eligible

    @staticmethod
    def _recipe_has_allergen(
        recipe: Recipe,
        allergen_ids: set[UUID],
        product_allergens: dict[UUID, set[UUID]],
    ) -> bool:
        """Sprawdza, czy przepis zawiera alergeny użytkownika."""
        if not allergen_ids:
            return False
        for ing in recipe.ingredients:
            product_id = ing.product_id
            if product_id in product_allergens:
                if product_allergens[product_id] & allergen_ids:
                    return True
        return False

    @staticmethod
    def _recipe_ingredients_available(
        recipe: Recipe,
        available_product_ids: set[UUID],
    ) -> bool:
        """Sprawdza, czy wszystkie nieopcjonalne składniki są dostępne."""
        for ing in recipe.ingredients:
            is_optional = getattr(ing, "is_optional", False)
            if not is_optional and ing.product_id not in available_product_ids:
                return False
        return True

    # ==================================================================
    # Krok 3 — zachłanna selekcja
    # ==================================================================

    def _build_slot_distribution(
        self,
        duration_days: int,
        meals_per_day: int,
    ) -> list[tuple[int, str]]:
        """Tworzy listę slotów (dzień, typ_posiłku) do wypełnienia.

        Returns:
            Lista krotek ``(day_number, meal_type)``.
        """
        daily_meals = MEAL_DISTRIBUTION.get(meals_per_day, MEAL_DISTRIBUTION[3])
        slots: list[tuple[int, str]] = []
        for day in range(1, duration_days + 1):
            for meal_type in daily_meals:
                slots.append((day, meal_type))
        return slots

    def _greedy_select(
        self,
        eligible_recipes: list[Recipe],
        slot_distribution: list[tuple[int, str]],
        max_budget: float | None,
        store_id: UUID,
    ) -> list[tuple[int, str, Recipe]]:
        """Zachłanny algorytm selekcji przepisów z reuse składników.

        Dla każdego slotu wybiera przepis o najwyższym łącznym score,
        uwzględniającym ponowne użycie składników, różnorodność i odżywienie.

        Returns:
            Lista krotek ``(day, meal_type, recipe)``.
        """
        # Pule przepisów wg typu posiłku
        pools: dict[str, list[Recipe]] = defaultdict(list)
        for recipe in eligible_recipes:
            mt = getattr(recipe, "meal_type", None) or "obiad"
            pools[mt].append(recipe)
            # Przepisy bez przypisanego meal_type trafiają też jako fallback
            if mt not in MEAL_TYPES:
                pools["obiad"].append(recipe)

        used_ingredient_ids: set[UUID] = set()
        recipe_usage_count: dict[UUID, int] = defaultdict(int)
        selected: list[tuple[int, str, Recipe]] = []

        # Bieżące dzienne odżywianie (resetowane co dzień)
        current_day: int = 0
        daily_recipes: list[Recipe] = []

        for day, meal_type in slot_distribution:
            if day != current_day:
                current_day = day
                daily_recipes = []

            pool = pools.get(meal_type, [])
            # Fallback: jeśli pula pusta, próbujemy ze wszystkich
            if not pool:
                pool = eligible_recipes

            if not pool:
                raise InsufficientRecipesError(
                    meal_type=meal_type,
                    required=1,
                    available=0,
                )

            best_recipe: Recipe | None = None
            best_score: float = -1.0

            for candidate in pool:
                # Limit powtórzeń
                if recipe_usage_count[candidate.id] >= MAX_RECIPE_REPEATS:
                    continue

                score = self._score_candidate(
                    candidate=candidate,
                    used_ingredient_ids=used_ingredient_ids,
                    recipe_usage_count=recipe_usage_count,
                    daily_recipes=daily_recipes,
                )
                if score > best_score:
                    best_score = score
                    best_recipe = candidate

            if best_recipe is None:
                # Spróbuj z dopuszczeniem powtórzeń
                for candidate in pool:
                    score = self._score_candidate(
                        candidate=candidate,
                        used_ingredient_ids=used_ingredient_ids,
                        recipe_usage_count=recipe_usage_count,
                        daily_recipes=daily_recipes,
                        ignore_repeat_limit=True,
                    )
                    if score > best_score:
                        best_score = score
                        best_recipe = candidate

            if best_recipe is None:
                raise InsufficientRecipesError(
                    meal_type=meal_type,
                    required=1,
                    available=0,
                )

            # Zapamiętaj wybór
            selected.append((day, meal_type, best_recipe))
            recipe_usage_count[best_recipe.id] += 1
            for ing in best_recipe.ingredients:
                used_ingredient_ids.add(ing.product_id)
            daily_recipes.append(best_recipe)

        logger.info(
            "Wybrano %d przepisów, unikalne składniki: %d",
            len(selected),
            len(used_ingredient_ids),
        )
        return selected

    def _score_candidate(
        self,
        candidate: Recipe,
        used_ingredient_ids: set[UUID],
        recipe_usage_count: dict[UUID, int],
        daily_recipes: list[Recipe],
        ignore_repeat_limit: bool = False,
    ) -> float:
        """Oblicza łączny scoring kandydującego przepisu.

        Składowe:
        - reuse_score (0.0–1.0): procent składników już użytych wcześniej.
        - variety_score (0.0–1.0): kara za powtórzenia przepisu.
        - nutrition_score (0.0–1.0): zbilansowanie z dotychczasowymi posiłkami.
        """
        if not ignore_repeat_limit and recipe_usage_count[candidate.id] >= MAX_RECIPE_REPEATS:
            return -1.0

        # -- reuse_score --
        candidate_ingredient_ids = {ing.product_id for ing in candidate.ingredients}
        if candidate_ingredient_ids:
            overlap = candidate_ingredient_ids & used_ingredient_ids
            reuse_score = len(overlap) / len(candidate_ingredient_ids)
        else:
            reuse_score = 0.0

        # -- variety_score --
        usage = recipe_usage_count.get(candidate.id, 0)
        if usage == 0:
            variety_score = 1.0
        elif usage == 1:
            variety_score = 0.5
        else:
            variety_score = 0.2

        # -- nutrition_score --
        if daily_recipes:
            current_daily = self.nutrition.calculate_daily_nutrition(daily_recipes)
            # Symuluj dodanie tego przepisu
            candidate_nutrition = self.nutrition.calculate_recipe_nutrition(
                candidate.ingredients,
            )
            projected = {
                k: current_daily.get(k, 0.0) + candidate_nutrition.get(k, 0.0)
                for k in ("kcal", "protein", "fat", "carbs", "fiber")
            }
            nutrition_score = self.nutrition.check_nutrition_balance(projected)
        else:
            nutrition_score = 0.5  # brak kontekstu — neutralna ocena

        total = (
            WEIGHT_REUSE * reuse_score
            + WEIGHT_VARIETY * variety_score
            + WEIGHT_NUTRITION * nutrition_score
        )
        return total

    # ==================================================================
    # Krok 4 — przypisanie do slotów
    # ==================================================================

    @staticmethod
    def _assign_to_slots(
        selected: list[tuple[int, str, Recipe]],
        slot_distribution: list[tuple[int, str]],
        user: User,
    ) -> list[dict[str, Any]]:
        """Tworzy dane wpisów planu posiłków.

        Uwzględnia ``household_size`` użytkownika do przeliczenia porcji.

        Returns:
            Lista słowników gotowych do utworzenia ``MealPlanEntry``.
        """
        household_size = getattr(user, "household_size", 1) or 1
        entries: list[dict[str, Any]] = []

        for day, meal_type, recipe in selected:
            recipe_servings = float(recipe.servings or 1)
            servings_multiplier = round(household_size / recipe_servings, 2)
            # Minimalna mnożnik = 1.0 (nie zmniejszamy poniżej jednej porcji)
            servings_multiplier = max(servings_multiplier, 1.0)

            entries.append(
                {
                    "day_number": day,
                    "meal_slot": meal_type,
                    "recipe_id": recipe.id,
                    "servings_multiplier": servings_multiplier,
                }
            )
        return entries

    # ==================================================================
    # Krok 5 — zapis do bazy danych
    # ==================================================================

    async def _persist_plan(
        self,
        user_id: UUID,
        store_id: UUID,
        duration_days: int,
        meals_per_day: int,
        entries_data: list[dict[str, Any]],
    ) -> MealPlan:
        """Tworzy MealPlan i MealPlanEntry w bazie."""
        from datetime import date
        from sqlalchemy import select
        from sqlalchemy.orm import selectinload
        from app.models import MealPlanEntry, Recipe, RecipeIngredient
        
        meal_plan = MealPlan(
            user_id=user_id,
            store_id=store_id,
            start_date=date.today(),
            duration_days=duration_days,
            meals_per_day=meals_per_day,
            status="draft",
        )
        self.db.add(meal_plan)
        await self.db.flush()  # meal_plan.id dostępny

        for entry_data in entries_data:
            entry = MealPlanEntry(
                meal_plan_id=meal_plan.id,
                **entry_data,
            )
            self.db.add(entry)

        await self.db.commit()

        result = await self.db.execute(
            select(MealPlan)
            .options(
                selectinload(MealPlan.entries)
                .selectinload(MealPlanEntry.recipe)
                .selectinload(Recipe.ingredients)
                .selectinload(RecipeIngredient.product)
            )
            .where(MealPlan.id == meal_plan.id)
        )
        meal_plan_loaded = result.scalar_one()

        logger.info(
            "Utworzono plan posiłków %s (%d dni, %d wpisów)",
            meal_plan.id,
            duration_days,
            len(entries_data),
        )

        return meal_plan_loaded
