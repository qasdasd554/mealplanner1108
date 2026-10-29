"""One diet vocabulary for generation and subsequent plan recipe choices."""
import re
import unicodedata

from app.services.exceptions import ServiceError


DIET_NAME_TO_TAG = {
    "Wegetariańska": "wegetariańskie", "Wegańska": "wegańskie",
    "Bezglutenowa": "bezglutenowe", "Wysokobiałkowa": "wysokobiałkowe", "Keto": "keto",
}


def _normal(value):
    value = unicodedata.normalize("NFKD", value.lower().replace("ł", "l"))
    value = value.encode("ascii", "ignore").decode()
    return re.sub(r"[^a-z0-9]+", " ", value).strip()


def recipe_diet_tag(diet):
    if diet is not None and not isinstance(diet, str):
        raise ServiceError("Wybierz poprawną dietę w ustawieniach planu.")
    normalized = _normal(diet or "")
    if normalized in {"", "bez ograniczen", "none", "brak", "no restrictions"}:
        return None
    tags = {_normal(name): tag for name, tag in DIET_NAME_TO_TAG.items()}
    tags.update({_normal(tag): tag for tag in DIET_NAME_TO_TAG.values()})
    tags.update({_normal(name): tag for name, tag in {
        "vegetarian": "wegetariańskie", "vegan": "wegańskie", "gluten_free": "bezglutenowe",
        "high_protein": "wysokobiałkowe", "ketogenic": "keto",
    }.items()})
    tag = tags.get(normalized)
    if tag is None:
        raise ServiceError("Nieznana dieta. Wybierz ją ponownie w ustawieniach planu.")
    return tag
