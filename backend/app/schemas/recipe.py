"""Schematy Pydantic v2 dla przepisów, tagów i składników."""

from __future__ import annotations

import uuid
from datetime import datetime
from decimal import Decimal

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator

from app.services.nutrition_calculator import is_ingredient_quantity_reasonable, quantity_to_grams


class RecipeIngredientCreate(BaseModel):
    """Dane składnika przy tworzeniu przepisu."""

    product_id: uuid.UUID
    quantity: float = Field(gt=0)
    unit: str
    is_optional: bool = False

    @model_validator(mode="after")
    def validate_quantity_range(self) -> "RecipeIngredientCreate":
        # UWAGA (naprawa): brak jakiegokolwiek górnego ograniczenia
        # oznaczał, że literówka przy wpisywaniu ilości (np. "200" zamiast
        # "2" dla produktu liczonego w SZTUKACH) tworzyła przepis z
        # absurdalną wartością odżywczą (np. 48 000 kcal za "200 sztuk
        # awokado") — nic tego nie łapało, ani przy tworzeniu, ani później
        # w generatorze planów. Ta sama funkcja (is_ingredient_quantity_
        # reasonable) jest używana też przy imporcie przez AI, żeby oba
        # miejsca łapały te same pomyłki tą samą regułą.
        if not is_ingredient_quantity_reasonable(self.quantity, self.unit):
            raise ValueError(
                f"Ilość składnika ({self.quantity} {self.unit}) jest nierealistycznie duża."
            )
        return self

class RecipeIngredientResponse(BaseModel):
    """Odpowiedź API — składnik przepisu."""

    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    product_id: uuid.UUID
    product_name: str
    quantity: float
    unit: str
    is_optional: bool
    kcal: int | None = None
    # Białko/tłuszcze/węglowodany dla TEJ ilości składnika w przepisie
    # (nie na 100 g — już przeliczone tak samo jak `kcal`).
    #
    # NAPRAWA REALNEGO BŁĘDU: odpowiedź API nigdy nie zawierała pełnego
    # obiektu `product` (patrz brak takiego pola w tym schemacie) —
    # tylko `product_id`/`product_name`. Frontend (okno edycji
    # składników w Śledzeniu) zakładał, że dostanie
    # `ingredient.product.nutritionPer100` i na tej podstawie policzy
    # B/T/W. Ponieważ to pole było zawsze puste, podsumowanie
    # makroskładników przy edycji zawsze pokazywało zera — działało
    # tylko kcal, bo to jedyna wartość liczona już tutaj, po stronie
    # backendu. Te trzy pola domykają lukę tym samym mechanizmem.
    protein: float | None = None
    fat: float | None = None
    carbs: float | None = None

    @model_validator(mode="before")
    @classmethod
    def get_product_name(cls, data):
        if hasattr(data, "product") and data.product is not None:
            from app.services.nutrition_calculator import compute_recipe_nutrition_total

            kcal: int | None = None
            protein = fat = carbs = None
            try:
                # Ta sama funkcja, której backend używa do liczenia
                # `nutrition_total` całego przepisu — wywołana na LIŚCIE
                # JEDNOELEMENTOWEJ zwraca sumę dla tego jednego składnika,
                # z uwzględnieniem korekty tłuszczu do smażenia.
                totals = compute_recipe_nutrition_total([data])
                kcal = int(round(totals.get("kcal", 0) or 0))
                protein = round(totals.get("protein", 0) or 0, 1)
                fat = round(totals.get("fat", 0) or 0, 1)
                carbs = round(totals.get("carbs", 0) or 0, 1)
            except Exception:
                pass

            return {
                "id": data.id,
                "product_id": data.product_id,
                "product_name": data.product.name,
                "quantity": data.quantity,
                "unit": data.unit,
                "is_optional": data.is_optional,
                "kcal": kcal,
                "protein": protein,
                "fat": fat,
                "carbs": carbs,
            }
        return data


class RecipeBase(BaseModel):
    """Wspólne pola przepisu."""

    # UWAGA (naprawa): pola tekstowe nie miały limitów długości — dłuższa
    # wartość niż kolumna w bazie (patrz app/models/recipe.py) powodowała
    # nieobsłużony błąd bazy danych (surowy 500) zamiast czytelnej
    # odpowiedzi walidacyjnej. Ten sam wzorzec błędu co przy display_name
    # w rejestracji (już naprawiony) — limity dobrane tak, żeby dokładnie
    # odpowiadały ograniczeniom odpowiednich kolumn.
    name: str = Field(..., max_length=300)
    description: str | None = None
    cuisine: str | None = Field(default=None, max_length=100)
    meal_type: str = Field(..., max_length=50)
    prep_time_min: int | None = None
    cook_time_min: int | None = None
    servings: int = Field(default=2, ge=1)
    difficulty: str = Field(default="łatwy", max_length=50)


class RecipeCreate(RecipeBase):
    """Dane wymagane do utworzenia przepisu."""

    tags: list[str] = []
    ingredients: list[RecipeIngredientCreate] = []
    instructions: list[str] = []
    suggested_seasonings: list[str] = []
    # Zgłoszenie do wspólnego katalogu widocznego dla wszystkich — tylko
    # konta Premium mogą to ustawić na True. Domyślnie przepis jest
    # prywatny (widoczny tylko dla twórcy).
    request_public: bool = False
    # Prawdziwe zdjęcie dania (Base64, bez prefiksu "data:image/...") —
    # opcjonalne, tylko dla ręcznie dodawanych przepisów.
    photo_base64: str | None = None

    @field_validator("photo_base64")
    @classmethod
    def validate_photo(cls, v: str | None) -> str | None:
        if v is None:
            return v
        from app.core.photo_validation import validate_and_check_photo_base64

        # 3 MB po dekompresji — ten sam limit co przy zdjęciach komentarzy.
        return validate_and_check_photo_base64(v, 3 * 1024 * 1024)


class RecipeVariantCreate(BaseModel):
    """Składniki tymczasowo zmienionego przepisu zapisywanego w „Moje”."""

    ingredients: list[RecipeIngredientCreate] = Field(min_length=1)


class RecipeResponse(RecipeBase):
    """Odpowiedź API — pełne dane przepisu."""

    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    nutrition_total: dict | None = None
    image_url: str | None = None
    photo_base64: str | None = None
    instructions: list[str] | None = None
    suggested_seasonings: list[str] | None = None
    is_active: bool
    tags: list[str] = []
    ingredients: list[RecipeIngredientResponse] = []
    created_at: datetime
    # Czy AKTUALNIE zalogowany użytkownik ma ten przepis w ulubionych —
    # dołączane ręcznie w endpointzie, żeby frontend nie musiał robić
    # osobnego zapytania dla każdego przepisu.
    is_favorite: bool = False
    # Czy to przepis dodany przez AI (prywatny, widoczny tylko dla
    # twórcy) — frontend używa tego np. do pokazania odznaki "Twój
    # przepis" i opcji edycji/usunięcia (docelowo).
    is_own_recipe: bool = False
    # "private" / "pending" / "public" / "rejected" — nieistotne dla 81
    # oficjalnych przepisów (zawsze widoczne, niezależnie od tej wartości).
    visibility: str = "private"
    # ID autora (użytkownika, nie admina-moderatora) — None dla 81
    # oficjalnych przepisów dostarczonych z aplikacją. Potrzebne we
    # frontendzie wyłącznie do przycisku "Zablokuj autora" (patrz
    # widgets/report_block_menu.dart) — samo pole nic nie odsłania,
    # bo autor i tak jest widoczny publicznie jako twórca przepisu.
    created_by_user_id: uuid.UUID | None = None
    # "Dodane przez [nazwa]" na ekranie szczegółów. Puste dla 81
    # oficjalnych przepisów (created_by_user_id=None) i dla list/siatek,
    # gdzie relacja `creator` NIE jest wczytywana celowo (koszt joina
    # przy każdym z dziesiątek przepisów na liście na raz).
    created_by_name: str | None = None
    created_by_avatar: str | None = None
    created_by_avatar_photo: str | None = None

    @field_validator("tags", mode="before")
    @classmethod
    def serialize_tags(cls, v):
        if isinstance(v, list):
            return [t.tag if hasattr(t, "tag") else t for t in v]
        return v

    @model_validator(mode="before")
    @classmethod
    def ensure_nutrition(cls, data):
        # NAPRAWA: to i dociąganie danych autora ("Dodane przez") były
        # KIEDYŚ dwoma osobnymi walidatorami @model_validator(mode="before").
        # Założenie, że Pydantic uruchomi je w kolejności deklaracji
        # w kodzie, okazało się błędne — w praktyce ten walidator (drugi
        # w pliku) wykonywał się PIERWSZY, zamieniając obiekt ORM na
        # zwykły słownik (patrz niżej), zanim walidator autora zdążył
        # skorzystać z relacji `creator`. Efekt: autor nigdy się nie
        # pokazywał, mimo że dane w bazie i zapytanie były poprawne —
        # potwierdzone testem end-to-end na żywych modelach. Połączenie
        # w jedną funkcję eliminuje zależność od kolejności międzywalidatorowej.
        try:
            from sqlalchemy import inspect as sa_inspect

            insp = sa_inspect(data)
            if "creator" not in insp.unloaded and data.creator is not None:
                data.created_by_name = data.creator.display_name
                data.created_by_avatar = data.creator.avatar
                data.created_by_avatar_photo = data.creator.avatar_photo_base64
        except Exception:
            pass

        if not getattr(data, "nutrition_total", None) and hasattr(data, "ingredients"):
            total = {"kcal": 0, "protein": 0, "fat": 0, "carbs": 0, "fiber": 0}
            for ing in data.ingredients:
                prod = getattr(ing, "product", None)
                if prod and prod.nutrition_per_100:
                    try:
                        qty = float(ing.quantity)
                        unit = getattr(ing, "unit", "g")
                        w = quantity_to_grams(prod.name, qty, unit)
                        for k in total:
                            total[k] += float(prod.nutrition_per_100.get(k, 0) or 0) * (w / 100.0)
                    except:
                        pass
            # UWAGA (naprawa): wcześniej ten blok wykonywał się TYLKO gdy
            # `any(v > 0 for v in total.values())` — czyli jeśli policzona
            # suma wyszła zerowa (np. bo żaden składnik się nie dopasował,
            # albo `ing.product` nie było załadowane), funkcja po cichu
            # zwracała ORYGINALNE dane BEZ ZMIAN zamiast ustawić
            # nutrition_total na wyliczone (choćby zerowe) wartości. Efekt:
            # przepis z realnym, ale nie do końca dopasowanym składnikiem
            # pokazywał puste/null wartości zamiast choćby częściowego,
            # jawnego wyniku — mylące i trudne do zdiagnozowania z
            # perspektywy użytkownika. Teraz zawsze budujemy i zwracamy
            # `res` z wyliczoną wartością (nawet jeśli to same zera),
            # więc zachowanie jest przewidywalne i widoczne wprost.
            res = {k: getattr(data, k) for k in data.__table__.columns.keys() if hasattr(data, k)}
            res["tags"] = data.tags
            res["ingredients"] = data.ingredients
            res["nutrition_total"] = {k: round(v, 1) for k, v in total.items()}
            # UWAGA (naprawa): is_favorite i is_own_recipe to atrybuty
            # ustawiane DYNAMICZNIE w endpointach PO wczytaniu z bazy
            # (nie są prawdziwymi kolumnami tabeli) — pętla powyżej,
            # budując `res` tylko z `__table__.columns.keys()`, całkiem
            # je gubiła. Efekt: KAŻDY przepis bez wcześniej wyliczonego
            # nutrition_total (czyli m.in. KAŻDY przepis dodany przez
            # AI) zawsze pokazywał is_own_recipe=False i is_favorite=False,
            # niezależnie od faktycznej wartości.
            res["is_favorite"] = getattr(data, "is_favorite", False)
            res["is_own_recipe"] = getattr(data, "is_own_recipe", False)
            # NAPRAWA: ten słownik budowany jest WYŁĄCZNIE z kolumn tabeli
            # (__table__.columns.keys()) — pola dołożone przez
            # attach_creator_info WYŻEJ (created_by_name i pozostałe) nie
            # są kolumnami, więc były tu po cichu gubione przy KAŻDYM
            # przeliczeniu wartości odżywczych (czyli praktycznie zawsze,
            # bo nutrition_total nigdy nie jest wcześniej wyliczone na
            # świeżo pobranym obiekcie). Efekt: "Dodane przez" nigdy się
            # nie pokazywało, mimo że dane były poprawnie wczytane —
            # potwierdzone testem na żywych modelach. Ten sam wzorzec co
            # is_favorite/is_own_recipe wyżej: trzeba przepisać jawnie.
            res["created_by_name"] = getattr(data, "created_by_name", None)
            res["created_by_avatar"] = getattr(data, "created_by_avatar", None)
            res["created_by_avatar_photo"] = getattr(data, "created_by_avatar_photo", None)
            return res
        return data


class AIRecipeImportRequest(BaseModel):
    """Żądanie rozpoznania przepisu przez AI — dokładnie JEDNO z pól
    `text` / `photo_base64` / `url` musi być podane."""

    text: str | None = Field(default=None, max_length=10_000)
    # Zdjęcie zakodowane w Base64, bez prefiksu "data:image/...".
    photo_base64: str | None = None
    # Krótki opis/podpowiedź ułatwiająca AI rozpoznanie zdjęcia (np. "to
    # jest szarlotka", "danie kuchni tajskiej") — opcjonalne, tylko dla
    # zdjęcia. Puste dla tekstu/linku (tam kontekst już jest w treści).
    photo_hint: str | None = Field(default=None, max_length=200)
    # Link do strony/posta (np. blog kulinarny, TikTok, Instagram) — AI
    # rozpozna przepis na podstawie tekstu strony (patrz ograniczenia
    # w app/services/ai_recipe_import.py, sekcja _fetch_url_text).
    url: str | None = Field(default=None, max_length=2000)
    # Zgłoszenie do wspólnego katalogu widocznego dla wszystkich — jak
    # przy ręcznym dodawaniu (ten endpoint i tak wymaga Premium, więc nie
    # trzeba tu dodatkowo sprawdzać uprawnień).
    request_public: bool = False

    @field_validator("photo_base64")
    @classmethod
    def validate_photo(cls, v: str | None) -> str | None:
        # UWAGA (naprawa): to jedyne z trzech miejsc z photo_base64
        # w aplikacji (obok ręcznego dodania przepisu i komentarzy), które
        # NIE miało żadnej walidacji — dało się wysłać dowolnie duże albo
        # zupełnie niebędące obrazem dane, które trafiały prosto do
        # płatnego API Gemini. Co gorsza: to samo zdjęcie staje się
        # POTEM zdjęciem utworzonego przepisu (photo_base64=payload...),
        # więc bez tej walidacji całkiem omijało też sprawdzenie w
        # RecipeCreate.
        if v is None:
            return v
        from app.core.photo_validation import validate_and_check_photo_base64

        return validate_and_check_photo_base64(v, 3 * 1024 * 1024)

