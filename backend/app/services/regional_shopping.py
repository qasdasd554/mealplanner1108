"""UK shopping snapshots: explicit quantities, local packs and honest unknowns."""

from copy import deepcopy
from datetime import date, datetime, timezone
from decimal import Decimal, ROUND_CEILING
import re
from typing import Iterable
from urllib.parse import urlsplit
from uuid import UUID

from sqlalchemy import select

from app.models import MealPlan, PantryItem, Product, RegionalProductOffer, ShoppingListItem, ShoppingListItemRegionalSnapshot, Store
from fastapi import HTTPException
from app.db.uk_product_catalog import CatalogueEvidence, _RETAILER_DOMAINS
from app.db.uk_store_catalog import UK_STORES
from app.services.regional_offer_pricing import RegionalOfferQuote, select_uk_offer_quote
from app.services.regional_requirements import to_regional_base_quantity, MAX_STORED_QUANTITY
from app.services.uk_catalogue_import import canonical_base_unit


def regional_pricing_date():
    return datetime.now(timezone.utc).date()


async def load_regional_offers(db, product_ids, store_id):
    if not product_ids:
        return []
    result = await db.execute(select(RegionalProductOffer).where(
        RegionalProductOffer.store_id == store_id,
        RegionalProductOffer.product_id.in_(product_ids),
    ))
    return list(result.scalars().all())


def regional_product_id(item):
    snapshot = getattr(item, "regional_snapshot", None)
    if snapshot is not None:
        return snapshot.product_id
    return item.store_product.product_id if item.store_product is not None else None


def regional_snapshot_requirement(item):
    """Read a persisted g/ml requirement without canonical/PL reinterpretation."""
    snapshot = getattr(item, "regional_snapshot", None)
    try:
        if (snapshot is None or snapshot.country_code != "GB" or snapshot.currency_code != "GBP"
                or not isinstance(snapshot.product_id, UUID) or snapshot.required_unit not in {"g", "ml"}
                or item.unit != snapshot.required_unit):
            return None
        quantity = _frozen_decimal(snapshot.required_quantity)
        if quantity > MAX_STORED_QUANTITY or quantity != _frozen_decimal(item.required_quantity):
            return None
        return snapshot.product_id, quantity, snapshot.required_unit
    except (ValueError, TypeError, ArithmeticError):
        return None


def _frozen_decimal(value):
    if value is None or isinstance(value, (bool, float)):
        raise ValueError("An exact stored decimal is required")
    amount = Decimal(value)
    if not amount.is_finite() or amount <= 0:
        raise ValueError("A positive finite stored decimal is required")
    if len(amount.as_tuple().digits) > 32 or abs(amount.as_tuple().exponent) > 12:
        raise ValueError("Stored decimal precision is outside the supported range")
    return amount


def frozen_regional_purchase_quote(item, *, as_of=None):
    """Validate a bought package as HISTORY, not as today's available offer.

    This pure helper never reloads/reprices an offer. In particular, a checked
    Tesco package stays Tesco after the remaining list moves to another shop.
    Offer deletion or evidence age must not erase a recorded purchase.
    """
    snapshot = getattr(item, "regional_snapshot", None)
    requirement = regional_snapshot_requirement(item)
    try:
        if requirement is None or not item.is_checked or item.is_from_pantry or snapshot.quote_status != "quoted":
            return None
        product_id, quantity, unit = requirement
        data = snapshot.quote_data
        if not isinstance(data, dict) or type(snapshot.pricing_as_of) is not date:
            return None
        today = as_of or regional_pricing_date()
        if type(today) is not date or snapshot.pricing_as_of > today:
            return None
        store = next((value for value in UK_STORES if value.id == snapshot.store_id), None)
        if store is None or not re.fullmatch(r"[0-9a-f]{64}", str(data.get("offer_fingerprint", ""))):
            return None
        source = CatalogueEvidence.model_validate(data.get("price_source"))
        host = urlsplit(source.url).hostname or ""
        if source.checked_on > snapshot.pricing_as_of or not any(
            host == domain or host.endswith("." + domain) for domain in _RETAILER_DOMAINS[store.slug]
        ):
            return None
        offer_id = UUID(str(data.get("offer_id")))
        if snapshot.offer_id is not None and snapshot.offer_id != offer_id:
            return None
        count = data.get("package_count")
        package = _frozen_decimal(data.get("package_quantity"))
        purchased = _frozen_decimal(data.get("purchased_quantity"))
        price = _frozen_decimal(data.get("price_per_package"))
        total = _frozen_decimal(data.get("total_price"))
        if (type(count) is not int or not 1 <= count <= 9_999_999_999 or data.get("package_unit") != unit
                or not isinstance(snapshot.name_en, str) or not snapshot.name_en.strip()
                or package > Decimal("999999.999") or package != package.quantize(Decimal("0.001"))
                or purchased > MAX_STORED_QUANTITY
                or package * count != purchased or purchased < quantity
                or price != price.quantize(Decimal("0.01")) or total > Decimal("99999999.99")
                or price * count != total or total != _frozen_decimal(item.estimated_price)
                or type(data.get("price_is_estimated")) is not bool
                or data.get("availability_scope") != "online_catalogue"
                or data.get("availability_status") != "available_online"):
            return None
        return RegionalOfferQuote(
            offer_id=offer_id, store_id=snapshot.store_id, product_id=product_id,
            name_en=snapshot.name_en, required_quantity=quantity, unit=unit,
            package_quantity=package, package_count=count, purchased_quantity=purchased,
            price_per_package=price, total_price=total, currency_code="GBP",
            price_is_estimated=data["price_is_estimated"],
            last_verified=None if data["price_is_estimated"] else source.checked_on,
            price_source=source.model_dump(mode="json"),
        )
    except (AttributeError, ValueError, TypeError, ArithmeticError):
        return None


def regional_pantry_coverage(product, quantity: Decimal, unit: str, pantry) -> Decimal:
    if pantry is None or pantry.quantity is None:
        return Decimal(0)
    try:
        available, pantry_unit = to_regional_base_quantity(product, pantry.quantity, pantry.unit)
    except ValueError:
        return Decimal(0)
    return min(quantity, available) if pantry_unit == unit else Decimal(0)


def _stored_quantity(value: Decimal) -> Decimal:
    # Never round a positive remainder down to zero or a whole package.
    if not value.is_finite() or value <= 0 or value > MAX_STORED_QUANTITY:
        raise ValueError("Shopping quantity exceeds the supported storage range")
    return value.quantize(Decimal("0.001"), rounding=ROUND_CEILING)


def resolve_manual_regional_quantity(product, quantity, unit, offers, store_id, as_of):
    """Manual 'one pack' means a validated local SKU, not the PL package."""
    if unit not in {"opak", "opakowanie", "package", "pack"}:
        try:
            return to_regional_base_quantity(product, quantity, unit)
        except ValueError:
            return Decimal(str(quantity)), unit
    try:
        base_unit = canonical_base_unit(product)
        quote = select_uk_offer_quote(
            offers, product_id=product.id, store_id=store_id,
            quantity=Decimal("0.001"), unit=base_unit, as_of=as_of,
        )
    except ValueError:
        quote = None
    if quote is None:
        return Decimal(str(quantity)), unit
    return Decimal(str(quantity)) * quote.package_quantity, quote.unit


def apply_regional_item_quote(
    item, *, product, store_id, quantity, unit, offers: Iterable,
    as_of: date, from_pantry: bool = False,
):
    offers = list(offers)
    try:
        # Package quantities on a canonical PL product are not UK SKU proof.
        if unit in {"opak", "opakowanie", "package", "pack"}:
            raise ValueError("A local SKU package must be resolved explicitly")
        base_quantity, base_unit = to_regional_base_quantity(product, quantity, unit)
    except (ValueError, AttributeError):
        base_quantity, base_unit = None, None
    if base_quantity is not None:
        base_quantity = _stored_quantity(base_quantity)
    quote = None
    if base_quantity is not None and not from_pantry:
        quote = select_uk_offer_quote(
            offers, product_id=product.id, store_id=store_id,
            quantity=base_quantity, unit=base_unit, as_of=as_of,
        )
    matching = [offer for offer in offers if offer.product_id == product.id and offer.store_id == store_id]
    name = quote.name_en if quote else (matching[0].name_en if matching else product.name)
    snapshot = getattr(item, "regional_snapshot", None)
    if snapshot is None:
        snapshot = ShoppingListItemRegionalSnapshot(manual_extra_quantity=Decimal(0))
        item.regional_snapshot = snapshot
    snapshot.product_id = product.id
    snapshot.store_id = store_id
    snapshot.country_code, snapshot.currency_code = "GB", "GBP"
    snapshot.name_en = name[:300]
    snapshot.required_quantity = _stored_quantity(base_quantity) if base_quantity is not None else None
    snapshot.required_unit = base_unit
    snapshot.pricing_as_of = as_of
    if not getattr(item, "is_from_pantry", False):
        snapshot.purchase_is_checked = bool(getattr(item, "is_checked", False))
    snapshot.quote_status = "pantry" if from_pantry else "quoted" if quote else "unpriced"
    snapshot.offer_id = quote.offer_id if quote else None
    snapshot.quote_data = None
    if quote is not None:
        selected = next(offer for offer in matching if offer.id == quote.offer_id)
        snapshot.quote_data = {
            "offer_id": str(quote.offer_id), "offer_fingerprint": selected.fingerprint,
            "package_quantity": str(quote.package_quantity), "package_unit": quote.unit,
            "package_count": quote.package_count, "purchased_quantity": str(quote.purchased_quantity),
            "price_per_package": str(quote.price_per_package), "total_price": str(quote.total_price),
            "price_is_estimated": quote.price_is_estimated,
            "price_source": deepcopy(quote.price_source),
            "availability_status": selected.availability_status,
            "availability_scope": selected.availability_scope,
        }
    item.store_product_id = None
    item.store_product = None
    item.custom_name = name[:200]
    item.department_id, item.department = None, None
    item.required_quantity = _stored_quantity(base_quantity if base_quantity is not None else Decimal(str(quantity)))
    item.unit = base_unit if base_unit is not None else unit
    item.is_from_pantry = from_pantry
    item.estimated_price = Decimal(0) if from_pantry else quote.total_price if quote else None
    if from_pantry:
        item.is_checked = True
    return item


def copy_regional_snapshot(source, target):
    snapshot = getattr(source, "regional_snapshot", None)
    if snapshot is None:
        return
    target.regional_snapshot = ShoppingListItemRegionalSnapshot(**{
        column.name: deepcopy(getattr(snapshot, column.name))
        for column in ShoppingListItemRegionalSnapshot.__table__.columns
        if column.name != "item_id"
    })


async def refresh_regional_items(db, shopping_list, *, as_of=None):
    """Requote retained/manual items after store/amount changes, no PL fallback."""
    items = [item for item in shopping_list.items if getattr(item, "regional_snapshot", None) is not None]
    product_ids = {item.regional_snapshot.product_id for item in items if item.regional_snapshot.product_id}
    offers = await load_regional_offers(db, product_ids, shopping_list.store_id)
    result = await db.execute(select(Product).where(Product.id.in_(product_ids))) if product_ids else None
    products = {product.id: product for product in result.scalars().all()} if result is not None else {}
    for item in items:
        snapshot = item.regional_snapshot
        if item.is_checked and not item.is_from_pantry:
            # Purchased pack evidence belongs to its original store, not the
            # current destination for the remaining unchecked purchases.
            if frozen_regional_purchase_quote(item) is None:
                raise HTTPException(status_code=409, detail="The purchased package data need to be corrected before refreshing this list.")
            continue
        product = products.get(snapshot.product_id)
        if product is None:
            item.estimated_price = Decimal(0) if item.is_from_pantry else None
            snapshot.quote_status = "pantry" if item.is_from_pantry else "unpriced"
            snapshot.quote_data, snapshot.offer_id = None, None
            snapshot.store_id = shopping_list.store_id
            continue
        apply_regional_item_quote(
            item, product=product, store_id=shopping_list.store_id,
            quantity=item.required_quantity, unit=item.unit, offers=offers,
            as_of=as_of or regional_pricing_date(), from_pantry=item.is_from_pantry,
        )


async def refresh_regional_plan_budget(db, shopping_list):
    """Refresh only the transient GB plan summary, never persist a stale total."""
    store = await db.get(Store, shopping_list.store_id)
    if store is None or store.country_code != "GB":
        return
    await db.flush()
    result = await db.execute(select(ShoppingListItem.estimated_price).where(
        ShoppingListItem.shopping_list_id == shopping_list.id,
        ShoppingListItem.is_from_pantry.is_(False),
    ))
    values = list(result.scalars().all())
    total = None if any(value is None for value in values) else sum(values, Decimal(0))
    plan = await db.get(MealPlan, shopping_list.meal_plan_id)
    if plan is not None:
        plan.estimated_min_budget = total
    return total


async def complete_regional_items_to_pantry(db, shopping_list, user_id):
    """Preflight the ENTIRE checked batch before staging any pantry change."""
    purchases = {}
    for item in shopping_list.items:
        if not item.is_checked or item.is_from_pantry:
            continue
        snapshot = item.regional_snapshot
        if snapshot is None:
            if item.store_product_id is not None:
                raise HTTPException(status_code=409, detail="Refresh this shopping list before moving items to the pantry.")
            continue
        if snapshot.product_id is None or snapshot.required_quantity is None or snapshot.required_unit not in {"g", "ml"}:
            continue
        quantity = snapshot.required_quantity
        if snapshot.quote_status == "quoted":
            try:
                quantity = Decimal(str(snapshot.quote_data["purchased_quantity"]))
                package = Decimal(str(snapshot.quote_data["package_quantity"]))
                count = snapshot.quote_data["package_count"]
                if type(count) is not int or count < 1 or package * count != quantity or quantity < item.required_quantity:
                    raise ValueError("Invalid stored package snapshot")
            except (KeyError, TypeError, ValueError, ArithmeticError) as exc:
                raise HTTPException(status_code=409, detail="Refresh this shopping list before moving items to the pantry.") from exc
        if not quantity.is_finite() or quantity <= 0 or quantity > MAX_STORED_QUANTITY:
            raise HTTPException(status_code=409, detail="The purchased quantity cannot be stored safely in the pantry.")
        old, unit = purchases.get(snapshot.product_id, (Decimal(0), snapshot.required_unit))
        if unit != snapshot.required_unit:
            raise HTTPException(status_code=409, detail="Shopping units do not match.")
        purchases[snapshot.product_id] = (old + quantity, unit)

    if not purchases:
        return 0
    products = (await db.execute(select(Product).where(Product.id.in_(purchases)))).scalars().all()
    by_product = {product.id: product for product in products}
    existing_rows = (await db.execute(select(PantryItem).where(
        PantryItem.user_id == user_id, PantryItem.product_id.in_(purchases),
    ).with_for_update())).scalars().all()
    existing = {row.product_id: row for row in existing_rows}
    prepared = []
    for product_id, (quantity, unit) in purchases.items():
        product = by_product.get(product_id)
        if product is None:
            raise HTTPException(status_code=409, detail="A shopping product is no longer available. Refresh the list first.")
        row = existing.get(product_id)
        if row is not None:
            if row.quantity is None:
                raise HTTPException(status_code=409, detail=(
                    "Enter a quantity for the existing pantry item, or finish without moving items to the pantry."
                ))
            try:
                current, current_unit = (
                    (Decimal(0), unit) if row.quantity == 0
                    else to_regional_base_quantity(product, row.quantity, row.unit)
                )
            except ValueError as exc:
                raise HTTPException(status_code=409, detail="Correct the existing pantry quantity/unit first.") from exc
            if current_unit != unit:
                raise HTTPException(status_code=409, detail="Pantry and shopping units do not match.")
            quantity += current
        if quantity > MAX_STORED_QUANTITY:
            raise HTTPException(status_code=409, detail="The purchased quantity exceeds the pantry storage range.")
        prepared.append((product_id, row, quantity, unit))

    # No ORM assignment/add above this line: catching a 409 cannot commit part
    # of an earlier valid product. Caller still owns the encompassing commit.
    for product_id, row, quantity, unit in prepared:
        if row is None:
            row = PantryItem(user_id=user_id, product_id=product_id)
            db.add(row)
        row.quantity, row.unit = quantity, unit
    return len(prepared)
