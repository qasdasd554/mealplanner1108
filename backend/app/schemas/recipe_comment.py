"""Schematy Pydantic dla komentarzy pod przepisami."""

import base64
import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field, field_validator

# Maksymalny rozmiar zdjęcia PO zdekodowaniu z Base64 — 3 MB. Zdjęcie jest
# przechowywane bezpośrednio w bazie danych (patrz komentarz w modelu
# RecipeComment), więc limit chroni bazę przed nadmiernym rozrostem, gdyby
# ktoś spróbował wysłać nieskompresowane, bardzo duże zdjęcie.
MAX_PHOTO_BYTES = 3 * 1024 * 1024


class RecipeCommentCreate(BaseModel):
    """Dane przesyłane przy dodawaniu komentarza."""

    # UWAGA (naprawa bezpieczeństwa): wcześniej `text` nie miał żadnego
    # limitu długości, a kolumna w bazie to nieograniczony typ Text —
    # ktoś mógłby wysłać komentarz o rozmiarze wielu megabajtów, obciążając
    # bazę danych i spowalniając wyświetlanie listy komentarzy każdemu,
    # kto ją przegląda.
    text: str | None = Field(default=None, max_length=2000)
    # Zdjęcie zakodowane w Base64, BEZ prefiksu "data:image/jpeg;base64,"
    # (sam ciąg base64 danych obrazu).
    photo_base64: str | None = None

    @field_validator("text")
    @classmethod
    def strip_text(cls, v: str | None) -> str | None:
        if v is None:
            return v
        v = v.strip()
        return v if v else None

    @field_validator("photo_base64")
    @classmethod
    def validate_photo_size(cls, v: str | None) -> str | None:
        if v is None:
            return v
        try:
            decoded = base64.b64decode(v, validate=True)
        except Exception as exc:
            raise ValueError("Nieprawidłowe dane zdjęcia (błędny Base64)") from exc
        if len(decoded) > MAX_PHOTO_BYTES:
            raise ValueError(
                f"Zdjęcie jest za duże (max {MAX_PHOTO_BYTES // 1024 // 1024} MB po dekompresji)"
            )
        # UWAGA (naprawa bezpieczeństwa): wcześniej nic nie sprawdzało, czy
        # przesłane dane są w ogóle obrazem — ktokolwiek mógłby zapisać w
        # bazie dowolne dane binarne pod pozorem "zdjęcia komentarza".
        # Sprawdzamy sygnaturę pliku (magic bytes) dla najpopularniejszych
        # formatów obrazów.
        is_jpeg = decoded[:3] == b"\xff\xd8\xff"
        is_png = decoded[:8] == b"\x89PNG\r\n\x1a\n"
        is_webp = decoded[:4] == b"RIFF" and decoded[8:12] == b"WEBP"
        is_gif = decoded[:6] in (b"GIF87a", b"GIF89a")
        if not (is_jpeg or is_png or is_webp or is_gif):
            raise ValueError(
                "Przesłany plik nie jest rozpoznawalnym obrazem (JPEG, PNG, WebP lub GIF)"
            )
        return v


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
