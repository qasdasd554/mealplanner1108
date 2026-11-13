"""PL manual purchases use compatible units and whole-package prices."""

from decimal import Decimal, ROUND_CEILING

from fastapi import HTTPException
from sqlalchemy import select

from app.core.language import account_text
from app.models import PantryItem, Product, Store, StoreProduct
from app.services.polish_list_prices import _amount, _base_quantity, _package_count, offer_package
from app.services.regional_requirements import MAX_STORED_QUANTITY, canonical_measure_code


def stored_amount(value):
    amount = _amount(value).quantize(Decimal("0.001"), rounding=ROUND_CEILING)
    if amount > MAX_STORED_QUANTITY:
        raise ValueError("Quantity exceeds storage limits")
    return amount


def product_amount(product, quantity, unit):
    """Prefer explicit g/ml factors; an unresolved measure stays in its own unit."""
    amount = _amount(quantity)
    try:
        amount, unit = _base_quantity(product, amount, unit)
    except ValueError:
        unit = canonical_measure_code(unit)
    return stored_amount(amount), unit


def combined_amount(product, left, left_unit, right, right_unit):
    left, left_unit = product_amount(product, left, left_unit)
    right, right_unit = product_amount(product, right, right_unit)
    if left_unit != right_unit:
        raise ValueError("The units cannot be combined safely")
    return stored_amount(left + right), left_unit


def item_price(product, offer, quantity, unit, *, package_price=None):
    """Unknown pack conversion is an unknown cost, never a single-pack price."""
    try:
        count = _package_count(product, quantity, unit, offer=offer)
        price = Decimal(str(offer.price if package_price is None else package_price)) * count
        if not price.is_finite() or not 0 <= price <= Decimal("99999999.99"):
            return None
        return price.quantize(Decimal("0.01"))
    except (ValueError, ArithmeticError, TypeError):
        return None


async def open_german_item_prices(db, lists, *, item_id=None) -> dict:
    """Refresh displayed costs in one query, preserving saved purchases."""
    from app.services.retailer_promotion_queue import german_retailer_prices

    items = [
        item for shopping in lists
        if getattr(shopping.store, "country_code", None) == "DE" and shopping.status in {"pending", "in_progress"}
        for item in shopping.items if not item.is_checked and not item.is_from_pantry
        and item.store_product is not None and item.store_product.store_id == shopping.store_id
        and (item_id is None or item.id == item_id)
    ]
    prices = await german_retailer_prices(db, (item.store_product for item in items))
    costs = {}
    for item in items:
        offer = item.store_product
        costs[item.id] = item_price(
            offer.product, offer, item.required_quantity, item.unit, package_price=prices.get(offer.id),
        ) if offer.is_available and offer.withdrawn_at is None else None
    return costs


async def complete_polish_items_to_pantry(db, shopping, user):
    """Validate the whole transfer before touching any pantry rows."""
    purchases = {}
    try:
        for item in shopping.items:
            if not item.is_checked or item.is_from_pantry or item.store_product is None:
                continue
            product = item.store_product.product
            if product is None:
                raise ValueError("Missing product")
            quantity, unit = product_amount(product, item.required_quantity, item.unit)
            try:
                # A priced purchase represents complete packages, just as in GB.
                # Without a reliable pack conversion, retain the stated amount.
                packs = _package_count(product, item.required_quantity, item.unit, offer=item.store_product)
                pack_size, pack_unit = offer_package(product, item.store_product)
            except (ValueError, ArithmeticError, TypeError):
                pass
            else:
                quantity, unit = product_amount(product, pack_size * packs, pack_unit)
            if product.id in purchases:
                _, old, old_unit = purchases[product.id]
                quantity, unit = combined_amount(product, old, old_unit, quantity, unit)
            purchases[product.id] = (product, quantity, unit)

        if not purchases:
            return 0
        existing_rows = (await db.execute(select(PantryItem).where(
            PantryItem.user_id == user.id, PantryItem.product_id.in_(purchases),
        ).with_for_update())).scalars().all()
        existing = {row.product_id: row for row in existing_rows}
        prepared = []
        for product_id, (product, quantity, unit) in purchases.items():
            row = existing.get(product_id)
            if row is not None:
                if row.quantity is None:
                    raise ValueError("Unknown existing pantry quantity")
                if row.quantity != 0:
                    quantity, unit = combined_amount(product, row.quantity, row.unit, quantity, unit)
            prepared.append((product_id, row, quantity, unit))
    except (ValueError, ArithmeticError, TypeError) as exc:
        raise HTTPException(status_code=409, detail=account_text(user,
            "Nie można bezpiecznie połączyć ilości ze spiżarnią. Popraw ilość lub jednostkę albo zakończ bez przenoszenia zakupów.",
            "These quantities cannot be safely combined with your pantry. Correct the amount or unit, or finish without moving purchases.",
        )) from exc

    for product_id, row, quantity, unit in prepared:
        if row is None:
            row = PantryItem(user_id=user.id, product_id=product_id)
            db.add(row)
        row.quantity, row.unit = quantity, unit
    return len(prepared)


async def refresh_polish_items(db, shopping, store_id):
    """Reprice open purchases in their target shop; bought food is history."""
    from app.services.polish_list_prices import quote_polish_list
    store = await db.get(Store, store_id)
    quoted = (await quote_polish_list(db, shopping, [store]))[store_id]
    for item, offer, quote in quoted:
        if item.is_checked or item.is_from_pantry:
            continue
        apply_polish_item_quote(item, offer, quote, country_code=getattr(store, "country_code", "PL"))
    return (None if any(quote is None for _, _, quote in quoted) else
        sum((Decimal(str(quote["price_in_store"])) for _, _, quote in quoted), Decimal(0)))


def apply_polish_item_quote(item, offer, quote, *, country_code):
    if offer is not None and quote is not None:
        item.store_product_id, item.store_product = offer.id, offer
        item.department_id, item.department = offer.department_id, offer.department
        item.estimated_price = Decimal(str(quote["price_in_store"]))
        if country_code == "DE":
            item.catalogue_product_id = None
            item.custom_name = None
        return

    if country_code == "DE" and item.store_product is not None:
        from app.services.system_content_language import ingredient_display_name
        item.catalogue_product_id = item.store_product.product_id
        item.custom_name = ingredient_display_name(item.store_product.product, country_code="DE")[:200]
        item.store_product_id, item.store_product = None, None
    item.department_id, item.department = None, None
    item.estimated_price = None


async def preserve_polish_purchases(db, old_items, new_items):
    """Retain an unchanged bought requirement, or stop before deleting history."""
    from sqlalchemy.orm import joinedload
    bought = [row for row in old_items if row.is_generated and row.is_checked and not row.is_from_pantry]
    if not bought:
        return
    ids = {row.store_product_id for row in bought if row.store_product_id is not None}
    ids.update(row["store_product_id"] for row in new_items if row.get("store_product_id") is not None)
    offers = {row.id: row for row in (await db.execute(select(StoreProduct)
        .where(StoreProduct.id.in_(ids)).options(joinedload(StoreProduct.product)))).scalars().unique().all()} if ids else {}

    fallback_ids = {item.catalogue_product_id for item in bought if item.catalogue_product_id is not None}
    fallback_ids.update(row["catalogue_product_id"] for row in new_items if row.get("catalogue_product_id") is not None)
    products = {product.id: product for product in (await db.execute(
        select(Product).where(Product.id.in_(fallback_ids))
    )).scalars().all()} if fallback_ids else {}

    def key(offer_id, catalogue_product_id, name, quantity, unit):
        offer = offers.get(offer_id)
        product = offer.product if offer is not None else products.get(catalogue_product_id)
        if product is not None:
            quantity, unit = product_amount(product, quantity, unit)
            return ("product", product.id, quantity, unit)
        return ("custom", (name or "").strip().casefold(), stored_amount(quantity), canonical_measure_code(unit))

    history = {}
    try:
        for row in bought:
            identity = key(row.store_product_id, row.catalogue_product_id, row.custom_name, row.required_quantity, row.unit)
            history.setdefault(identity, []).append(row)
        for data in new_items:
            if data.get("is_from_pantry"):
                continue
            identity = key(data.get("store_product_id"), data.get("catalogue_product_id"), data.get("custom_name"),
                           data["required_quantity"], data["unit"])
            matches = history.get(identity, [])
            if matches:
                row = matches.pop(0)
                data.update({name: getattr(row, name) for name in (
                    "store_product_id", "catalogue_product_id", "custom_name", "department_id", "required_quantity", "unit",
                    "estimated_price", "substituted_for")})
                data["is_checked"] = True
        if any(rows for rows in history.values()):
            raise ValueError("The bought requirement changed")
    except (ValueError, ArithmeticError, TypeError) as exc:
        raise HTTPException(status_code=409, detail=(
            "Zmieniły się składniki lub ilości kupionej pozycji. Popraw jej stan zakupu przed przeliczeniem listy."
        )) from exc
