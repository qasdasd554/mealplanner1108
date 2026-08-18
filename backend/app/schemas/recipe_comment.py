"""Schematy Pydantic dla komentarzy pod przepisami."""

import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field, field_validator

from app.core.photo_validation import validate_and_check_photo_base64
from app.core.profanity_filter import contains_profanity

# Maksymalny rozmiar zdjęcia PO zdekodowaniu z Base64 — 3 MB. Zdjęcie jest
# przechowywane bezpośrednio w bazie danych (patrz komentarz w modelu
# RecipeComment), więc limit chroni bazę przed nadmiernym rozrostem, gdyby
# ktoś spróbował wysłać nieskompresowane, bardzo duże zdjęcie.
MAX_PHOTO_BYTES = 3 * 1024 * 1024

# Limit długości komentarza — 500 znaków. Dobrane tak, żeby starczyło na
# konkretną wskazówkę albo krótką recenzję ("zamiast masła użyłam oliwy,
# piekłam 5 minut dłużej"), ale nie na ścianę tekstu, która zdominowałaby
# sekcję komentarzy pod przepisem. Podobny rząd wielkości (500 znaków)
# spotyka się w polach odpowiedzi/komentarza w innych aplikacjach.
MAX_COMMENT_LENGTH = 500


class RecipeCommentCreate(BaseModel):
    """Dane przesyłane przy dodawaniu komentarza."""

    text: str | None = Field(default=None, max_length=MAX_COMMENT_LENGTH)
    # Zdjęcie zakodowane w Base64, BEZ prefiksu "data:image/jpeg;base64,"
    # (sam ciąg base64 danych obrazu).
    photo_base64: str | None = None

    @field_validator("text")
    @classmethod
    def strip_text(cls, v: str | None) -> str | None:
        if v is None:
            return v
        v = v.strip()
        if not v:
            return None
        if contains_profanity(v):
            raise ValueError(
                "Komentarz zawiera niedozwolony język. Popraw treść i spróbuj ponownie."
            )
        return v

    @field_validator("photo_base64")
    @classmethod
    def validate_photo_size(cls, v: str | None) -> str | None:
        if v is None:
            return v
        return validate_and_check_photo_base64(v, MAX_PHOTO_BYTES)


class RecipeCommentResponse(BaseModel):
    """Odpowiedź API — pojedynczy komentarz."""

    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    recipe_id: uuid.UUID
    user_id: uuid.UUID
    # Nazwa autora dołączana ręcznie w endpointzie (z relacji user) —
    # potrzebna do wyświetlenia "Kto napisał", żeby frontend nie musiał
    # robić osobnego zapytania o każdego użytkownika.
    author_name: str
    text: str | None = None
    photo_base64: str | None = None
    created_at: datetime
    like_count: int = 0
    # Czy AKTUALNIE zalogowany użytkownik polubił ten komentarz — potrzebne,
    # żeby frontend wiedział, czy pokazać serce wypełnione czy puste, bez
    # osobnego zapytania.
    liked_by_me: bool = False
