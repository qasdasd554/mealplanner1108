"""Generator planów posiłków — główny algorytm Smart Meal Planner.

Implementuje zachłanny algorytm selekcji przepisów maksymalizujący
ponowne użycie składników, uwzględniając przy tym:
- alergeny użytkownika,
- preferencje dietetyczne,
- dostępność produktów w wybranym sklepie,
- zbilansowanie makroskładników,
- różnorodność posiłków,
- bezwzględny brak powtórzenia tego samego przepisu w jednym dniu.
"""

from __future__ import annotations

import logging
import math
import re
import unicodedata
from collections import defaultdict
from datetime import date, datetime
from typing import Any, Sequence
from uuid import UUID
from zoneinfo import ZoneInfo

from sqlalchemy import and_, or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import joinedload, selectinload

from app.models import (
    Allergen,
    MealPlan,
    MealPlanEntry,
    PantryItem,
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
    ServiceError,
    UserNotFoundError,
)
from app.services.nutrition_calculator import NutritionCalculator
from app.services.shopping_list_builder import ShoppingListBuilder
from app.services.store_market_access import get_store_in_account_market
from app.core.markets import account_country
from app.core.market_clock import market_today
from app.services.market_catalog import (
    recipe_market_availability,
    recipe_has_reviewed_uk_offers,
    reviewed_uk_offer_conditions,
    utc_market_date,
)
from app.models.regional_product_offer import RegionalProductOffer

logger = logging.getLogger(__name__)


def _shopping_list_budget_query(shopping_list_id: UUID, country_code: str):
    """A complete UK checkout estimate, or unknown; PL keeps its old sum."""
    from app.models import ShoppingListItem
    from sqlalchemy import case, func

    if country_code == "GB":
        missing = func.sum(case((and_(
            ShoppingListItem.is_from_pantry.is_(False),
            ShoppingListItem.estimated_price.is_(None),
        ), 1), else_=0))
        total_expression = case((or_(
            func.count(ShoppingListItem.id) == 0, missing > 0,
        ), None), else_=func.coalesce(func.sum(ShoppingListItem.estimated_price), 0))
    else:
        total_expression = func.coalesce(func.sum(ShoppingListItem.estimated_price), 0)
    return select(total_expression).where(
        ShoppingListItem.shopping_list_id == shopping_list_id
    )

# ── Typy posiłków i domyślna dystrybucja ────────────────────────────
MEAL_TYPES: list[str] = ["śniadanie", "obiad", "kolacja", "przekąska", "deser"]

# Dystrybucja posiłków wg ilości posiłków dziennie
MEAL_DISTRIBUTION: dict[int, list[str]] = {
    1: ["obiad"],
    2: ["śniadanie", "obiad"],
    3: ["śniadanie", "obiad", "kolacja"],
    4: ["śniadanie", "obiad", "kolacja", "przekąska"],
    5: ["śniadanie", "obiad", "kolacja", "przekąska", "deser"],
}


def _normalise_recipe_text(value: str) -> str:
    """Upraszcza polski tekst tak, aby odmiana wyrazu nie rozbijała rodzin dań."""
    # Litera „ł” nie rozkłada się w NFKD, więc trzeba obsłużyć ją jawnie.
    lowered = value.lower().replace("ł", "l")
    ascii_text = unicodedata.normalize("NFKD", lowered).encode("ascii", "ignore").decode()
    return re.sub(r"[^a-z0-9]+", " ", ascii_text).strip()


def _recipe_family_key(recipe: Recipe) -> str:
    """Zwraca rodzinę dania, np. obie sałatki z tuńczykiem mają ten sam klucz.

    Samo ID chroni tylko przed ponownym użyciem dokładnie tego samego rekordu.
    Tutaj łączymy rodzaj dania z głównym składnikiem, dzięki czemu drobna
    zmiana nazwy lub dodatku nie omija zasady różnorodności w ciągu dnia.
    """
    name = _normalise_recipe_text(getattr(recipe, "name", "") or "")

    dish_kinds = (
        ("salat", "salatka"),
        ("zup", "zupa"),
        ("makaron", "makaron"),
        ("spaghetti", "makaron"),
        ("penne", "makaron"),
        ("lasagn", "makaron"),
        ("owsiank", "owsianka"),
        ("omlet", "omlet"),
        ("jajeczn", "jajecznica"),
        ("nales", "nalesniki"),
        ("plac", "placki"),
        ("koktaj", "koktajl"),
        ("smooth", "koktajl"),
        ("kanap", "kanapka"),
        ("wrap", "wrap"),
        ("tortill", "wrap"),
        ("curry", "curry"),
        ("gulasz", "gulasz"),
        ("burger", "burger"),
        ("risotto", "risotto"),
        ("pudding", "pudding"),
        ("ciast", "ciasto"),
    )
    kind = next((label for stem, label in dish_kinds if stem in name), "")

    ingredient_texts: list[str] = []
    for ingredient in getattr(recipe, "ingredients", []) or []:
        product = getattr(ingredient, "product", None)
        product_name = getattr(product, "name", None) or getattr(ingredient, "product_name", None)
        if product_name:
            ingredient_texts.append(_normalise_recipe_text(str(product_name)))
    searchable = f"{name} {' '.join(ingredient_texts)}"

    main_ingredients = (
        ("tuncz", "tunczyk"),
        ("kurcz", "kurczak"),
        ("indyk", "indyk"),
        ("losos", "losos"),
        ("dorsz", "dorsz"),
        ("krewet", "krewetki"),
        ("wolow", "wolowina"),
        ("wieprz", "wieprzowina"),
        ("tofu", "tofu"),
        ("ciecierzyc", "ciecierzyca"),
        ("soczew", "soczewica"),
        ("fasol", "fasola"),
        ("jaj", "jajko"),
        ("twarog", "twarog"),
        ("banan", "banan"),
        ("jabl", "jablko"),
    )
    main = next((label for stem, label in main_ingredients if stem in searchable), "")

    if kind and main:
        return f"{kind}:{main}"
    if kind:
        significant = [
            token
            for token in name.split()
            if len(token) >= 4 and token not in {"oraz", "pestkami", "warzywami", "szybka"}
        ]
        return f"{kind}:{':'.join(significant[:2])}"
    if main:
        return f"danie:{main}"
    return f"nazwa:{name}"

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


def effective_household_size(user: User, requested: int | None = None) -> int:
    """Jawne żądanie podlega limitowi; stare ustawienie profilu jest bezpiecznie ograniczone."""
    if requested is not None:
        if isinstance(requested, bool) or not isinstance(requested, int) or not 1 <= requested <= 8:
            raise ServiceError("Plan można utworzyć dla 1–8 osób.")
        return requested
    stored = getattr(user, "household_size", 1) or 1
    try:
        return min(max(int(stored), 1), 8)
    except (TypeError, ValueError, OverflowError):
        return 1


def effective_target_kcal(user: User, requested: float | None = None) -> float:
    """Wybrany cel, następnie zapisany kalkulator, w końcu 2000 kcal na osobę."""
    if requested is not None:
        if not math.isfinite(requested) or not 800 <= requested <= 6000:
            raise ServiceError("Cel kaloryczny musi wynosić 800–6000 kcal na osobę.")
        return float(requested)
    stored = getattr(user, "daily_kcal_goal", None)
    if isinstance(stored, (int, float)) and math.isfinite(stored) and 800 <= stored <= 6000:
        return float(stored)
    return 2000.0


def active_ingredient_preferences(user: User) -> tuple[set[UUID], set[UUID]]:
    """Wygaśnięcie Premium wyłącza preferencje, lecz nie usuwa zapisanego wyboru."""
    from app.core.premium import is_premium_active

    if not hasattr(user, "role") or not is_premium_active(user):
        return set(), set()
    stored = getattr(user, "ingredient_preferences", None) or {}
    if not isinstance(stored, dict):
        return set(), set()

    def ids(key: str) -> set[UUID]:
        values = stored.get(key, [])
        if not isinstance(values, list):
            return set()
        result = set()
        for value in values[:50]:
            try:
                result.add(UUID(str(value)))
            except (ValueError, TypeError):
                continue
        return result

    disliked = ids("disliked_product_ids")
    return ids("liked_product_ids") - disliked, disliked


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
        include_pantry: bool = True,
        create_shopping_list: bool = True,
        start_date: date | None = None,
    ) -> MealPlan:
        """Generuje kompletny plan posiłków.

        Args:
            user_id: identyfikator użytkownika.
            store_id: identyfikator sklepu (do weryfikacji dostępności).
            duration_days: ile dni obejmuje plan.
            meals_per_day: ile posiłków dziennie (1-5).
            max_budget: opcjonalny budżet w walucie kraju konta (PLN/GBP).
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
        if await get_store_in_account_market(self.db, store_id, user) is None:
            raise StoreNotFoundError(store_id)
        household_size = effective_household_size(user, household_size)
        target_kcal = effective_target_kcal(user, target_kcal)
        liked_ids, disliked_ids = active_ingredient_preferences(user)
        preference_warnings: list[str] = []
        saved_diet = getattr(user, "dietary_preferences", None) or {}
        if "diet" not in preferences and isinstance(saved_diet, dict) and saved_diet.get("diet"):
            preferences = {**preferences, "diet": saved_diet["diet"]}

        # Krok 2 — przepisy kwalifikujące się
        eligible_recipes = await self._filter_eligible_recipes(
            allergen_ids=allergen_ids,
            store_id=store_id,
            diet=preferences.get("diet"),
            user_id=user_id,
            country_code=account_country(user),
        )
        pantry_product_ids = (
            await self._load_pantry_product_ids(user_id)
            if include_pantry
            else set()
        )

        # Krok 3 — zachłanna selekcja
        slot_distribution = self._build_slot_distribution(
            duration_days,
            meals_per_day,
            selected_meal_types=preferences.get("meal_types"),
        )
        selected = self._greedy_select(
            eligible_recipes=eligible_recipes,
            slot_distribution=slot_distribution,
            max_budget=max_budget,
            store_id=store_id,
            target_kcal=target_kcal,
            preferred_ingredient_ids=pantry_product_ids,
            liked_ingredient_ids=liked_ids,
            disliked_ingredient_ids=disliked_ids,
            preference_warnings=preference_warnings,
        )

        # Krok 4 — macierz dzień × slot
        entries_data = self._assign_to_slots(
            selected=selected,
            slot_distribution=slot_distribution,
            user=user,
            household_size=household_size,
        )

        # Sam plan nadal można utworzyć, gdy darmowy limit list w tym
        # tygodniu został wykorzystany. Blokada jest wspólna z tworzeniem
        # listy, więc równoległe żądanie nie ominie limitu.
        from app.services.shopping_list_quota import can_create_shopping_list
        can_create_list = create_shopping_list and await can_create_shopping_list(
            self.db, user=user
        )

        # Krok 5 — zapis do bazy
        meal_plan = await self._persist_plan(
            user_id=user_id,
            store_id=store_id,
            duration_days=duration_days,
            meals_per_day=meals_per_day,
            entries_data=entries_data,
            start_date=start_date or market_today(user),
        )
        meal_plan.preferences = {
            **preferences,
            "household_size": household_size,
            "target_kcal": target_kcal,
            "include_pantry": include_pantry,
            "preference_warnings": preference_warnings,
        }
        # Historia powstaje przed commitem buildera listy. Dzięki temu
        # plan, wpis limitu i lista są atomowe, a usunięcie planu nie
        # pozwala wygenerować drugiego w tym samym tygodniu.
        from app.services.meal_plan_quota import record_meal_plan_creation
        await record_meal_plan_creation(
            self.db, user=user, meal_plan_id=meal_plan.id,
        )

        # Krok 6 — automatyczna lista zakupów, tylko jeśli limit pozwala.
        if can_create_list:
            builder = ShoppingListBuilder(self.db)
            shopping_list = await builder.build_from_meal_plan(
                meal_plan.id,
                include_pantry=include_pantry,
            )

            total_result = await self.db.execute(
                _shopping_list_budget_query(shopping_list.id, account_country(user))
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
        meal_plan_reloaded.shopping_list_limit_reached = (
            create_shopping_list and not can_create_list
        )
        meal_plan_reloaded.preference_warnings = preference_warnings

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

    async def _load_pantry_product_ids(self, user_id: UUID) -> set[UUID]:
        """Zwraca produkty domowe używane do preferowania tańszych dań.

        Dokładne ilości rozlicza później budowniczy listy zakupów. Tutaj
        sama obecność produktu jest sygnałem, że przepis lepiej wykorzysta
        to, co użytkownik już ma.
        """
        result = await self.db.execute(
            select(PantryItem.product_id).where(PantryItem.user_id == user_id)
        )
        return {row[0] for row in result.all()}

    # ==================================================================
    # Krok 2 — filtracja przepisów
    # ==================================================================

    async def _filter_eligible_recipes(
        self,
        allergen_ids: set[UUID],
        store_id: UUID,
        diet: str | None = None,
        user_id: UUID | None = None,
        country_code: str = "PL",
    ) -> list[Recipe]:
        """Zwraca przepisy kwalifikujące się do planu.

        Kryteria:
        - przepis jest WIDOCZNY dla tego użytkownika,
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

        # An empty or unmapped ingredient list is not proof of UK availability.
        # Keep the historical Polish selection unchanged.
        as_of = utc_market_date() if country_code == "GB" else None
        if country_code == "GB":
            stmt = stmt.where(recipe_market_availability(country_code, store_id=store_id, as_of=as_of))

        # NAPRAWA NIESPÓJNOŚCI WIDOCZNOŚCI: katalog przepisów stosuje filtr
        # "oficjalny LUB własny LUB publiczny" (_visibility_filter
        # w app/api/v1/recipes.py), ale to zapytanie nie miało go wcale.
        # Generator mógł więc wstawić do planu CUDZY PRYWATNY przepis —
        # taki, którego użytkownik nie ma prawa nawet zobaczyć w katalogu,
        # a który przez alergeny i dostępność składników przechodził
        # pozostałe kryteria. Efekt: w planie pojawiała się pozycja
        # nieodnajdywalna w aplikacji, razem z jej składnikami na liście
        # zakupów.
        if user_id is not None:
            stmt = stmt.where(
                or_(
                    Recipe.created_by_user_id.is_(None),      # 81 oficjalnych
                    Recipe.created_by_user_id == user_id,     # własne
                    Recipe.visibility == "public",            # zatwierdzone przez admina
                )
            )

        # Nieznany filtr nie może po cichu zmienić planu w „bez ograniczeń”.
        # Akceptujemy etykiety oficjalnego klienta oraz starsze kanoniczne tagi.
        if diet is not None and not isinstance(diet, str):
            raise ServiceError("Wybierz poprawną dietę w ustawieniach planu.")
        normalized_diet = _normalise_recipe_text(diet.strip()) if diet else ""
        if normalized_diet not in {"", "bez ograniczen", "none", "brak", "no restrictions"}:
            diet_tags = {_normalise_recipe_text(name): tag for name, tag in _DIET_NAME_TO_TAG.items()}
            diet_tags.update({_normalise_recipe_text(tag): tag for tag in _DIET_NAME_TO_TAG.values()})
            aliases = {
                "vegetarian": "wegetariańskie", "vegan": "wegańskie",
                "gluten_free": "bezglutenowe", "high_protein": "wysokobiałkowe",
                "ketogenic": "keto",
            }
            diet_tags.update({_normalise_recipe_text(name): tag for name, tag in aliases.items()})
            tag = diet_tags.get(normalized_diet)
            if tag is None:
                raise ServiceError("Nieznana dieta. Wybierz ją ponownie w ustawieniach planu.")
            stmt = stmt.where(
                Recipe.id.in_(select(RecipeTag.recipe_id).where(RecipeTag.tag == tag))
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

        offers = []
        off_ids = set()
        if country_code == "GB":
            # Country-level OFF reports and reviewed retailer offers are
            # separate evidence. Neither creates a price for an unknown SKU.
            product_ids = {ingredient.product_id for recipe in all_recipes
                           for ingredient in recipe.ingredients if not ingredient.is_optional}
            if product_ids:
                offers = (await self.db.execute(select(RegionalProductOffer).where(
                    RegionalProductOffer.store_id == store_id,
                    RegionalProductOffer.product_id.in_(product_ids),
                    *reviewed_uk_offer_conditions(as_of=as_of),
                ))).scalars().all()
            from app.services.off_availability import off_available_product_ids
            off_ids = await off_available_product_ids(self.db, product_ids, as_of=as_of)
            available_product_ids = set()
        else:
            # Pobranie identyfikatorów produktów dostępnych w polskim sklepie.
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
            if country_code == "GB":
                available = recipe_has_reviewed_uk_offers(
                    recipe, offers, store_id=store_id, as_of=as_of, off_product_ids=off_ids,
                )
            else:
                available = self._recipe_ingredients_available(recipe, available_product_ids)
            if not available:
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
        selected_meal_types: list[str] | None = None,
    ) -> list[tuple[int, str]]:
        """Tworzy listę slotów (dzień, typ_posiłku) do wypełnienia.

        Returns:
            Lista krotek ``(day_number, meal_type)``.
        """
        requested: list[str] = []
        for meal_type in selected_meal_types or []:
            if meal_type in MEAL_TYPES and meal_type not in requested:
                requested.append(meal_type)

        if requested:
            daily_meals = requested[:meals_per_day]
            if len(daily_meals) < meals_per_day:
                for meal_type in MEAL_DISTRIBUTION.get(meals_per_day, MEAL_DISTRIBUTION[3]):
                    if meal_type not in daily_meals:
                        daily_meals.append(meal_type)
                    if len(daily_meals) == meals_per_day:
                        break
        else:
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
        preferred_ingredient_ids: set[UUID] | None = None,
        liked_ingredient_ids: set[UUID] | None = None,
        disliked_ingredient_ids: set[UUID] | None = None,
        preference_warnings: list[str] | None = None,
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

        # Składniki ze spiżarni dostają ten sam umiarkowany bonus co produkty
        # ponownie używane w kilku daniach. Wyłączenie spiżarni przekazuje
        # pusty zbiór, więc zachowanie pozostaje identyczne jak wcześniej.
        used_ingredient_ids: set[UUID] = set(preferred_ingredient_ids or set())
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

            # Twarda reguła dzienna: tego samego przepisu nie wolno wybrać
            # drugi raz w jednym dniu, również dla dwóch slotów „przekąska”.
            # Najpierw zachowujemy właściwy typ posiłku. Dopiero gdy jego
            # pula nie ma już unikalnego kandydata, szukamy w całym katalogu.
            daily_recipe_ids = {recipe.id for recipe in daily_recipes}
            daily_recipe_families = {_recipe_family_key(recipe) for recipe in daily_recipes}
            search_pools = [pool]
            if pool is not eligible_recipes:
                search_pools.append(eligible_recipes)

            best_recipe: Recipe | None = None
            for candidate_pool in search_pools:
                # Limit tygodniowych powtórzeń jest regułą miękką: można go
                # przekroczyć przy bardzo małej puli. Unikalność w danym dniu
                # pozostaje twarda i nie jest wyłączana w żadnej strategii.
                for ignore_repeat_limit in (False, True):
                    best_score = -1.0
                    candidate_for_strategy: Recipe | None = None
                    for candidate in candidate_pool:
                        if candidate.id in daily_recipe_ids:
                            continue
                        if _recipe_family_key(candidate) in daily_recipe_families:
                            continue
                        if (
                            not ignore_repeat_limit
                            and recipe_usage_count[candidate.id] >= MAX_RECIPE_REPEATS
                        ):
                            continue

                        score = self._score_candidate(
                            candidate=candidate,
                            used_ingredient_ids=used_ingredient_ids,
                            recipe_usage_count=recipe_usage_count,
                            daily_recipes=daily_recipes,
                            ignore_repeat_limit=ignore_repeat_limit,
                            target_kcal=target_kcal,
                            meals_today=slots_per_day.get(day, 1),
                        )
                        if score > best_score:
                            best_score = score
                            candidate_for_strategy = candidate

                    if candidate_for_strategy is not None:
                        best_recipe = candidate_for_strategy
                        break
                if best_recipe is not None:
                    break

            if best_recipe is None:
                # Liczba unikalnych przepisów jest mniejsza niż liczba
                # posiłków wymagana tego dnia. Nie zapisujemy wadliwego planu.
                available_unique = len(
                    {recipe.id for recipe in eligible_recipes} - daily_recipe_ids
                )
                raise InsufficientRecipesError(
                    meal_type=meal_type,
                    required=1,
                    available=available_unique,
                )

            # Zapamiętaj wybór
            selected.append((day, meal_type, best_recipe))
            recipe_usage_count[best_recipe.id] += 1
            for ing in best_recipe.ingredients:
                used_ingredient_ids.add(ing.product_id)
            daily_recipes.append(best_recipe)

        if liked_ingredient_ids or disliked_ingredient_ids:
            selected = self._apply_ingredient_preferences(
                selected, eligible_recipes,
                liked_ingredient_ids or set(), disliked_ingredient_ids or set(),
                preference_warnings if preference_warnings is not None else [],
                target_kcal=target_kcal,
            )
            recipe_usage_count = defaultdict(int)
            used_ingredient_ids = set(preferred_ingredient_ids or set())
            for _day, _slot, recipe in selected:
                recipe_usage_count[recipe.id] += 1
                used_ingredient_ids.update(ing.product_id for ing in recipe.ingredients)

        if target_kcal:
            selected = self._top_up_low_calorie_days(
                selected=selected,
                pools=pools,
                used_ingredient_ids=used_ingredient_ids,
                recipe_usage_count=recipe_usage_count,
                target_kcal=target_kcal,
                allowed_meal_types={meal_type for _day, meal_type in slot_distribution},
            )

        self._assert_unique_recipes_per_day(selected)

        logger.info(
            "Wybrano %d przepisów, unikalne składniki: %d",
            len(selected),
            len(used_ingredient_ids),
        )
        return selected

    def _apply_ingredient_preferences(
        self,
        selected: list[tuple[int, str, Recipe]],
        eligible_recipes: list[Recipe],
        liked_ids: set[UUID],
        disliked_ids: set[UUID],
        warnings: list[str],
        *,
        target_kcal: float | None = None,
    ) -> list[tuple[int, str, Recipe]]:
        """Uwzględnia upodobania w jednym daniu dziennie, bez obchodzenia filtrów.

        Źródłem kandydatów jest wyłącznie uprzednio odfiltrowany katalog:
        alergie, dieta, widoczność i sklep mają bezwarunkowe pierwszeństwo.
        Pozostałe dania nie są globalnie ograniczane przez „nie lubię”.
        """
        result = list(selected)
        ingredient_ids = {
            recipe.id: {ing.product_id for ing in recipe.ingredients}
            for recipe in eligible_recipes
        }

        def compatible(recipe: Recipe) -> bool:
            return not (ingredient_ids.get(recipe.id, set()) & disliked_ids)

        safe_candidates = [recipe for recipe in eligible_recipes if compatible(recipe)]
        liked_candidates = [
            recipe for recipe in safe_candidates
            if ingredient_ids.get(recipe.id, set()) & liked_ids
        ]
        days = sorted({day for day, _slot, _recipe in result})
        for day in days:
            indices = [index for index, entry in enumerate(result) if entry[0] == day]
            daily = [result[index][2] for index in indices]
            if any(
                compatible(recipe) and (not liked_ids or ingredient_ids.get(recipe.id, set()) & liked_ids)
                for recipe in daily
            ):
                continue

            # Lubiane składniki są preferowane, a nielubiane wykluczone
            # w wybranym daniu. Gdy lubianych nie da się użyć, pokazujemy
            # ostrzeżenie i próbujemy przynajmniej zachować wykluczenia.
            candidate_groups = [liked_candidates, safe_candidates] if liked_ids else [safe_candidates]
            replacement: tuple[int, Recipe] | None = None
            used_liked = False
            for group_number, candidates in enumerate(candidate_groups):
                best_score = -1.0
                for index in indices:
                    _day, slot, previous = result[index]
                    other_recipes = [result[other][2] for other in indices if other != index]
                    usage: dict[UUID, int] = defaultdict(int)
                    used_ids: set[UUID] = set()
                    for other_index, (_other_day, _other_slot, recipe) in enumerate(result):
                        if other_index == index:
                            continue
                        usage[recipe.id] += 1
                        used_ids.update(ingredient_ids.get(recipe.id, set()))
                    for candidate in candidates:
                        if (candidate.meal_type or "obiad") != slot:
                            continue
                        score = self._score_candidate(
                            candidate, used_ids, usage, other_recipes,
                            ignore_repeat_limit=True,
                            target_kcal=target_kcal,
                            meals_today=len(indices),
                        )
                        if score > best_score:
                            best_score = score
                            replacement = (index, candidate)
                if replacement is not None:
                    used_liked = bool(liked_ids and group_number == 0)
                    break
            if replacement is not None:
                index, candidate = replacement
                result[index] = (day, result[index][1], candidate)

            matches_exclusions = any(compatible(result[index][2]) for index in indices)
            if not matches_exclusions:
                warnings.append(
                    f"Dzień {day}: nie znaleziono dania bez nielubianych składników "
                    "zgodnego z dietą, alergiami i wybranymi posiłkami. Zmień preferencje lub plan."
                )
            elif liked_ids and not used_liked:
                warnings.append(
                    f"Dzień {day}: nie znaleziono pasującego dania z lubianymi składnikami. "
                    "Uwzględniliśmy wykluczenie nielubianych składników w jednym daniu."
                )
        return result

    def _top_up_low_calorie_days(
        self,
        selected: list[tuple[int, str, Recipe]],
        pools: dict[str, list[Recipe]],
        used_ingredient_ids: set[UUID],
        recipe_usage_count: dict[UUID, int],
        target_kcal: float,
        allowed_meal_types: set[str] | None = None,
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

        # Dopełnienie nie może po cichu dodawać kategorii, których użytkownik
        # nie wybrał. Najpierw preferujemy przekąskę, potem deser, a następnie
        # pozostałe dozwolone typy.
        allowed = allowed_meal_types or set(pools)
        all_recipes_pool = [
            recipe
            for meal_type, pool in pools.items()
            if meal_type in allowed
            for recipe in pool
        ]
        preferred_type = next(
            (meal_type for meal_type in ("przekąska", "deser") if meal_type in allowed),
            None,
        )
        top_up_pool = (
            pools.get(preferred_type, []) if preferred_type is not None else all_recipes_pool
        ) or all_recipes_pool
        # UWAGA (naprawa): pula ZAPASOWA, używana TYLKO gdy sama pula
        # przekąsek wprawdzie istnieje, ale WSZYSTKIE jej pozycje trafiły
        # już w limit powtórzeń — wcześniej w takiej sytuacji dopełnianie
        # po prostu się poddawało (best_candidate=None), zostawiając dzień
        # wyraźnie poniżej celu, mimo że INNE kategorie dań wciąż miały
        # dostępne, nieużyte opcje.
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
                daily_recipe_ids = {recipe.id for recipe in day_recipes}
                daily_recipe_families = {_recipe_family_key(recipe) for recipe in day_recipes}
                for candidate in top_up_pool:
                    if candidate.id in daily_recipe_ids:
                        continue
                    if _recipe_family_key(candidate) in daily_recipe_families:
                        continue
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
                        if candidate.id in daily_recipe_ids:
                            continue
                        if _recipe_family_key(candidate) in daily_recipe_families:
                            continue
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

    @staticmethod
    def _assert_unique_recipes_per_day(
        selected: list[tuple[int, str, Recipe]],
    ) -> None:
        """Nie pozwala zapisać planu z tym samym przepisem dwa razy dziennie."""
        recipe_ids_by_day: dict[int, set[UUID]] = defaultdict(set)
        recipe_families_by_day: dict[int, set[str]] = defaultdict(set)
        for day, _meal_type, recipe in selected:
            if recipe.id in recipe_ids_by_day[day]:
                raise RuntimeError(
                    f"Generator wybrał przepis {recipe.id} więcej niż raz w dniu {day}"
                )
            family = _recipe_family_key(recipe)
            if family in recipe_families_by_day[day]:
                raise RuntimeError(
                    f"Generator wybrał dwa warianty tej samej rodziny dań "
                    f"({family}) w dniu {day}"
                )
            recipe_ids_by_day[day].add(recipe.id)
            recipe_families_by_day[day].add(family)

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
        # To ograniczenie jest niezależne od globalnego limitu powtórzeń.
        # `ignore_repeat_limit` może poluzować różnorodność między dniami,
        # ale nigdy nie może dopuścić duplikatu w obrębie jednego dnia.
        if any(recipe.id == candidate.id for recipe in daily_recipes):
            return -1.0
        candidate_family = _recipe_family_key(candidate)
        if any(_recipe_family_key(recipe) == candidate_family for recipe in daily_recipes):
            return -1.0

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
        people = effective_household_size(user, household_size)
        entries: list[dict[str, Any]] = []

        for day, meal_type, recipe in selected:
            recipe_servings = float(recipe.servings or 1)
            servings_multiplier = round(people / recipe_servings, 2)
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
        start_date: date | None = None,
    ) -> MealPlan:
        """Tworzy MealPlan i MealPlanEntry w bazie."""
        from sqlalchemy import select
        from sqlalchemy.orm import selectinload
        from app.models import MealPlanEntry, Recipe, RecipeIngredient

        meal_plan = MealPlan(
            user_id=user_id,
            store_id=store_id,
            start_date=start_date or datetime.now(ZoneInfo("Europe/Warsaw")).date(),
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

        # Zapis planu i nowej listy zakupów musi być atomowy. Builder
        # listy zatwierdzi oba obiekty dopiero po sprawdzeniu limitu.
        await self.db.flush()

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
