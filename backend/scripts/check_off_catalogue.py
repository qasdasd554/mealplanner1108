"""Read-only live OFF UK sample: one bounded HTTP request, no database writes."""

import argparse
from datetime import datetime, timezone
import json

import httpx

from app.services.barcode_lookup import USER_AGENT
from app.services.off_catalogue import catalogue_values


def check_sample(size: int = 30) -> dict:
    if not 1 <= size <= 100:
        raise ValueError("Use a sample size between 1 and 100")
    endpoint = "https://world.openfoodfacts.org/api/v2/search"
    fields = ("code,product_name_en,product_name,brands,countries_tags,stores,"
              "quantity,product_quantity,product_quantity_unit,nutriments,"
              "nutrition_data_per,last_modified_t,obsolete")
    response = httpx.get(endpoint, params={
        "countries_tags_en": "united-kingdom", "fields": fields, "page_size": size,
    }, headers={"User-Agent": USER_AGENT}, timeout=25)
    response.raise_for_status()
    payload = response.json()
    now = datetime.now(timezone.utc)
    rows = [value for raw in payload.get("products", [])
            if (value := catalogue_values(raw, retrieved_at=now)) is not None]
    if not rows:
        raise ValueError("No validated UK products in the live sample")
    return {
        "source": "Open Food Facts contributors", "licence": "ODbL-1.0",
        "checked_at": now.isoformat(), "matching_records_reported_by_api": payload.get("count"),
        "sample_received": len(payload.get("products", [])), "sample_validated": len(rows),
        "with_complete_macros": sum(all(x is not None for x in row["nutrition_per_100"].values()) for row in rows),
        "with_known_package": sum(row["package_quantity"] is not None for row in rows),
        "with_community_reported_stores": sum(bool(row["reported_stores"]) for row in rows),
        "prices_or_stock_created": 0,
    }


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sample-size", type=int, default=30)
    args = parser.parse_args()
    print(json.dumps(check_sample(args.sample_size), indent=2))
