"""Synthetic reviewed retailer evidence; no real price/stock assertions or IO."""

from datetime import datetime, timezone
from uuid import uuid4

from app.db.uk_product_catalog import UKProductProposal
from app.db.uk_store_catalog import UK_STORES
from app.models import Store
from app.models.regional_product_offer import RegionalProductOffer


_DOMAINS = dict(zip(
    ("tesco", "sainsburys", "asda", "aldi", "morrisons", "lidl", "co-op", "waitrose", "iceland", "ocado"),
    ("tesco.com", "sainsburys.co.uk", "asda.com", "aldi.co.uk", "morrisons.com", "lidl.co.uk", "coop.co.uk", "waitrose.com", "iceland.co.uk", "ocado.com"),
))


def uk_store(db, *, slug=None):
    definitions = [item for item in UK_STORES if slug is None or item.slug == slug]
    for definition in definitions:
        existing = db.get(Store, definition.id)
        if existing is None:
            shop = Store(id=definition.id, name=definition.name, country_code="GB", currency_code="GBP")
            db.add(shop)
            db.flush()
            return shop
    if slug is not None:
        return db.get(Store, definitions[0].id)
    raise ValueError("Synthetic test exhausted known UK stores")


def reviewed_offer(db, product, shop, *, quantity="500", unit="g", price="2.00",
                   status="available_online", kind="observed", checked=None, sku=None):
    definition = next(item for item in UK_STORES if item.id == shop.id)
    now = datetime.now(timezone.utc)
    checked = checked or now.date()
    sku = sku or f"synthetic-{uuid4().hex}"
    source = {"url": f"https://www.{_DOMAINS[definition.slug]}/synthetic/{sku}",
              "publisher": "Synthetic integration fixture", "checked_on": checked.isoformat()}
    proposal = UKProductProposal.model_validate({
        "retailer_slug": definition.slug, "retailer_sku": sku,
        "canonical_product_id": product.id, "name_en": f"Synthetic {product.name}",
        "package": {"quantity": quantity, "unit": unit, "source": source},
        "price": {"amount": price, "kind": kind, "source": source,
                  "estimate_reason": "Synthetic local estimate for testing" if kind == "estimate" else None},
        "availability_status": status, "availability_source": source,
    })
    row = RegionalProductOffer(
        id=proposal.proposal_id, store_id=shop.id, product_id=product.id,
        country_code="GB", currency_code="GBP", retailer_sku=sku,
        name_en=proposal.name_en, package_quantity=proposal.package.quantity,
        package_unit=unit, price=proposal.price.amount, price_kind=kind,
        estimate_reason=proposal.price.estimate_reason,
        package_source=source.copy(), price_source=source.copy(), availability_source=source.copy(),
        availability_scope="online_catalogue", availability_status=status,
        reviewed_by_user_id=None, reviewed_at=now, fingerprint=proposal.fingerprint,
    )
    db.add(row)
    db.flush()
    return row
