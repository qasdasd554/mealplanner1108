"""Wspólna walidacja zdjęć przesyłanych jako Base64 — używana zarówno
przy zdjęciach w komentarzach, jak i przy zdjęciach przepisów, żeby nie
duplikować tej samej logiki bezpieczeństwa w dwóch miejscach."""

from __future__ import annotations

import base64


def validate_and_check_photo_base64(v: str, max_bytes: int) -> str:
    """Sprawdza, że `v` to poprawny Base64 dekodujący się do rozpoznawalnego
    obrazu (JPEG/PNG/WebP/GIF) o rozmiarze nie większym niż `max_bytes`.
    Rzuca ValueError z czytelnym komunikatem, jeśli coś jest nie tak.
    Zwraca `v` bez zmian, jeśli wszystko w porządku (do użycia bezpośrednio
    w field_validator Pydantic)."""
    try:
        decoded = base64.b64decode(v, validate=True)
    except Exception as exc:
        raise ValueError("Nieprawidłowe dane zdjęcia (błędny Base64)") from exc

    if len(decoded) > max_bytes:
        raise ValueError(f"Zdjęcie jest za duże (max {max_bytes // 1024 // 1024} MB po dekompresji)")

    # Sprawdzamy sygnaturę pliku (magic bytes) dla najpopularniejszych
    # formatów obrazów — bez tego ktokolwiek mógłby zapisać w bazie
    # dowolne dane binarne pod pozorem "zdjęcia".
    is_jpeg = decoded[:3] == b"\xff\xd8\xff"
    is_png = decoded[:8] == b"\x89PNG\r\n\x1a\n"
    is_webp = decoded[:4] == b"RIFF" and decoded[8:12] == b"WEBP"
    is_gif = decoded[:6] in (b"GIF87a", b"GIF89a")
    if not (is_jpeg or is_png or is_webp or is_gif):
        raise ValueError("Przesłany plik nie jest rozpoznawalnym obrazem (JPEG, PNG, WebP lub GIF)")

    return v
