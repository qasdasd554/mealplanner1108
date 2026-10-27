"""Piece presentation for known system foods; never rewrite quote arithmetic."""
from decimal import Decimal, ROUND_CEILING
from functools import lru_cache


@lru_cache(maxsize=1)
def _pieces():
    from app.db.seed import PRODUCTS_DATA, _uid
    from app.services.product_measures import PIECE_GRAMS
    return {_uid('product:' + row[0]): (row[0], Decimal(str(PIECE_GRAMS[row[0]])))
            for row in PRODUCTS_DATA if row[1] == 'szt' and row[0] in PIECE_GRAMS}


def shopping_piece_display(product_id, name, quantity, unit):
    if unit != 'g' or product_id not in _pieces():
        return {}
    from app.services.system_content_language import _index
    source, grams = _pieces()[product_id]
    translated = _index()['ingredients'].get(str(product_id), {}).get('en_GB')
    if name not in {source, translated}:
        return {}
    value = Decimal(str(quantity))
    if not value.is_finite() or value <= 0:
        return {}
    return dict(display_quantity=int((value / grams).to_integral_value(rounding=ROUND_CEILING)),
                display_unit='szt', display_quantity_is_approximate=True)
