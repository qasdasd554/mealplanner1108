"""Validate small, reviewed Open Prices references without network/DB writes.

A receipt/price-tag observation is NOT an online retailer listing or current
stock. Only the explicit reviewed bridge can create a store-observation
proposal for the existing pricing pipeline, always as a labelled estimate.
There is no automatic feed or persistence here. Callers decode JSON prices with
parse_float=Decimal, provide an explicitly reviewed generic OFF mapping and
the current canonical/cache records. No fuzzy product or retailer matching.
"""

from collections.abc import Mapping
from dataclasses import dataclass
from datetime import date, datetime, timedelta, timezone
from decimal import Decimal, InvalidOperation
from typing import Literal
from uuid import UUID

from app.db.uk_store_catalog import UK_STORES
from app.services.barcode_lookup import normalize_barcode
from app.services.off_ingredient_mapping import OffMappingProposal
from app.services.system_content_language import is_system_ingredient
from app.services.uk_catalogue_import import canonical_base_unit


_RETAILER_BRANDS = {
    "tesco": "tesco", "sainsbury's": "sainsburys", "sainsburys": "sainsburys",
    "asda": "asda", "aldi": "aldi", "morrisons": "morrisons", "lidl": "lidl",
    "co-op": "co-op", "the co-operative food": "co-op", "waitrose": "waitrose",
    "iceland": "iceland", "ocado": "ocado",
}
_STORES = {row.slug: row.id for row in UK_STORES}
_MAX_AGE_DAYS = 30


@dataclass(frozen=True, slots=True)
class OpenPricesReference:
    product_id: UUID
    observed_gtin: str
    retailer_slug: str
    store_id: UUID
    name_en: str
    amount: Decimal
    package_quantity: Decimal
    package_unit: Literal["g", "ml"]
    observed_on: date
    observation_id: int
    proof_id: int
    proof_type: Literal["RECEIPT", "PRICE_TAG"]
    source_url: str
    package_source_url: str
    package_checked_on: date
    off_fingerprint: str
    currency_code: Literal["GBP"] = "GBP"
    licence: Literal["ODbL-1.0"] = "ODbL-1.0"
    price_is_estimated: Literal[True] = True
    availability_scope: Literal["community_observation"] = "community_observation"
    current_stock_confirmed: Literal[False] = False


def _object(value):
    if not isinstance(value, Mapping):
        raise ValueError("An expanded Open Prices object is required")
    return value


def _identifier(value):
    if type(value) is not int or not 0 < value < 2**63:
        raise ValueError("A positive integer source identifier is required")
    return value


def _decimal(value):
    if not isinstance(value, (Decimal, str, int)) or isinstance(value, bool):
        raise ValueError("Decode source decimal numbers exactly, not as binary floats")
    try:
        amount = Decimal(value)
    except (InvalidOperation, ValueError) as exc:
        raise ValueError("A finite positive source number is required") from exc
    if not amount.is_finite() or amount <= 0 or len(amount.as_tuple().digits) > 16 or abs(amount.as_tuple().exponent) > 6:
        raise ValueError("A finite bounded positive source number is required")
    return amount


def _day(value):
    if not isinstance(value, str) or len(value) != 10:
        raise ValueError("An explicit source calendar date is required")
    return date.fromisoformat(value)


def _label(value):
    if not isinstance(value, str) or not value.strip() or len(value) > 300:
        raise ValueError("A bounded product/retailer label is required")
    return " ".join(value.split()).casefold()


def prepare_open_prices_reference(observation, *, mapping, off_product,
                                  canonical_product, as_of: date) -> OpenPricesReference:
    """Validate one observation without relaxing the existing offer schema.

    The trusted review is for generic food identity only, not a claim that the
    source SKU is the canonical Polish brand. Its local package/price remain
    attached to observed_gtin. Unknown drained quantity, density or local stock
    is not inferred. A later pricing adapter must handle package basis before
    using this reference to calculate how many packs fulfil a recipe.
    """
    if type(as_of) is not date:
        raise ValueError("An explicit review calendar date is required")
    row = _object(observation)
    product, location, proof = (_object(row.get(key)) for key in ("product", "location", "proof"))
    link = OffMappingProposal.model_validate(mapping)
    canonical = canonical_product
    try:
        if (canonical.id != link.product_id or canonical.name != link.product_name
                or canonical.unit != link.product_unit or canonical.brand != link.product_brand
                or canonical.review_status != "approved" or canonical.created_by_user_id is not None
                or canonical.barcode is not None
                or ((canonical.brand or "").strip() and not is_system_ingredient(canonical))):
            raise ValueError("A current approved generic ingredient identity is required")
        code = link.off_barcode
        if (normalize_barcode(code) != code or row.get("product_code") != code
                or product.get("code") != code or off_product.barcode != code
                or product.get("source") != "off" or off_product.country_code != "GB"
                or off_product.licence != "ODbL-1.0"
                or off_product.fingerprint != link.off_fingerprint
                or off_product.source_url != f"https://world.openfoodfacts.org/product/{code}"):
            raise ValueError("Exact, attributed UK OFF evidence must match the reviewed link")
        retrieved = off_product.retrieved_at
        if not isinstance(retrieved, datetime):
            raise ValueError("OFF retrieval time is required")
        retrieved_day = (retrieved.replace(tzinfo=timezone.utc) if retrieved.tzinfo is None
                         else retrieved.astimezone(timezone.utc)).date()
        if not 0 <= (as_of - retrieved_day).days <= _MAX_AGE_DAYS:
            raise ValueError("Current UK OFF evidence is required")
        base_unit = canonical_base_unit(canonical)
        if off_product.base_unit != base_unit or _label(product.get("product_name")) != _label(off_product.name):
            raise ValueError("Product label and dimension changed since source review")
        pack = _decimal(product.get("product_quantity"))
        unit = product.get("product_quantity_unit")
        if unit not in {"g", "kg", "ml", "l"}:
            raise ValueError("Source package needs explicit mass or volume")
        if unit in {"kg", "l"}:
            pack *= 1000
        unit = "g" if unit in {"g", "kg"} else "ml"
        if (unit != base_unit or pack > Decimal("999999.999")
                or pack != pack.quantize(Decimal("0.001"))
                or pack != _decimal(str(off_product.package_quantity))):
            raise ValueError("Package must match the current exact OFF SKU, not the Polish default pack")
    except (AttributeError, TypeError) as exc:
        raise ValueError("Complete canonical and OFF snapshots are required") from exc

    observation_id, product_id, location_id, proof_id = (
        _identifier(row.get(key)) for key in ("id", "product_id", "location_id", "proof_id"))
    if (row.get("type") != "PRODUCT" or row.get("currency") != "GBP"
            or row.get("duplicate_of") is not None or row.get("price_is_discounted") is not False
            or row.get("discount_type") is not None or row.get("price_without_discount") is not None
            # UNIT explicitly prices this exact packaged SKU. Per-kilogram
            # prices still cannot be mistaken for the whole pack's price.
            or row.get("price_per") not in (None, "UNIT")):
        raise ValueError("A non-discounted GBP price for one exact packaged food is required")
    amount = _decimal(row.get("price"))
    if amount > Decimal("99999999.99") or amount != amount.quantize(Decimal("0.01")):
        raise ValueError("Source price must be in whole GBP pennies without rounding")
    observed = _day(row.get("date"))
    if not 0 <= (as_of - observed).days <= _MAX_AGE_DAYS:
        raise ValueError("Observation is future-dated or too old; fetching does not refresh its price date")
    retailer = _RETAILER_BRANDS.get(_label(location.get("osm_brand")))
    if retailer is None or location.get("osm_address_country_code") != "GB":
        raise ValueError("An explicit recognised UK retailer location is required")
    if (_identifier(product.get("id")) != product_id
            or _identifier(location.get("id")) != location_id
            or _identifier(proof.get("id")) != proof_id
            or _identifier(proof.get("location_id")) != location_id):
        raise ValueError("Observation, product, location and proof identities do not agree")
    osm_id = _identifier(row.get("location_osm_id"))
    osm_type = row.get("location_osm_type")
    if (not isinstance(osm_type, str) or osm_type not in {"NODE", "WAY", "RELATION"}
            or _identifier(location.get("osm_id")) != osm_id
            or _identifier(proof.get("location_osm_id")) != osm_id
            or location.get("osm_type") != osm_type or proof.get("location_osm_type") != osm_type):
        raise ValueError("The proof must identify the same physical retailer location")
    proof_type = proof.get("type")
    if (not isinstance(proof_type, str) or proof_type not in {"RECEIPT", "PRICE_TAG"}
            or proof.get("draft") is not False
            or proof.get("currency") != "GBP" or _day(proof.get("date")) != observed):
        raise ValueError("A final, dated proof of this GBP observation is required")
    receipt_quantity = row.get("receipt_quantity")
    if (receipt_quantity is not None and _decimal(receipt_quantity) != 1) or (
            proof_type == "RECEIPT" and receipt_quantity is None):
        raise ValueError("Ambiguous multi-item receipts cannot define a one-package price")

    return OpenPricesReference(
        product_id=canonical.id, observed_gtin=code, retailer_slug=retailer,
        store_id=_STORES[retailer], name_en=off_product.name,
        amount=amount.quantize(Decimal("0.01")), package_quantity=pack, package_unit=unit,
        observed_on=observed, observation_id=observation_id, proof_id=proof_id,
        proof_type=proof_type, source_url=f"https://prices.openfoodfacts.org/prices/{observation_id}",
        package_source_url=off_product.source_url, package_checked_on=retrieved_day,
        off_fingerprint=off_product.fingerprint,
    )


def community_price_proposal(reference: OpenPricesReference, *, package_basis_note: str):
    """Explicit review bridge, not an automatic runtime feed or online claim.

    The reviewer must verify that the ingredient requirement and quoted pack
    both mean mass/volume as sold. Do not use this for unreviewed drained foods.
    Existing import_reviewed_uk_catalogue still enforces current DB admin role,
    transaction atomicity, approved canonical IDs, dimensions and source dates.
    """
    from app.db.uk_product_catalog import UKProductProposal
    if (not isinstance(reference, OpenPricesReference) or reference.currency_code != "GBP"
            or reference.price_is_estimated is not True or reference.current_stock_confirmed is not False
            or reference.availability_scope != "community_observation"
            or reference.store_id != _STORES.get(reference.retailer_slug)):
        raise ValueError("A validated community GBP reference is required")
    source = dict(url=reference.source_url, publisher="Open Prices (ODbL-1.0)",
        checked_on=reference.observed_on, provider="open_prices", observation_id=reference.observation_id,
        proof_id=reference.proof_id, proof_type=reference.proof_type, product_code=reference.observed_gtin,
        retailer_slug=reference.retailer_slug, licence=reference.licence,
        off_fingerprint=reference.off_fingerprint,
        package_basis="as_sold", package_basis_note=package_basis_note)
    return UKProductProposal.model_validate(dict(retailer_slug=reference.retailer_slug,
        retailer_sku=f"off-{reference.observed_gtin}", canonical_product_id=reference.product_id,
        name_en=reference.name_en,
        package=dict(quantity=reference.package_quantity, unit=reference.package_unit,
            source=dict(url=reference.package_source_url, publisher="Open Food Facts (ODbL-1.0)", checked_on=reference.package_checked_on)),
        price=dict(amount=reference.amount, kind="estimate", source=source,
            estimate_reason="Estimate from a dated community price observation; confirm the current price and availability in store."),
        availability_scope="store_observation", availability_status="reported_available", availability_source=source))
