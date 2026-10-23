"""OFF country catalogue cache, separate from app/user and shop databases.

Only public product facts are stored. Community-reported shop names are NOT
reviewed availability and cannot create RegionalProductOffer/StoreProduct.
Import callers own transactions; no network or commits occur in this module.
"""

from datetime import datetime, timedelta, timezone
import hashlib
import json
import math
import re

from sqlalchemy import select
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.dialects.sqlite import insert as sqlite_insert

from app.models.off_catalogue_product import OffCatalogueProduct
from app.schemas.product import ProductNameSuggestion
from app.services.barcode_lookup import _result_from_off_product, normalize_barcode


def catalogue_values(product: object, *, retrieved_at: datetime) -> dict | None:
    if not isinstance(product, dict):
        return None
    if retrieved_at.tzinfo is None:
        raise ValueError("An explicit timezone-aware retrieval time is required")
    countries = product.get("countries_tags")
    if not isinstance(countries, list) or "en:united-kingdom" not in countries:
        return None
    if product.get("obsolete") in (True, 1, "1", "on"):
        return None
    code = product.get("code")
    if not isinstance(code, str) or re.fullmatch(r"[0-9]{8,14}", code) is None:
        return None
    if normalize_barcode(code) != code:
        return None
    modified = product.get("last_modified_t", 0)
    if (type(modified) is not int or modified < 0
            or modified > int(retrieved_at.timestamp()) + 86400):
        return None
    parsed = _result_from_off_product(product, country_code="GB")
    if parsed is None or len(parsed.name) > 300 or len(parsed.brand or "") > 200:
        return None
    nutrition = {"kcal": parsed.kcal_per_100, "protein": parsed.protein_per_100,
                 "fat": parsed.fat_per_100, "carbs": parsed.carbs_per_100}
    for key, value in nutrition.items():
        if value is not None and (not math.isfinite(value) or value > (2000 if key == "kcal" else 200)):
            nutrition[key] = None
    stores = product.get("stores")
    reported = list(dict.fromkeys(part.strip() for part in stores.split(",") if part.strip())) if isinstance(stores, str) else []
    values = {
        "barcode": code, "name": parsed.name, "brand": parsed.brand,
        "search_name": f"{parsed.name} {parsed.brand or ''}".strip().casefold(),
        "country_code": "GB", "base_unit": parsed.unit,
        "package_quantity": parsed.serving_quantity,
        "nutrition_per_100": nutrition,
        "reported_stores": [label[:200] for label in reported[:30]],
        "source_url": f"https://world.openfoodfacts.org/product/{code}",
        "source_modified_t": modified, "licence": "ODbL-1.0",
    }
    values["fingerprint"] = hashlib.sha256(json.dumps(
        values, sort_keys=True, ensure_ascii=False, separators=(",", ":"), allow_nan=False,
    ).encode()).hexdigest()
    values["retrieved_at"] = retrieved_at.astimezone(timezone.utc)
    return values


async def import_off_catalogue(db, products, *, retrieved_at: datetime) -> int:
    """Bounded upsert: older source revisions never overwrite newer ones."""
    if len(products) > 500:
        raise ValueError("Import at most 500 OFF products per batch")
    unique = {}
    for raw in products:
        values = catalogue_values(raw, retrieved_at=retrieved_at)
        if values is None:
            continue
        previous = unique.get(values["barcode"])
        if previous is None or values["source_modified_t"] > previous["source_modified_t"]:
            unique[values["barcode"]] = values
        elif (values["source_modified_t"] == previous["source_modified_t"]
              and values["fingerprint"] != previous["fingerprint"]):
            raise ValueError("Conflicting OFF contents for the same source revision")
    if not unique:
        return 0
    factory = sqlite_insert if db.get_bind().dialect.name == "sqlite" else pg_insert
    statement = factory(OffCatalogueProduct).values(list(unique.values()))
    statement = statement.on_conflict_do_update(
        index_elements=[OffCatalogueProduct.barcode],
        set_={name: getattr(statement.excluded, name) for name in next(iter(unique.values())) if name != "barcode"},
        where=((statement.excluded.source_modified_t > OffCatalogueProduct.source_modified_t)
               | ((statement.excluded.source_modified_t == OffCatalogueProduct.source_modified_t)
                  & (statement.excluded.fingerprint == OffCatalogueProduct.fingerprint))),
    )
    await db.execute(statement)
    return len(unique)


async def search_off_catalogue(db, query: str, *, country_code: str, limit: int,
                              now: datetime | None = None):
    """Local cache only. No per-keystroke fan-out, AI, shop or price inference."""
    normalized = " ".join(query.split()).casefold()
    if country_code != "GB" or len(normalized) < 2:
        return []
    literal = normalized.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")
    result = await db.execute(select(OffCatalogueProduct).where(
        OffCatalogueProduct.country_code == "GB",
        OffCatalogueProduct.retrieved_at >= (now or datetime.now(timezone.utc)) - timedelta(days=30),
        OffCatalogueProduct.search_name.like(f"%{literal}%", escape="\\"),
    ).order_by(OffCatalogueProduct.search_name, OffCatalogueProduct.barcode).limit(max(1, min(limit, 20))))
    return [ProductNameSuggestion(
        source="open_food_facts", name=row.name, brand=row.brand, barcode=row.barcode,
        unit=row.base_unit, serving_quantity=row.package_quantity,
        kcal_per_100=row.nutrition_per_100.get("kcal"),
        protein_per_100=row.nutrition_per_100.get("protein"),
        fat_per_100=row.nutrition_per_100.get("fat"),
        carbs_per_100=row.nutrition_per_100.get("carbs"),
    ) for row in result.scalars().all()]
