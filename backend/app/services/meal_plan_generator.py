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

# UWAGA (naprawa POWAŻNEGO błędu): interfejs (ekran onboardingu) zapisuje
# dietę jako spolszczoną nazwę z wielkiej litery w formie rzeczownikowej
# ("Wegetariańska", "Bezglutenowa", "Keto"...), ale tagi faktycznie
# przypisane przepisom w bazie (app/db/seed.py) są małymi literami w
# formie przymiotnikowej mnogiej ("wegetariańskie", "bezglutenowe"...).
# Dokładne porównanie stringów (Recipe.tag == diet) NIGDY się nie
# zgadzało — filtr diety był FAKTYCZNIE MARTWY dla każdej opcji poza
# "Bez ograniczeń": albo generator rzucał błąd "za mało przepisów"
# (gdy diета trafiała bezpośrednio do zapytania), albo — jeśli diety
# w ogóle nie przekazywano (patrz naprawa we frontendzie) — ograniczenie
# było całkowicie ignorowane, więc np. osoba na diecie ketogenicznej
# mogła dostać w planie pizzę.
_DIET_NAME_TO_TAG: dict[str, str] = {
    "Wegetariańska": "wegetariańskie",
    "Wegańska": "wegańskie",
    "Bezglutenowa": "bezglutenowe",
    "Wysokobiałkowa": "wysokobiałkowe",
    "Keto": "keto",
}
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
# UWAGA (druga tura naprawy): nawet po podniesieniu NUTRITION do 0.45,
# testy na dłuższych planach (7 dni) pokazały systematyczne POGARSZANIE
# się dopasowania kalorycznego pod koniec tygodnia (dzień 7 potrafił
# wypaść nawet 55%+ poniżej celu) — presja na ponowne wykorzystanie
# składników narasta z każdym kolejnym dniem (więcej "już użytych"
# składników do dopasowania) i systematycznie przebijała dopasowanie
# kaloryczne. Odżywienie musi być ZDECYDOWANIE dominującym czynnikiem —
# to podstawowa, oczekiwana funkcja aplikacji; oszczędność na zakupach
# to wciąż wartościowy, ale wyraźnie drugorzędny cel.
WEIGHT_REUSE: float = 0.30
WEIGHT_VARIETY: float = 0.25
WEIGHT_NUTRITION: float = 0.45

# Maksymalna liczba powtórzeń tego samego przepisu — 14 było w praktyce
# "brakiem limitu" (np. dla planu 7-dniowego to 2/3 wszystkich posiłków
# mogłoby być tym samym przepisem). Niższa wartość, w połączeniu z
# rosnącą karą za powtórzenia (patrz variety_score), wymusza realną
# różnorodność zamiast pozwalać jednemu przepisu dominować plan.
MAX_RECIPE_REPEATS: int = 4

# Próg tolerancji dopełniania dnia dodatkowymi daniami — jeśli suma
# kalorii na osobę w danym dniu wypada poniżej tego procentu celu
# (target_kcal), dokładamy dodatkowe dania (patrz _top_up_low_calorie_days).
CALORIE_TOP_UP_THRESHOLD: float = 0.85
# Maksymalna liczba DODATKOWYCH dań dokładanych do jednego dnia — żeby
# przy bardzo niskokalorycznym katalogu przepisów nie skończyć z absurdalną
# liczbą "dosypanych" przekąsek zamiast po prostu zbliżenia się do celu.
# UWAGA (naprawa): 4 było w praktyce za mało, żeby domknąć realną lukę
# kaloryczną w niektórych dniach (plan kończył się wyraźnie poniżej progu
# 85% celu, mimo wyczerpania limitu dopełniania, a NIE wyczerpania puli
# przepisów). 8 daje realny margines na domknięcie nawet większej luki.
MAX_TOP_UP_DISHES_PER_DAY: int = 8


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
        household_size: int | None = None,
        target_kcal: float | None = None,
    ) -> MealPlan:
        """Generuje kompletny plan posiłków.

        Args:
            user_id: identyfikator użytkownika.
            store_id: identyfikator sklepu (do weryfikacji dostępności).
            duration_days: ile dni obejmuje plan.
            meals_per_day: ile posiłków dziennie (1-5).
            max_budget: opcjonalny budżet w PLN.
            preferences: opcjonalne preferencje (np. ``{'diet': 'vegetarian'}``).
            household_size: dla ilu osób gotować w TYM planie — nadpisuje
                (tylko na potrzeby tego planu, bez trwałej zmiany profilu)
                domyślną wartość z profilu użytkownika.
            target_kcal: docelowa dzienna kaloryczność na osobę. Wcześniej
                to pole było wysyłane przez aplikację, ale backend w ogóle
                go nie przyjmował (Pydantic po cichu je odrzucał) — algorytm
                zawsze dobierał przepisy pod sztywne, domyślne 2000 kcal,
                niezależnie od tego, co użytkownik ustawił w formularzu.

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
            target_kcal=target_kcal,
        )

        # Krok 4 — macierz dzień × slot
        entries_data = self._assign_to_slots(
            selected=selected,
            slot_distribution=slot_distribution,
            user=user,
            household_size=household_size,
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
        shopping_list = await builder.build_from_meal_plan(meal_plan.id)

        # Zsumuj koszt listy zakupów i zapisz jako szacowany minimalny
        # budżet planu — wcześniej to pole istniało w API (zawsze null),
        # ale nigdy nie było faktycznie liczone.
        from app.models import ShoppingListItem
        from sqlalchemy import func

        total_result = await self.db.execute(
            select(func.coalesce(func.sum(ShoppingListItem.estimated_price), 0)).where(
                ShoppingListItem.shopping_list_id == shopping_list.id
            )
        )
        meal_plan.estimated_min_budget = total_result.scalar_one()
        await self.db.commit()

        # Obiekt meal_plan wygasł po commicie z ShoppingListBuilder, trzeba przeładować
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

        # Filtr po tagu dietetycznym — mapujemy nazwę z interfejsu na
        # rzeczywisty tag w bazie (patrz komentarz przy _DIET_NAME_TO_TAG
        # na górze pliku). Nierozpoznana wartość diety NIE powinna po
        # cichu zostać zignorowana (to dokładnie ten błąd, który
        # naprawiamy) — logujemy ostrzeżenie, żeby było widać w logach,
        # gdyby interfejs kiedyś zaczął wysyłać nieznaną wartość.
        if diet:
            tag = _DIET_NAME_TO_TAG.get(diet)
            if tag is None:
                logger.warning("Nieznana wartość diety '%s' — filtr diety pominięty.", diet)
            else:
                stmt = stmt.where(
                    Recipe.id.in_(
                        select(RecipeTag.recipe_id).where(RecipeTag.tag == tag)
                    )
                )

        # UWAGA (naprawa poważnego błędu): brak jawnego sortowania w tym
        # zapytaniu oznaczał, że PostgreSQL mógł zwracać przepisy w
        # dowolnej, niegwarantowanej kolejności (zależnej od fizycznego
        # układu danych na dysku, który różni się między np. świeżym
        # zresetowaniem bazy a normalną pracą) — a zachłanny algorytm
        # wyboru w _greedy_select przy remisach w punktacji bierze
        # PIERWSZEGO kandydata z kolejności iteracji. Efekt: te same
        # ustawienia (dieta, cel kaloryczny, liczba dni) mogły dawać
        # WYRAŹNIE różne plany w zależności od przypadkowej kolejności
        # zwróconej przez bazę, co utrudniało też debugowanie (wyniki nie
        # były powtarzalne między testami). Jawne sortowanie po ID
        # zapewnia w pełni deterministyczne, powtarzalne zachowanie.
        stmt = stmt.order_by(Recipe.id)

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
        target_kcal: float | None = None,
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

        # UWAGA (naprawa): potrzebne do oszacowania "sprawiedliwego udziału"
        # celu kalorycznego przy PIERWSZYM posiłku dnia — patrz komentarz
        # przy nutrition_score w _score_candidate.
        slots_per_day: dict[int, int] = defaultdict(int)
        for day, _meal_type in slot_distribution:
            slots_per_day[day] += 1

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
                    target_kcal=target_kcal,
                    meals_today=slots_per_day.get(day, 1),
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
                        target_kcal=target_kcal,
                        meals_today=slots_per_day.get(day, 1),
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

        if target_kcal:
            selected = self._top_up_low_calorie_days(
                selected=selected,
                pools=pools,
                used_ingredient_ids=used_ingredient_ids,
                recipe_usage_count=recipe_usage_count,
                target_kcal=target_kcal,
            )

        logger.info(
            "Wybrano %d przepisów, unikalne składniki: %d",
            len(selected),
            len(used_ingredient_ids),
        )
        return selected

    def _top_up_low_calorie_days(
        self,
        selected: list[tuple[int, str, Recipe]],
        pools: dict[str, list[Recipe]],
        used_ingredient_ids: set[UUID],
        recipe_usage_count: dict[UUID, int],
        target_kcal: float,
    ) -> list[tuple[int, str, Recipe]]:
        """Dokłada dodatkowe dania do dni, w których suma kalorii NA OSOBĘ
        wypada wyraźnie poniżej celu (target_kcal).

        Dlaczego to w ogóle jest potrzebne: przy niewielkiej liczbie
        posiłków dziennie (np. 2) albo katalogu złożonym z niskokalorycznych
        przepisów, samo dobieranie "najlepiej pasujących" dań może nie
        wystarczyć, żeby zbliżyć się do celu — np. użytkownik ustawia
        2000 kcal, a dostaje plan na 600 kcal dziennie, bo tyle wychodzi
        z dostępnych 2 posiłków. Zamiast zostawić taki wynik, dokładamy
        dodatkowe dania (preferując przekąski) aż zbliżymy się do celu
        albo osiągniemy rozsądny limit dodatkowych dań na dzień.
        """
        by_day: dict[int, list[Recipe]] = defaultdict(list)
        for day, _meal_type, recipe in selected:
            by_day[day].append(recipe)

        # Pula kandydatów do dopełniania — najpierw przekąski (naturalny
        # wybór do "dobicia" kaloryczności bez robienia z tego kolejnego
        # pełnego dania), a jeśli ich brak, cokolwiek dostępne.
        top_up_pool = pools.get("przekąska") or [r for pool in pools.values() for r in pool]
        # UWAGA (naprawa): pula ZAPASOWA, używana TYLKO gdy sama pula
        # przekąsek wprawdzie istnieje, ale WSZYSTKIE jej pozycje trafiły
        # już w limit powtórzeń — wcześniej w takiej sytuacji dopełnianie
        # po prostu się poddawało (best_candidate=None), zostawiając dzień
        # wyraźnie poniżej celu, mimo że INNE kategorie dań wciąż miały
        # dostępne, nieużyte opcje.
        all_recipes_pool = [r for pool in pools.values() for r in pool]
        if not top_up_pool:
            return selected

        extra_entries: list[tuple[int, str, Recipe]] = []

        for day, day_recipes in by_day.items():
            added_count = 0
            while added_count < MAX_TOP_UP_DISHES_PER_DAY:
                current_total = self._sum_per_person_nutrition(day_recipes)
                if current_total["kcal"] >= target_kcal * CALORIE_TOP_UP_THRESHOLD:
                    break

                best_candidate: Recipe | None = None
                best_score = -1.0
                for candidate in top_up_pool:
                    if recipe_usage_count[candidate.id] >= MAX_RECIPE_REPEATS:
                        continue
                    score = self._score_candidate(
                        candidate=candidate,
                        used_ingredient_ids=used_ingredient_ids,
                        recipe_usage_count=recipe_usage_count,
                        daily_recipes=day_recipes,
                        target_kcal=target_kcal,
                    )
                    if score > best_score:
                        best_score = score
                        best_candidate = candidate

                if best_candidate is None and top_up_pool is not all_recipes_pool:
                    # Przekąski wyczerpane (limit powtórzeń) — spróbuj
                    # dopełnić DOWOLNYM dostępnym daniem z innej kategorii,
                    # zamiast od razu się poddawać.
                    for candidate in all_recipes_pool:
                        if recipe_usage_count[candidate.id] >= MAX_RECIPE_REPEATS:
                            continue
                        score = self._score_candidate(
                            candidate=candidate,
                            used_ingredient_ids=used_ingredient_ids,
                            recipe_usage_count=recipe_usage_count,
                            daily_recipes=day_recipes,
                            target_kcal=target_kcal,
                        )
                        if score > best_score:
                            best_score = score
                            best_candidate = candidate

                if best_candidate is None:
                    # Naprawdę wyczerpaliśmy wszystkie sensowne opcje (limit
                    # powtórzeń wszędzie) — nie ma sensu kręcić się w kółko,
                    # kończymy dopełnianie tego dnia.
                    break

                # UWAGA (naprawa): etykieta slotu musi odpowiadać
                # RZECZYWISTEMU typowi posiłku kandydata — wcześniej było to
                # na sztywno "przekąska", co dawało błędną etykietę, gdy
                # dopełnienie sięgało po danie z innej kategorii.
                extra_entries.append((day, best_candidate.meal_type or "przekąska", best_candidate))
                day_recipes.append(best_candidate)
                recipe_usage_count[best_candidate.id] += 1
                for ing in best_candidate.ingredients:
                    used_ingredient_ids.add(ing.product_id)
                added_count += 1

        if extra_entries:
            logger.info("Dopełniono %d dni dodatkowymi daniami (łącznie +%d)", len(by_day), len(extra_entries))
        return selected + extra_entries

    def _per_person_nutrition(self, recipe: Recipe) -> dict[str, float]:
        """Wartości odżywcze CAŁEGO przepisu podzielone przez liczbę porcji
        — czyli to, co faktycznie zjada JEDNA osoba, niezależnie od tego,
        na ile osób akurat gotujemy (household_size wpływa tylko na to,
        ILE razy trzeba pomnożyć przepis, żeby starczyło dla wszystkich —
        nie zmienia tego, ile je pojedyncza osoba)."""
        total = self.nutrition.calculate_recipe_nutrition(recipe.ingredients)
        servings = float(recipe.servings or 1)
        return {k: v / servings for k, v in total.items()}

    def _sum_per_person_nutrition(self, recipes: list[Recipe]) -> dict[str, float]:
        """Suma wartości odżywczych NA OSOBĘ dla listy przepisów (np.
        wszystkich posiłków zaplanowanych na dany dzień)."""
        result = {"kcal": 0.0, "protein": 0.0, "fat": 0.0, "carbs": 0.0, "fiber": 0.0}
        for recipe in recipes:
            per_person = self._per_person_nutrition(recipe)
            for k in result:
                result[k] += per_person.get(k, 0.0)
        return result

    def _score_candidate(
        self,
        candidate: Recipe,
        used_ingredient_ids: set[UUID],
        recipe_usage_count: dict[UUID, int],
        daily_recipes: list[Recipe],
        ignore_repeat_limit: bool = False,
        target_kcal: float | None = None,
        meals_today: int = 1,
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
        # UWAGA (naprawa): wcześniej kara za powtórzenia "spłaszczała się"
        # na stałej wartości 0.2 po drugim użyciu — czyli 3., 5. i 14.
        # użycie tego samego przepisu miało DOKŁADNIE tak samo niską karę
        # jak drugie. Przy małej puli pasujących przepisów (np. tylko 2-3
        # przekąski pasujące do restrykcyjnej diety) prowadziło to do
        # sytuacji, gdzie jeden przepis (np. "Guacamole") wygrywał wielokrotnie
        # pod rząd, bo nic dodatkowo nie zniechęcało algorytmu do kolejnego
        # wyboru TEGO SAMEGO zwycięzcy zamiast przeplatania dostępnych opcji.
        # Formuła 1/(użycia+1) maleje w NIESKOŃCZONOŚĆ z każdym kolejnym
        # użyciem, więc im częściej coś było wybrane, tym mocniej jest
        # spychane w dół rankingu przy każdym kolejnym wyborze.
        usage = recipe_usage_count.get(candidate.id, 0)
        variety_score = 1.0 / (usage + 1)

        # -- nutrition_score --
        if daily_recipes:
            # UWAGA (naprawa): wcześniej liczono tu SUMĘ CAŁYCH przepisów
            # (np. przepis na 4 porcje wliczał się w całości), podczas gdy
            # realnie każda osoba je tylko SWOJĄ porcję — niezależnie od
            # household_size, to zawsze `nutrition_total / recipe.servings`
            # (patrz też naprawa servings_multiplier w _assign_to_slots).
            # Przez to dobór przepisów "celował" w kaloryczność, która
            # nigdy nie odpowiadała temu, co faktycznie ląduje na talerzu
            # jednej osoby — stąd plany typu "2000 kcal celu, a wychodzi
            # 600 kcal dziennie".
            current_daily = self._sum_per_person_nutrition(daily_recipes)
            candidate_nutrition = self._per_person_nutrition(candidate)
            projected_kcal = current_daily.get("kcal", 0.0) + candidate_nutrition.get("kcal", 0.0)

            if target_kcal:
                # UWAGA (naprawa POWAŻNEGO błędu): wcześniej ta ocena
                # liczyła odchylenie dla WSZYSTKICH pięciu makroskładników
                # (kcal, białko, tłuszcz, węglowodany, błonnik) i UŚREDNIAŁA
                # je — ale użytkownik ustawia tylko docelowe KCAL, więc
                # pozostałe cztery odchylenia liczyły się względem
                # GENERYCZNYCH wartości domyślnych, niemających nic
                # wspólnego z tym, czego użytkownik faktycznie chce. Nawet
                # OGROMNE przekroczenie kcal (np. 3x za dużo) rozmywało się
                # w uśrednieniu z czterema nieistotnymi odchyleniami, więc
                # cel kaloryczny był w praktyce prawie ignorowany. Teraz,
                # gdy podano konkretny cel kcal, oceniamy WYŁĄCZNIE
                # dopasowanie do kcal — nic go już nie rozmywa.
                deviation = abs(projected_kcal - target_kcal) / target_kcal
                nutrition_score = max(0.0, 1.0 - deviation)
            else:
                projected = {
                    k: current_daily.get(k, 0.0) + candidate_nutrition.get(k, 0.0)
                    for k in ("kcal", "protein", "fat", "carbs", "fiber")
                }
                nutrition_score = self.nutrition.check_nutrition_balance(projected)
        else:
            # UWAGA (naprawa POWAŻNEGO błędu): wcześniej PIERWSZY posiłek
            # każdego dnia (gdy daily_recipes jest jeszcze puste) dostawał
            # zawsze NEUTRALNĄ ocenę 0.5 dla KAŻDEGO kandydata, niezależnie
            # od jego kaloryczności — bo nie było z czym porównać "dotychczas
            # zjedzone". Efekt: pierwszy wybór dnia w ogóle nie kierował się
            # celem kalorycznym (tylko ponownym użyciem składników i
            # różnorodnością), a reszta dnia próbowała to później
            # skompensować — czasem się udawało, czasem nie, dając bardzo
            # niestabilne wyniki (raz plan wychodził 30% poniżej celu, raz
            # 15% powyżej, mimo identycznych ustawień). Zamiast neutralnej
            # oceny, szacujemy "sprawiedliwy udział" tego posiłku w
            # dziennym celu (target_kcal / liczba posiłków dziś) i oceniamy
            # względem NIEGO — więc nawet pierwszy wybór dnia świadomie
            # celuje w rozsądną kaloryczność zamiast być całkowicie losowy.
            if target_kcal and meals_today > 0:
                fair_share = target_kcal / meals_today
                candidate_kcal = self._per_person_nutrition(candidate).get("kcal", 0.0)
                deviation = abs(candidate_kcal - fair_share) / fair_share if fair_share else 0.0
                nutrition_score = max(0.0, 1.0 - deviation)
            else:
                nutrition_score = 0.5  # brak celu kalorycznego — neutralna ocena

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
        household_size: int | None = None,
    ) -> list[dict[str, Any]]:
        """Tworzy dane wpisów planu posiłków.

        Uwzględnia liczbę osób do przeliczenia porcji — domyślnie z profilu
        użytkownika (``user.household_size``), ale można ją nadpisać per
        plan przez parametr ``household_size`` (np. gdy ktoś tym razem
        gotuje na więcej osób niż zwykle). Celowo NIE modyfikujemy obiektu
        ``user`` — to jednorazowe ustawienie tylko dla tego planu, a nie
        trwała zmiana profilu.

        Returns:
            Lista słowników gotowych do utworzenia ``MealPlanEntry``.
        """
        effective_household_size = household_size or getattr(user, "household_size", 1) or 1
        entries: list[dict[str, Any]] = []

        for day, meal_type, recipe in selected:
            recipe_servings = float(recipe.servings or 1)
            servings_multiplier = round(effective_household_size / recipe_servings, 2)
            # UWAGA (naprawa): wcześniej był tu sztuczny dolny próg
            # `max(servings_multiplier, 1.0)`, który wymuszał ugotowanie
            # CO NAJMNIEJ całego przepisu — niezależnie od liczby osób.
            # Dla przepisu na 4 porcje i planu dla 1 osoby dawało to
            # absurd: zamiast policzyć 1/4 przepisu (0.25), kod i tak
            # kazał zrobić cały przepis (1.0), czyli 4x za dużo jedzenia
            # dla jednej osoby. Teraz mnożnik faktycznie skaluje się w dół.
            # Jedyne zabezpieczenie to nie zejście do zera/ujemnej wartości
            # (co i tak nie powinno się zdarzyć, bo obie wartości > 0).
            servings_multiplier = max(servings_multiplier, 0.1)

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
