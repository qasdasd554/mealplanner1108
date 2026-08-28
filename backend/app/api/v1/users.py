"""Endpointy zarządzania profilem użytkownika."""

from datetime import datetime, timedelta, timezone
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, ConfigDict, Field, field_validator
from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.api.deps import get_current_admin, get_current_user
from app.db.session import get_db
from app.models import Allergen, Store, User, UserAllergen
from app.schemas.user import UserResponse

router = APIRouter()


class UserProfileUpdate(BaseModel):
    """Schemat aktualizacji profilu użytkownika."""

    model_config = ConfigDict(from_attributes=True)

    # UWAGA (naprawa bezpieczeństwa): wcześniej display_name i household_size
    # nie miały żadnych granic — dało się ustawić np. household_size=-999999
    # albo wyświetlaną nazwę o długości megabajtów. Kolumna w bazie i tak by
    # to odrzuciła (surowym błędem 500, nie czytelnym komunikatem), a
    # ekstremalne wartości household_size mogłyby psuć przeliczenia porcji
    # w generatorze planów posiłków.
    display_name: str | None = Field(default=None, max_length=200)
    preferred_store_id: UUID | None = None
    dietary_preferences: dict | None = None
    household_size: int | None = Field(default=None, ge=1, le=20)
    # Dane do kalkulatora zapotrzebowania kalorycznego (Śledzenie) —
    # granice dobrane szeroko, ale na tyle rozsądnie, żeby odciąć
    # oczywiście błędne wartości (patrz komentarz o household_size wyżej
    # — ten sam wzorzec zabezpieczenia).
    weight_kg: float | None = Field(default=None, gt=0, le=400)
    height_cm: float | None = Field(default=None, gt=0, le=280)
    age: int | None = Field(default=None, gt=0, le=130)
    gender: str | None = Field(default=None, max_length=10)
    activity_level: str | None = Field(default=None, max_length=20)
    daily_kcal_goal: int | None = Field(default=None, ge=800, le=6000)
    avatar: str | None = None

    @field_validator("avatar")
    @classmethod
    def validate_avatar(cls, v: str | None) -> str | None:
        allowed = {"male", "female"}
        if v is not None and v not in allowed:
            raise ValueError(f"Awatar musi być jednym z: {', '.join(allowed)}.")
        return v

    @field_validator("gender")
    @classmethod
    def validate_gender(cls, v: str | None) -> str | None:
        if v is not None and v not in ("male", "female"):
            raise ValueError("Płeć musi być 'male' albo 'female'.")
        return v

    @field_validator("activity_level")
    @classmethod
    def validate_activity_level(cls, v: str | None) -> str | None:
        allowed = {"sedentary", "light", "moderate", "active", "very_active"}
        if v is not None and v not in allowed:
            raise ValueError(f"Poziom aktywności musi być jednym z: {', '.join(allowed)}.")
        return v

    @field_validator("dietary_preferences")
    @classmethod
    def limit_dietary_preferences_size(cls, v: dict | None) -> dict | None:
        """Bez limitu dało się wysłać dowolnie duży, zagnieżdżony słownik
        JSON pod pozorem preferencji żywieniowych — kolumna w bazie nie
        ma ograniczenia rozmiaru. 10 KB to i tak wielokrotność tego, czego
        realnie potrzeba (kilka krótkich pól tekstowych)."""
        if v is None:
            return v
        import json

        size = len(json.dumps(v))
        if size > 10_000:
            raise ValueError("Preferencje żywieniowe są za duże (max 10 KB)")
        return v


class AllergenIdsUpdate(BaseModel):
    """Lista identyfikatorów alergenów do przypisania użytkownikowi."""

    model_config = ConfigDict(from_attributes=True)

    allergen_ids: list[str]


@router.get(
    "/me",
    response_model=UserResponse,
    summary="Pobierz profil bieżącego użytkownika",
)
async def get_me(
    current_user: User = Depends(get_current_user),
) -> User:
    """Zwraca profil zalogowanego użytkownika."""
    return current_user


@router.put(
    "/me",
    response_model=UserResponse,
    summary="Zaktualizuj profil użytkownika",
)
async def update_me(
    payload: UserProfileUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> User:
    """Aktualizuje pola profilu bieżącego użytkownika.

    Pomija pola o wartości ``None`` — aktualizowane są tylko jawnie przekazane wartości.
    """
    update_data = payload.model_dump(exclude_unset=True)

    # UWAGA (naprawa): wcześniej `preferred_store_id` nie było w ogóle
    # sprawdzane — nieistniejący sklep przechodził walidację Pydantic (to
    # tylko UUID), ale przy zapisie do bazy naruszał ograniczenie klucza
    # obcego, kończąc się nieobsłużonym błędem 500 zamiast czytelnej
    # odpowiedzi. Sprawdzamy istnienie PRZED próbą zapisu.
    if update_data.get("preferred_store_id") is not None:
        store = await db.get(Store, update_data["preferred_store_id"])
        if store is None:
            raise HTTPException(status_code=400, detail="Wskazany sklep nie istnieje")

    for field, value in update_data.items():
        setattr(current_user, field, value)

    db.add(current_user)
    await db.commit()
    await db.refresh(current_user)
    return current_user


class CalorieCalculatorRequest(BaseModel):
    """Dane wejściowe do kalkulatora zapotrzebowania kalorycznego —
    celowo NIEZALEŻNE od tego, co jest zapisane w profilu, żeby
    użytkownik mógł "poeksperymentować" z różnymi wartościami przed
    zdecydowaniem się i zapisaniem wyniku (PUT /users/me)."""

    weight_kg: float = Field(gt=0, le=400)
    height_cm: float = Field(gt=0, le=280)
    age: int = Field(gt=0, le=130)
    gender: str
    activity_level: str

    @field_validator("gender")
    @classmethod
    def validate_gender(cls, v: str) -> str:
        if v not in ("male", "female"):
            raise ValueError("Płeć musi być 'male' albo 'female'.")
        return v

    @field_validator("activity_level")
    @classmethod
    def validate_activity_level(cls, v: str) -> str:
        allowed = {"sedentary", "light", "moderate", "active", "very_active"}
        if v not in allowed:
            raise ValueError(f"Poziom aktywności musi być jednym z: {', '.join(allowed)}.")
        return v


class CalorieCalculatorResponse(BaseModel):
    maintenance: int
    weight_loss: int
    weight_gain: int


@router.post(
    "/me/calorie-calculator",
    response_model=CalorieCalculatorResponse,
    summary="Oblicz dzienne zapotrzebowanie kaloryczne (wzór Mifflin-St Jeor)",
)
async def calculate_calorie_needs_endpoint(
    payload: CalorieCalculatorRequest,
    current_user: User = Depends(get_current_user),
) -> dict:
    """Liczy zapotrzebowanie kaloryczne (utrzymanie / redukcja / przyrost
    masy ciała) na podstawie podanych danych — analogicznie do
    kalkulatora BMI/kalorii NFZ (diety.nfz.gov.pl). Wynik NIE jest
    automatycznie zapisywany — użytkownik wybiera jedną z trzech
    wartości (albo ustawia własną suwakiem) i zapisuje ją osobno przez
    PUT /users/me z polem daily_kcal_goal.
    """
    from app.services.nutrition_calculator import (
        InvalidCalorieCalculatorInput,
        calculate_calorie_needs,
    )

    try:
        return calculate_calorie_needs(
            weight_kg=payload.weight_kg,
            height_cm=payload.height_cm,
            age=payload.age,
            gender=payload.gender,
            activity_level=payload.activity_level,
        )
    except InvalidCalorieCalculatorInput as exc:
        raise HTTPException(status_code=400, detail=str(exc))


@router.put(
    "/me/allergens",
    response_model=UserResponse,
    summary="Zaktualizuj alergeny użytkownika",
)
async def update_my_allergens(
    payload: AllergenIdsUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> User:
    """Zastępuje listę alergenów użytkownika nowym zestawem.

    Operacja jest atomowa: usuwa wszystkie istniejące powiązania
    i tworzy nowe na podstawie przekazanej listy ``allergen_ids``.
    Akceptuje zarówno UUID jak i nazwy alergenów (np. 'gluten', 'laktoza').
    """
    # Usuń istniejące powiązania
    await db.execute(
        delete(UserAllergen).where(UserAllergen.user_id == current_user.id)
    )

    if payload.allergen_ids:
        # Sprawdź czy to UUIDs czy nazwy
        resolved_ids = []
        names_to_lookup = []
        for aid in payload.allergen_ids:
            try:
                resolved_ids.append(UUID(aid))
            except (ValueError, AttributeError):
                names_to_lookup.append(aid)

        # Wyszukaj alergeny po nazwie
        if names_to_lookup:
            result = await db.execute(
                select(Allergen).where(Allergen.name.in_(names_to_lookup))
            )
            found = result.scalars().all()
            resolved_ids.extend([a.id for a in found])

        # Zweryfikuj istnienie alergenów po UUID
        if resolved_ids:
            result = await db.execute(
                select(Allergen).where(Allergen.id.in_(resolved_ids))
            )
            existing_allergens = result.scalars().all()
            existing_ids = {a.id for a in existing_allergens}

            for allergen_id in resolved_ids:
                if allergen_id in existing_ids:
                    db.add(UserAllergen(user_id=current_user.id, allergen_id=allergen_id))

    await db.commit()

    # Odśwież użytkownika z relacjami
    result = await db.execute(
        select(User)
        .options(selectinload(User.allergens))
        .where(User.id == current_user.id)
    )
    user = result.scalar_one()
    return user


class RecipeLeaderboardEntry(BaseModel):
    """Pojedynczy wpis w rankingu — ile PUBLICZNYCH przepisów (widocznych
    dla wszystkich, zaakceptowanych przez administratora) dodał dany
    użytkownik. Celowo NIE liczymy przepisów prywatnych — to ranking
    wkładu we WSPÓLNY katalog, nie licznik "ile razy ktoś kliknął dodaj"."""

    model_config = ConfigDict(from_attributes=True)

    display_name: str
    recipe_count: int
    avatar: str | None = None


@router.get(
    "/leaderboard/recipes",
    response_model=list[RecipeLeaderboardEntry],
    summary="Ranking użytkowników wg liczby dodanych publicznych przepisów",
)
async def get_recipe_leaderboard(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> list[RecipeLeaderboardEntry]:
    """Zwraca ranking (top 50) użytkowników, którzy dodali najwięcej
    przepisów zaakceptowanych do wspólnego katalogu."""
    from app.models import Recipe
    from sqlalchemy import func

    result = await db.execute(
        select(
            User.display_name,
            func.count(Recipe.id).label("recipe_count"),
            User.avatar,
        )
        .join(Recipe, Recipe.created_by_user_id == User.id)
        .where(Recipe.visibility == "public")
        .group_by(User.id, User.display_name, User.avatar)
        .order_by(func.count(Recipe.id).desc())
        .limit(50)
    )
    return [
        RecipeLeaderboardEntry(display_name=name or "Użytkownik", recipe_count=count, avatar=avatar)
        for name, count, avatar in result.all()
    ]


@router.get(
    "/leaderboard/recipes/weekly",
    response_model=list[RecipeLeaderboardEntry],
    summary="Cotygodniowy konkurs — ranking wg przepisów dodanych w ostatnich 7 dniach",
)
async def get_weekly_recipe_leaderboard(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> list[RecipeLeaderboardEntry]:
    """Ta sama logika co ranking ogólny, ale liczy TYLKO przepisy
    dodane w ciągu ostatnich 7 dni — cotygodniowy konkurs, w którym
    każdy zaczyna "od zera" co tydzień, zamiast rankingu zdominowanego
    na stałe przez najwcześniejszych/najbardziej płodnych autorów."""
    from app.models import Recipe
    from sqlalchemy import func

    week_ago = datetime.now(timezone.utc) - timedelta(days=7)

    result = await db.execute(
        select(
            User.display_name,
            func.count(Recipe.id).label("recipe_count"),
            User.avatar,
        )
        .join(Recipe, Recipe.created_by_user_id == User.id)
        .where(Recipe.visibility == "public", Recipe.created_at >= week_ago)
        .group_by(User.id, User.display_name, User.avatar)
        .order_by(func.count(Recipe.id).desc())
        .limit(50)
    )
    return [
        RecipeLeaderboardEntry(display_name=name or "Użytkownik", recipe_count=count, avatar=avatar)
        for name, count, avatar in result.all()
    ]


# ══════════════════════════════════════════════════════════════════
# ŚLEDZENIE AKTYWNOŚCI (admin) — patrz app/api/deps.py, get_current_user,
# gdzie last_active_at jest aktualizowane przy uwierzytelnionych zapytaniach.
# ══════════════════════════════════════════════════════════════════
class UserActivityEntry(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    email: str
    display_name: str | None
    last_active_at: datetime | None
    created_at: datetime
    is_active_last_24h: bool
    is_active_last_7d: bool


@router.get(
    "/admin/activity",
    response_model=list[UserActivityEntry],
    summary="Lista użytkowników wg ostatniej aktywności (admin)",
)
async def get_user_activity(
    current_user: User = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
) -> list[UserActivityEntry]:
    """Zwraca WSZYSTKICH użytkowników posortowanych od najbardziej
    aktywnych — do monitorowania zaangażowania (np. ilu użytkowników
    faktycznie wraca do aplikacji, nie tylko ją zainstalowało)."""
    result = await db.execute(
        select(User).order_by(User.last_active_at.desc().nulls_last())
    )
    users = result.scalars().all()
    now = datetime.now(timezone.utc)

    entries = []
    for u in users:
        last_active_naive = u.last_active_at
        is_24h = False
        is_7d = False
        if last_active_naive is not None:
            delta = now - last_active_naive
            is_24h = delta <= timedelta(hours=24)
            is_7d = delta <= timedelta(days=7)
        entries.append(
            UserActivityEntry(
                id=u.id,
                email=u.email,
                display_name=u.display_name,
                last_active_at=u.last_active_at,
                created_at=u.created_at,
                is_active_last_24h=is_24h,
                is_active_last_7d=is_7d,
            )
        )
    return entries

