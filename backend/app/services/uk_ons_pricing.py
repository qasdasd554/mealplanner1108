"""National averages for ingredient quantities, never a merchant SKU/pack."""
from dataclasses import dataclass
from datetime import date
from decimal import Decimal, ROUND_HALF_UP
import hashlib
import json
from uuid import UUID

from app.services.uk_national_price_reference import reference_dataset, estimate_reference_quantity, _reference_unit
from app.services.system_content_language import is_system_ingredient, ingredient_display_name
from app.services.uk_catalogue_import import canonical_base_unit


# Explicit food-category review, not fuzzy matching or substitution. These
# links only estimate cost; they never establish UK sale or change nutrition.
_LINKS = {
    "Płatki owsiane": "Oats or porridge", "Chleb pszenny": "Bread - sliced white",
    "Ryż basmati": "Rice - basmati or jasmine", "Makaron penne": "Pasta - dry",
    "Makaron spaghetti": "Pasta - dry", "Pierś z kurczaka": "Chicken - fillet or steak",
    "Mleko 2%": "Milk - cow's (semi-skimmed, fresh)",
    "Śmietana 18%": "Cream - pouring and cooking (e.g. single, whipping)",
    "Parmezan": "Cheese - parmesan and similar products", "Oliwa z oliwek": "Oil - olive",
    "Olej rzepakowy": "Oil - rapeseed", "Masło extra": "Butter - dairy (block or tub)",
    "Banan": "Bananas", "Pomidory": "Tomatoes", "Marchew": "Carrots",
    "Cebula": "Onions", "Ziemniaki": "Potatoes - white", "Cukier": "Sugar - white",
    "Miód": "Honey", "Brokuł": "Broccoli",
}


@dataclass(frozen=True)
class NationalReferenceQuote:
    product_id: UUID
    store_id: UUID
    name_en: str
    required_quantity: Decimal
    unit: str
    total_price: Decimal
    price_source: dict
    currency_code: str = "GBP"
    price_is_estimated: bool = True
    offer_id: None = None
    package_quantity: None = None
    package_count: None = None
    price_per_package: None = None
    last_verified: None = None

    @property
    def purchased_quantity(self):
        # Only the entered/checked amount is known, not a retail package.
        return self.required_quantity


def quote_national_requirement(product, quantity, unit, *, store_id, as_of):
    quote = _quote_ons_requirement(product, quantity, unit, store_id=store_id, as_of=as_of)
    if quote is not None:
        return quote
    from app.services.uk_catalogue_estimates import quote_static_requirement
    return quote_static_requirement(product, quantity, unit, store_id=store_id, as_of=as_of)


def _quote_ons_requirement(product, quantity, unit, *, store_id, as_of):
    if (product is None or product.review_status != "approved"
            or not is_system_ingredient(product) or product.name not in _LINKS
            or type(as_of) is not date or unit not in {"g", "ml"}):
        return None
    data = reference_dataset()
    try:
        if canonical_base_unit(product) != unit:
            return None
        source_day = date.fromisoformat(data["retrieved_on"])
        label = _LINKS[product.name]
        row, = [row for row in data["records"] if row["name"] == label]
        period = date.fromisoformat(row["period"] + "-01")
        if not 0 <= (as_of - period).days <= 120:
            return None
        estimate = estimate_reference_quantity(label, quantity, unit, as_of=as_of)
        if estimate is None or not 0 < estimate.cost_gbp <= Decimal("99999999.99"):
            return None
        source = {"provider": "ons_national_average", "url": data["source_url"],
            "publisher": data["publisher"], "checked_on": source_day.isoformat(),
            "period": row["period"], "reference_name": label,
            "reference_unit": row["reference_unit"], "reference_price_gbp": row["price_gbp"],
            "dataset_sha256": data["source_sha256"], "licence": "OGL-3.0",
            "basis": "required_quantity_not_shop_price", "confirms_package": False,
            "confirms_store_stock": False}
        return NationalReferenceQuote(product.id, store_id,
            ingredient_display_name(product, country_code="GB"), Decimal(quantity), unit,
            estimate.cost_gbp, source)
    except (ValueError, TypeError, ArithmeticError):
        return None


def reference_quote_data(quote):
    body = {"price_basis": "national_quantity_reference", "product_id": str(quote.product_id),
        "name_en": quote.name_en, "required_quantity": str(quote.required_quantity),
        "required_unit": quote.unit, "total_price": str(quote.total_price),
        "price_is_estimated": True, "price_source": quote.price_source}
    body["reference_fingerprint"] = _fingerprint(body)
    return body


def _fingerprint(body):
    return hashlib.sha256(json.dumps(body, sort_keys=True, separators=(",", ":"),
        ensure_ascii=False, allow_nan=False).encode()).hexdigest()


def frozen_national_reference(item, *, as_of):
    """Preserve a checked quantity estimate, not a current store offer.

    Validate frozen arithmetic/source/identity without replacing it by newer
    price data. This is not proof of actual amount paid or a package bought.
    """
    snapshot = getattr(item, "regional_snapshot", None)
    if (snapshot is not None and isinstance(snapshot.quote_data, dict)
            and (snapshot.quote_data.get("price_source") or {}).get("provider") == "uk_catalogue_estimate"):
        from app.services.uk_catalogue_estimates import frozen_static_reference
        return frozen_static_reference(item, as_of=as_of)
    try:
        body = dict(snapshot.quote_data)
        fingerprint = body.pop("reference_fingerprint")
        source = body["price_source"]
        amount, total = Decimal(body["required_quantity"]), Decimal(body["total_price"])
        reference = _reference_unit(source["reference_unit"])
        period = date.fromisoformat(source["period"] + "-01")
        checked = date.fromisoformat(source["checked_on"])
        if (set(body) != {"price_basis", "product_id", "name_en", "required_quantity",
                    "required_unit", "total_price", "price_is_estimated", "price_source"}
                or snapshot.country_code != "GB" or snapshot.currency_code != "GBP"
                or not item.is_checked or item.is_from_pantry or snapshot.quote_status != "quoted"
                or snapshot.offer_id is not None or type(as_of) is not date
                or snapshot.pricing_as_of > as_of or not period <= checked <= snapshot.pricing_as_of
                or body["price_basis"] != "national_quantity_reference"
                or body["product_id"] != str(snapshot.product_id) or body["name_en"] != snapshot.name_en
                or body["required_unit"] != snapshot.required_unit or item.unit != snapshot.required_unit
                or snapshot.required_unit not in {"g", "ml"}
                or not amount.is_finite() or not 0 < amount <= Decimal("9999999.999")
                or amount != snapshot.required_quantity or amount != item.required_quantity
                or not total.is_finite() or not 0 < total <= Decimal("99999999.99")
                or total != item.estimated_price or body["price_is_estimated"] is not True
                or fingerprint != _fingerprint(body) or source["provider"] != "ons_national_average"
                or source["url"] != reference_dataset()["source_url"]
                or source["publisher"] != "Office for National Statistics"
                or source["licence"] != "OGL-3.0" or source["reference_name"] not in _LINKS.values()
                or source["basis"] != "required_quantity_not_shop_price"
                or source["confirms_package"] is not False or source["confirms_store_stock"] is not False
                or reference is None or reference[1] != snapshot.required_unit):
            return None
        price = Decimal(source["reference_price_gbp"])
        if not price.is_finite() or price <= 0 or (price * amount / reference[0]).quantize(
                Decimal("0.01"), rounding=ROUND_HALF_UP) != total:
            return None
        return NationalReferenceQuote(snapshot.product_id, snapshot.store_id, snapshot.name_en,
            amount, snapshot.required_unit, total, source)
    except (AttributeError, ValueError, TypeError, ArithmeticError, KeyError):
        return None
