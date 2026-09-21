"""Regresje szybkiej ścieżki importu i doboru produktów."""

import asyncio

from bs4 import BeautifulSoup

from app.services import ai_recipe_import
from app.services.ai_recipe_import import (
    _jsonld_recipe_from_soup,
    _select_prompt_products,
    match_product_name,
)


def test_structured_recipe_can_skip_ai() -> None:
    html = '''<script type="application/ld+json">{
      "@context": "https://schema.org", "@type": "Recipe", "name": "Omlet",
      "recipeYield": "2 porcje",
      "recipeIngredient": ["2 jajka", "100 g mąki pszennej"],
      "recipeInstructions": [{"@type": "HowToStep", "text": "Wymieszaj składniki."}]
    }</script>'''
    parsed = _jsonld_recipe_from_soup(BeautifulSoup(html, "html.parser"))
    assert parsed is not None
    assert parsed["name"] == "Omlet"
    assert parsed["servings"] == 2
    assert parsed["ingredients"][0] == {
        "product_name": "jajka", "quantity": 2.0, "unit": "szt",
    }


def test_ambiguous_structured_ingredient_falls_back_to_ai() -> None:
    html = '''<script type="application/ld+json">{
      "@type": "Recipe", "name": "Zupa", "recipeIngredient": ["szczypta soli"],
      "recipeInstructions": "Wymieszaj."
    }</script>'''
    assert _jsonld_recipe_from_soup(BeautifulSoup(html, "html.parser")) is None


def test_matching_product_name_does_not_guess_unrelated_ingredient() -> None:
    names = ["Mąka pszenna", "Jajka", "Masło"]
    assert match_product_name("maka pszenna", names) == "Mąka pszenna"
    assert match_product_name("krewetki", names) is None


def test_full_recipe_text_uses_smaller_prompt_catalog() -> None:
    names = [f"Produkt {i}" for i in range(200)]
    names += ["Jajka", "Mąka", "Mleko", "Masło"]
    selected = _select_prompt_products(
        names, "Jajka, mąka, mleko i masło. Wymieszaj i smaż."
    )
    assert set(["Jajka", "Mąka", "Mleko", "Masło"]).issubset(selected)
    assert len(selected) < len(names)


def test_photo_prompt_never_includes_entire_large_catalog() -> None:
    selected = _select_prompt_products([f"Produkt {i}" for i in range(3000)], None)
    assert len(selected) == 140


def test_timeout_of_first_model_tries_second_model(monkeypatch) -> None:
    attempted = []

    async def fake_model(parts, model, *, timeout_seconds):
        attempted.append(model)
        if model == "first":
            raise ai_recipe_import._ModelUnavailableError("timeout", reason="timeout")
        return '{"name":"Omlet"}'

    monkeypatch.setattr(ai_recipe_import.settings, "GEMINI_API_KEY", "test-key")
    monkeypatch.setattr(ai_recipe_import, "GEMINI_MODELS", ["first", "second"])
    monkeypatch.setattr(ai_recipe_import, "_call_gemini_model", fake_model)
    ai_recipe_import._model_unavailable_until.clear()
    try:
        result = asyncio.run(ai_recipe_import._call_gemini([{"text": "omlet"}]))
    finally:
        ai_recipe_import._model_unavailable_until.clear()
    assert result == '{"name":"Omlet"}'
    assert attempted == ["first", "second"]
