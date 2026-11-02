"""Recover invalid recipe measures from explicit source text, never guess mass.

No recipe title, typical serving or package size is evidence for how many
grams a writer meant by an unsupported 'piece'. Both markets use this path.
"""
import math
import logging
import re
import unicodedata
from decimal import Decimal, ROUND_HALF_UP

from app.services.nutrition_calculator import quantity_to_grams
from app.services.product_measures import (
    _measure_names, canonical_measure_code, canonical_measure_name,
    explicit_physical_unit,
)

logger = logging.getLogger(__name__)


def _normal(text):
    return "".join(char for char in unicodedata.normalize("NFKD", str(text).casefold().replace("ł", "l"))
                   if not unicodedata.combining(char))


def ingredient_base_amount(product, quantity, unit):
    if product is None:
        return 0.0
    try:
        value = quantity_to_grams(product.name, float(quantity), unit,
            getattr(product, "serving_quantity", None), getattr(product, "measure_options", None))
        return value if math.isfinite(value) and value > 0 else 0.0
    except (TypeError, ValueError, OverflowError):
        return 0.0


def _name_pattern(name):
    words = re.findall(r"[a-z0-9]+", _normal(name))
    if not words:
        return None
    patterns = []
    for word in words:
        # Small, bounded inflection set; no free prefix match that would turn
        # 'cynamonki' or 'cukier cynamonowy' into the ingredient 'cynamon'.
        if len(word) >= 4 and word[-1] in "ayoe":
            patterns.append(re.escape(word[:-1]) + r"(?:a|y|o|e|i|u|em|ie|ej|ego|ym|ymi|ami)")
        elif len(word) >= 4:
            patterns.append(re.escape(word) + r"(?:u|em|ie|a|ami|ow|s)?")
        else:
            patterns.append(re.escape(word))
    return r"\b" + r"\s+".join(patterns) + r"\b"


_NUMBER = r"\d+(?:[.,]\d+)?(?:\s*/\s*\d+)?"
_UNIT = r"(?:kg|g|ml|l|lyzeczk(?:a|i|ami|e)|lyzeczek|lyzk(?:a|i|e|ami)|lyzek|szklank(?:a|i|e)|szklanek|tsp|tbsp|teaspoons?|tablespoons?)\b\.?"


def recover_ingredient_amount(product, quantity, unit, texts):
    """Return (g/ml amount, base unit) only for one unambiguous named amount."""
    if ingredient_base_amount(product, quantity, unit) or product is None:
        return None
    canonical = canonical_measure_name(product.name)
    names = {product.name, canonical}
    names.update(alias for alias, source in _measure_names().items() if source == canonical)
    candidates = set()
    for name in names:
        pattern = _name_pattern(name)
        if pattern is None:
            continue
        patterns = (
            rf"{pattern}\s*(?:\(\s*|:\s*)(?P<quantity>{_NUMBER})\s*(?P<unit>{_UNIT})",
            rf"(?<![\d/.,-])(?P<quantity>{_NUMBER})\s*(?P<unit>{_UNIT})\s+(?:of\s+)?{pattern}",
        )
        for text in texts:
            text = _normal(text)[:100000]
            for expression in patterns:
                for match in re.finditer(expression, text):
                    if re.search(r"\d\s+$", text[max(0, match.start()-10):match.start()]):
                        continue  # do not read '1 1/2 tsp' as only '1/2 tsp'
                    number = match["quantity"].replace(",", ".")
                    try:
                        amount = (float(number.split("/")[0]) / float(number.split("/")[1])
                                  if "/" in number else float(number))
                    except (ValueError, ZeroDivisionError, OverflowError):
                        continue
                    code = canonical_measure_code(match["unit"])
                    # The parser uses accent-free text; protocol codes do too.
                    code = {"lyzeczki": "lyzeczka", "lyzeczkami": "lyzeczka", "lyzeczek": "lyzeczka",
                            "lyzeczke": "lyzeczka", "lyzki": "lyzka", "lyzke": "lyzka",
                            "lyzkami": "lyzka", "lyzek": "lyzka", "szklanke": "szklanka"}.get(code, code)
                    grams = ingredient_base_amount(product, amount, code)
                    if grams:
                        base_unit = explicit_physical_unit(product)
                        bases = {row.get("base_unit") for row in getattr(product, "measure_options", None) or []
                                 if isinstance(row, dict) and row.get("base_unit") in {"g", "ml"}}
                        if base_unit is None or bases and bases != {base_unit}:
                            continue
                        # Preserve the dimension of a directly stated source.
                        direct = {"g": "g", "kg": "g", "ml": "ml", "l": "ml"}.get(code)
                        if direct and direct != base_unit:
                            continue
                        rounded = Decimal(str(grams)).quantize(Decimal("0.001"), rounding=ROUND_HALF_UP)
                        if 0 < rounded <= Decimal("9999999.999"):
                            candidates.add((rounded, base_unit))
    return next(iter(candidates)) if len(candidates) == 1 else None


def normalize_import_amounts(parsed, matched, *, source_text=None):
    texts = [*(parsed.get("instructions") or [])]
    if source_text:
        texts.append(source_text)
    for ingredient, product in matched:
        recovered = recover_ingredient_amount(product, ingredient["quantity"], ingredient["unit"], texts)
        if recovered:
            ingredient["quantity"], ingredient["unit"] = float(recovered[0]), recovered[1]
        else:
            ingredient["unit"] = canonical_measure_code(ingredient["unit"])
    return matched


def repair_recipe_amounts(recipe):
    """Update only provably recoverable units; invalidate fabricated totals.

    Caller owns the transaction. Unknown counts remain in the recipe and
    shopping list, with missing nutrition/cost instead of a fabricated 100 g.
    """
    changed = False
    invalid = False
    texts = getattr(recipe, "instructions", None) or []
    ingredients = getattr(recipe, "ingredients", None) or []
    for ingredient in ingredients:
        product = ingredient.product
        if not ingredient_base_amount(product, ingredient.quantity, ingredient.unit):
            invalid = True
            recovered = recover_ingredient_amount(product, ingredient.quantity, ingredient.unit, texts)
            if recovered:
                ingredient.quantity, ingredient.unit = float(recovered[0]), recovered[1]
                changed = True
    if changed or invalid:
        from app.services.nutrition_calculator import compute_recipe_nutrition_total
        total = compute_recipe_nutrition_total(ingredients)
        if getattr(recipe, "nutrition_total", None) != total:
            recipe.nutrition_total = total
            changed = True
    return changed


async def repair_open_lists_for_recipes(db, recipe_ids):
    """Rebuild only unbought generated requirements, preserving manual/history.

    The builder owns each transaction and retains manual rows. Already bought,
    completed and merged lists must not be silently rewritten by a data repair.
    """
    if not recipe_ids:
        return 0
    from sqlalchemy import select
    from app.models import MealPlanEntry, ShoppingList, ShoppingListItem
    from app.services.shopping_list_builder import ShoppingListBuilder
    ids = list((await db.execute(select(ShoppingList.id).join(
        MealPlanEntry, MealPlanEntry.meal_plan_id == ShoppingList.meal_plan_id,
    ).where(
        MealPlanEntry.recipe_id.in_(recipe_ids),
        ShoppingList.status.notin_(("completed", "merged")),
        ShoppingList.items.any(ShoppingListItem.is_generated.is_(True)),
        ~ShoppingList.items.any(ShoppingListItem.is_checked.is_(True)
            & ShoppingListItem.is_from_pantry.is_(False)),
    ).distinct())).scalars().all())
    updated = 0
    for identifier in ids:
        try:
            await ShoppingListBuilder(db).recalculate(identifier)
            updated += 1
        except Exception:
            await db.rollback()
            logger.exception("Could not rebuild an open shopping list after ingredient-unit repair: %s", identifier)
    return updated
