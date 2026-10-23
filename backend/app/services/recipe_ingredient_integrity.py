"""Conservative PL/GB checks; never invent a meal's ingredients or amounts."""

import re
import unicodedata

from fastapi import HTTPException


def _normal(value):
    text = unicodedata.normalize("NFKD", (value or "").casefold().replace("ł", "l"))
    return " ".join(re.findall(r"[a-z0-9]+", "".join(c for c in text if not unicodedata.combining(c))))


_CONNECTOR = re.compile(r"\b(?:z|ze|w|i|with|and|in|served)\b")
_DESCRIPTORS = {"traditional", "homemade", "classic", "delicious", "tradycyjny", "tradycyjna", "domowy", "domowa", "klasyczny", "klasyczna", "ready", "meal"}
_COMPONENTS = {"paste", "powder", "sauce", "stock", "spice", "seasoning", "oil", "butter", "sos", "bulion", "przyprawa", "olej", "maslo", "oliwa", "extract", "ekstrakt"}
_ATTRIBUTES = {"skin", "bone", "bones", "seeds", "seed", "salt", "added", "without", "no", "unsalted", "skora", "skorka", "sol", "sola", "ziarnami", "pestkami", "koscia", "kosci"}


def _head(value):
    return [word for word in _CONNECTOR.split(_normal(value), maxsplit=1)[0].split()
            if word not in _DESCRIPTORS]


def _component(value):
    head = _head(value)
    return (bool(set(head) & _COMPONENTS) or " ".join(head).startswith("pasta curry")
            or " w proszku" in _normal(value))


def _stems(words):
    # Only an extra safety signal, never used to choose/replace a product ID.
    return {word[:5] if len(word) > 5 else word for word in words}


def looks_like_whole_meal(name):
    normal = _normal(name)
    if _component(name):
        return False
    if any(phrase in normal for phrase in ("ready meal", "danie gotowe", "gotowe danie", "danie obiadowe")):
        return True
    connector = _CONNECTOR.search(normal)
    if connector is None:
        return False
    tail = set(normal[connector.end():].split()) - {"and", "i", "with", "z", "ze"}
    return bool(tail) and not tail.issubset(_ATTRIBUTES)


def is_whole_recipe_product(recipe_name, product_name):
    recipe, product = _normal(recipe_name), _normal(product_name)
    if not recipe or not product:
        return False
    if _component(product):
        return False
    recipe_head, product_head = _stems(_head(recipe)), _stems(_head(product))
    # The complete recipe head must be present. A raw ingredient containing
    # only 'chicken' is not the whole 'chicken tikka masala' recipe.
    return bool(recipe_head) and recipe_head.issubset(product_head) and looks_like_whole_meal(product)


def validate_ingredient_names(recipe_name, product_names, *, country_code="PL"):
    suspicious = [name for name in product_names if is_whole_recipe_product(recipe_name, name)]
    if not suspicious:
        return
    names = ", ".join(dict.fromkeys(suspicious))[:600]
    detail = (
        f'The recipe “{recipe_name[:150]}” contains a whole prepared dish instead of cooking ingredients: {names}. '
        'Correct its ingredients before creating the shopping list. No list was changed.'
        if country_code == "GB" else
        f'Przepis „{recipe_name[:150]}” zawiera gotowe danie zamiast składników do przygotowania: {names}. '
        'Popraw składniki przepisu przed utworzeniem listy zakupów. Lista nie została zmieniona.'
    )
    raise HTTPException(status_code=409, detail=detail)


def validate_recipe_ingredients(recipe, *, country_code="PL"):
    validate_ingredient_names(getattr(recipe, "name", ""),
        [ingredient.product.name for ingredient in recipe.ingredients
         if ingredient.product is not None], country_code=country_code)
