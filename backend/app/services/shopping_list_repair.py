"""Consolidate old unchecked generated UK rows; preserve purchase history."""
from decimal import Decimal, localcontext
from sqlalchemy import select
from app.models import Product
from app.services.regional_requirements import canonical_measure_code, to_regional_base_quantity, MAX_STORED_QUANTITY
from app.services.regional_shopping import apply_regional_item_quote, load_regional_offers, regional_pricing_date


def candidates(shopping):
    if shopping.status not in {'pending', 'in_progress'}:
        return []
    return [item for item in shopping.items if item.regional_snapshot is not None
            and item.is_generated and not item.is_checked and not item.is_from_pantry
            and not (item.regional_snapshot.manual_extra_quantity or 0)]


def needs_repair(shopping):
    seen = set()
    for item in candidates(shopping):
        key = (item.regional_snapshot.product_id, item.substituted_for)
        if key in seen or canonical_measure_code(item.unit) not in {'g', 'ml'}:
            return True
        seen.add(key)
    return False


async def consolidate_generated_rows(db, shopping):
    """Caller locks the list and commits; no totals/units are guessed."""
    items = candidates(shopping)
    ids = {item.regional_snapshot.product_id for item in items}
    if not ids:
        return False
    products = {row.id: row for row in (await db.execute(select(Product).where(Product.id.in_(ids)))).scalars()}
    groups = {}
    for item in items:
        product = products.get(item.regional_snapshot.product_id)
        if product is None:
            continue
        try:
            quantity, unit = to_regional_base_quantity(product, item.required_quantity, item.unit)
        except ValueError:
            quantity, unit = Decimal(str(item.required_quantity)), canonical_measure_code(item.unit)
        groups.setdefault((product.id, unit, item.substituted_for), []).append((item, quantity, product))
    prepared = []
    for (product_id, unit, _), members in groups.items():
        with localcontext() as arithmetic:
            arithmetic.prec = 130
            quantity = sum((amount for _, amount, _ in members), Decimal(0))
        if not quantity.is_finite() or not 0 < quantity <= MAX_STORED_QUANTITY:
            continue
        first = members[0][0]
        if len(members) > 1 or first.unit != unit or first.required_quantity != quantity:
            prepared.append((members, quantity, unit))
    if not prepared:
        return False
    offers = await load_regional_offers(db, ids, shopping.store_id)
    for members, quantity, unit in prepared:
        first, _, product = members[0]
        apply_regional_item_quote(first, product=product, store_id=shopping.store_id,
            quantity=quantity, unit=unit, offers=offers, as_of=regional_pricing_date())
        for duplicate, _, _ in members[1:]:
            shopping.items.remove(duplicate)
    await db.flush()
    return True
