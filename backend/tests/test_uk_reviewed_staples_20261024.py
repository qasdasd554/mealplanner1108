"""Reviewed real OFF staple batches; local transactions, no live IO."""

from copy import deepcopy
from datetime import datetime, timezone
import json
from pathlib import Path
from uuid import UUID

import pytest
from sqlalchemy import func, select

from app.db.seed import NUTRITION_DATA, PRODUCTS_DATA
from app.models import OffCatalogueProduct, Product, RegionalProductOffer
from app.services.off_availability import off_available_product_ids
from app.services.off_catalogue import catalogue_values, import_off_catalogue
from app.services.off_ingredient_mapping import import_reviewed_off_mappings
from app.services.product_measures import build_measure_options
from tests.test_uk_catalogue_import import AsyncAdapter, catalogue_db
from tests.test_regional_shopping import run


DAY = datetime(2026, 10, 24, 18, tzinfo=timezone.utc)


@pytest.fixture(params=["off_uk_staples_20261024.json", "off_uk_priority_staples_20261024.json", "off_uk_cooking_staples_20261024.json"])
def packet(request):
    return json.loads((Path(__file__).parent / "fixtures" / request.param).read_text(encoding="utf-8"))


def test_current_staples_bind_without_replacing_polish_product_facts(catalogue_db, packet):
    session, reviewer, _ = catalogue_db
    adapter = AsyncAdapter(session)
    seeds = {row[0]: row for row in PRODUCTS_DATA}
    products = []
    for proposal in packet["proposals"]:
        seed = seeds[proposal["product_name"]]
        product = Product(id=UUID(proposal["product_id"]), name=seed[0],
            unit=seed[1], brand=proposal["product_brand"], default_quantity=seed[2],
            serving_quantity=None, review_status="approved",
            nutrition_per_100=deepcopy(NUTRITION_DATA[seed[0]]),
            measure_options=build_measure_options(seed[0], seed[1], seed[2], None))
        products.append(product)
        session.add(product)
    session.commit()
    original = {row.id: (row.name, row.brand, row.unit, row.default_quantity,
        row.serving_quantity, deepcopy(row.nutrition_per_100), deepcopy(row.measure_options))
        for row in products}
    for record in packet["products"]:
        assert record["http_status"] == 200
        at = datetime.fromisoformat(record["retrieved_at"])
        facts = catalogue_values(record["product"], retrieved_at=at)
        assert facts is not None and facts["fingerprint"] == record["fingerprint"]
        assert run(import_off_catalogue(adapter, [record["product"]], retrieved_at=at)) == 1
    session.commit()
    ids = set(original)
    assert run(off_available_product_ids(adapter, ids, as_of=DAY.date())) == set()
    result = run(import_reviewed_off_mappings(adapter, packet["proposals"],
        reviewer_user_id=reviewer, reviewed_at=DAY, as_of=DAY.date()))
    assert result.created == len(packet["proposals"]) and result.updated == 0
    assert run(off_available_product_ids(adapter, ids, as_of=DAY.date())) == ids
    assert {row.id: (row.name, row.brand, row.unit, row.default_quantity,
        row.serving_quantity, row.nutrition_per_100, row.measure_options)
        for row in products} == original
    assert session.scalar(select(func.count()).select_from(RegionalProductOffer)) == 0
    if packet.get("review_batch") == "cooking-20261024":
        assert session.get(OffCatalogueProduct, "5010251868095").package_quantity is None
        assert session.get(OffCatalogueProduct, "5000128271165").package_quantity is None
        assert session.get(OffCatalogueProduct, "5000232852908").package_quantity == 1000
    elif "excluded_queries" not in packet:
        eggs = session.get(OffCatalogueProduct, "5060286261408")
        onions = session.get(OffCatalogueProduct, "00287432")
        assert eggs.package_quantity is None  # Six eggs are not six grams.
        assert onions.package_quantity is None  # No made-up 100 g fallback.
    session.rollback()
    assert run(off_available_product_ids(adapter, ids, as_of=DAY.date())) == set()


def test_packet_has_distinct_reviewed_canonical_identities_and_no_prices(packet):
    assert packet["automatic_import"] is False and packet["licence"] == "ODbL-1.0"
    proposals = packet["proposals"]
    expected_count = 7 if packet.get("review_batch") == "cooking-20261024" else 9
    assert len({row["product_id"] for row in proposals}) == expected_count
    assert len({row["off_barcode"] for row in proposals}) == expected_count
    expected = {
        "Cebula", "Marchew", "Ziemniaki", "Mąka pszenna", "Płatki owsiane",
        "Jajka", "Cukier", "Pieprz czarny mielony", "Sól",
    }
    if packet.get("review_batch") == "cooking-20261024":
        expected = {"Pierś z kurczaka", "Olej rzepakowy", "Ser żółty gouda", "Miód",
            "Ogórek", "Papryka czerwona", "Parmezan"}
        assert set(packet["excluded_queries"]) == {"vegetable stock cubes"}
    elif "excluded_queries" in packet:
        expected = {"Oliwa z oliwek", "Pomidory", "Czosnek", "Chleb pszenny", "Awokado",
            "Makaron penne", "Cytryna", "Sałata lodowa", "Banan"}
        assert set(packet["excluded_queries"]) == {"chicken breast", "rapeseed oil", "vegetable stock"}
    assert {row["product_name"] for row in proposals} == expected
    for record in packet["products"]:
        assert record["barcode_requested"] == record["product"]["code"]
        assert "price" not in record and "price" not in record["product"]
        assert "en:united-kingdom" in record["product"]["countries_tags"]
