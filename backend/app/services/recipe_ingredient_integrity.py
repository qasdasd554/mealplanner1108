"""Conservative PL/GB checks; never invent a meal's ingredients or amounts."""

import re
import unicodedata

from fastapi import HTTPException


def _normal(value):
    text = unicodedata.normalize("NFKD", (value or "").casefold().replace("ł", "l"))
    return " ".join(re.findall(r"[a-z0-9]+", "".join(c for c in text if not unicodedata.combining(c))))


_CONNECTOR = re.compile(r"\b(?:z|ze|w|i|with|and|in|served)\b")
_DESCRIPTORS = {"traditional", "homemade", "classic", "delicious", "tradycyjny", "tradycyjna", "domowy", "domowa", "klasyczny", "klasyczna", "ready", "meal"}
_COMPONENTS = {"paste", "powder", "sauce", "stock", "spice", "seasoning", "oil", "butter", "sos", "bulion", "przyprawa", "olej", "maslo", "oliwa", "extract", "ekstrakt", "flour", "maka", "juice", "sok", "przecier", "koncentrat", "melasa", "molasses"}
_ATTRIBUTES = {"skin", "bone", "bones", "seeds", "seed", "salt", "added", "without", "no", "unsalted", "skora", "skorka", "sol", "sola", "ziarnami", "pestkami", "koscia", "kosci",
               "spring", "water", "brine", "juice", "its", "own", "wodzie", "zalewie", "puszce"}
_CUTS = {"piers", "filet", "udziec", "udko", "podudzie", "skrzydelka", "schab", "karkowka", "lopatka", "comber", "zeberka", "poledwica", "mieso"}
_ANIMALS = {"kurczaka", "indyka", "lososia", "dorsza", "kaczki", "krolika", "wolowiny", "wieprzowiny", "cieleciny", "jagnieciny"}


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
    # Compound dish names without a preposition still describe a ready meal.
    # In particular '&' is removed by normalisation, so a connector-only
    # rule let packaged Cordon Bleu enter the cooking-ingredient prompt.
    if re.search(r"\bcordon bleu\b", normal):
        return True
    if any(phrase in normal for phrase in ("ready meal", "danie gotowe", "gotowe danie", "danie obiadowe")):
        return True
    connector = _CONNECTOR.search(normal)
    if connector is None:
        return False
    tail = set(normal[connector.end():].split()) - {"and", "i", "with", "z", "ze"}
    # "Pierś z kurczaka" describes the identity of one ingredient, not
    # a dish served with another ingredient. Do not remove it from AI's
    # catalogue merely because Polish uses the same preposition "z".
    if set(_head(name)) & _CUTS and tail & _ANIMALS and tail.issubset(_ANIMALS | _ATTRIBUTES):
        return False
    if tail == {"sosie", "wlasnym"}:
        return False
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
    # Used at AI creation/revision, not when transferring an already saved
    # recipe to a list. A different title must not evade ingredient validation.
    suspicious = [name for name in product_names if looks_like_whole_meal(name)]
    if not suspicious:
        return
    names = ", ".join(dict.fromkeys(suspicious))[:600]
    detail = (
        f'Could not recognise a complete ingredient list for “{recipe_name[:150]}”: {names}. '
        'A whole prepared meal cannot replace the ingredients needed to cook it. No recipe was saved.'
        if country_code == "GB" else
        f'Nie rozpoznano kompletnej listy składników przepisu „{recipe_name[:150]}”: {names}. '
        'Gotowy posiłek nie może zastąpić składników potrzebnych do przygotowania dania. Nie zapisano przepisu.'
    )
    raise HTTPException(status_code=422, detail=detail)


def validate_recipe_ingredients(recipe, *, country_code="PL"):
    validate_ingredient_names(getattr(recipe, "name", ""),
        [ingredient.product.name for ingredient in recipe.ingredients
         if ingredient.product is not None], country_code=country_code)
