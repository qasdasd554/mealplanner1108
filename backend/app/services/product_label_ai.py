"""Rozpoznawanie produktu z dwóch zdjęć etykiety przez Gemini.

Ta ścieżka jest uruchamiana wyłącznie wtedy, gdy kodu nie ma w Neon,
Open Food Facts ani USDA. Nie bierze udziału w zwykłym skanowaniu, więc
nie może spowolnić produktów, które już są znane.
"""

from __future__ import annotations

import base64
import json
import re

from app.services.ai_recipe_import import AIRecipeImportError, _call_gemini


class ProductLabelRecognitionError(Exception):
    """Czytelny błąd rozpoznawania etykiety produktu."""


def _image_mime(photo_base64: str) -> str:
    raw = base64.b64decode(photo_base64)
    if raw.startswith(b"\x89PNG\r\n\x1a\n"):
        return "image/png"
    if raw.startswith(b"RIFF") and raw[8:12] == b"WEBP":
        return "image/webp"
    if raw.startswith((b"GIF87a", b"GIF89a")):
        return "image/gif"
    return "image/jpeg"


def _optional_number(value: object, *, maximum: float) -> float | None:
    if value is None or isinstance(value, bool):
        return None
    try:
        number = float(str(value).replace(",", "."))
    except (TypeError, ValueError):
        return None
    return round(number, 2) if 0 <= number <= maximum else None


def _parse_label_json(raw_text: str, barcode: str) -> dict:
    cleaned = re.sub(r"^```(?:json)?\s*|\s*```$", "", raw_text.strip())
    try:
        payload = json.loads(cleaned)
    except json.JSONDecodeError as exc:
        raise ProductLabelRecognitionError(
            "AI nie zwróciło prawidłowych danych produktu. Zrób wyraźniejsze zdjęcia."
        ) from exc
    if not isinstance(payload, dict):
        raise ProductLabelRecognitionError("Nie udało się odczytać etykiety produktu.")

    name = str(payload.get("name") or "").strip()
    if len(name) < 2:
        raise ProductLabelRecognitionError(
            "Nie udało się odczytać nazwy. Zrób zdjęcie całego przodu opakowania."
        )
    brand = str(payload.get("brand") or "").strip() or None
    unit = str(payload.get("unit") or "g").strip().lower()
    if unit not in {"g", "ml", "szt"}:
        unit = "g"

    return {
        "found": True,
        "source": "product_label_ai",
        "barcode": barcode,
        "name": name[:300],
        "brand": brand[:200] if brand else None,
        "unit": unit,
        "serving_quantity": _optional_number(
            payload.get("serving_quantity"), maximum=100_000
        ),
        "kcal_per_100": _optional_number(payload.get("kcal_per_100"), maximum=2_000),
        "protein_per_100": _optional_number(
            payload.get("protein_per_100"), maximum=200
        ),
        "fat_per_100": _optional_number(payload.get("fat_per_100"), maximum=200),
        "carbs_per_100": _optional_number(payload.get("carbs_per_100"), maximum=200),
    }


async def recognize_product_label(
    *,
    barcode: str,
    front_photo_base64: str,
    nutrition_photo_base64: str,
) -> dict:
    """Odczytuje wyłącznie informacje widoczne na dostarczonych zdjęciach."""
    prompt = """Rozpoznaj produkt spożywczy z dwóch zdjęć.
Pierwsze zdjęcie pokazuje przód opakowania, drugie tabelę wartości odżywczych.

ZASADY:
- Nie zgaduj i nie korzystaj z pamięci o podobnych produktach.
- Nazwę i markę odczytaj z przodu opakowania.
- Makro zwróć zawsze na 100 g albo 100 ml, zgodnie z tabelą.
- Jeżeli tabela podaje tylko porcję i da się ją jednoznacznie przeliczyć,
  przelicz wartości na 100 g/ml. W przeciwnym razie zwróć null.
- serving_quantity oznacza widoczną masę/objętość porcji lub opakowania.
- unit może być wyłącznie: g, ml albo szt.
- Dla każdej niewidocznej lub niepewnej liczby zwróć null.

Zwróć wyłącznie JSON:
{
  "name": "pełna nazwa produktu",
  "brand": "marka lub null",
  "unit": "g",
  "serving_quantity": 100,
  "kcal_per_100": 123,
  "protein_per_100": 4.5,
  "fat_per_100": 2.1,
  "carbs_per_100": 18.0
}"""
    parts = [
        {"text": prompt},
        {"text": "Zdjęcie 1 — przód opakowania:"},
        {
            "inlineData": {
                "mimeType": _image_mime(front_photo_base64),
                "data": front_photo_base64,
            }
        },
        {"text": "Zdjęcie 2 — tabela wartości odżywczych:"},
        {
            "inlineData": {
                "mimeType": _image_mime(nutrition_photo_base64),
                "data": nutrition_photo_base64,
            }
        },
    ]
    try:
        raw = await _call_gemini(
            parts,
            timeout_seconds=22,
            max_total_seconds=40,
        )
    except AIRecipeImportError as exc:
        raise ProductLabelRecognitionError(
            "Rozpoznawanie etykiety jest chwilowo niedostępne. Spróbuj ponownie za moment."
        ) from exc
    return _parse_label_json(raw, barcode)
