"""Rollback-only UK migration/import smoke test on an explicitly confirmed branch.

Never run against production. Requires a separate env file and exact direct
hostname confirmation. Does not start FastAPI/workers, send mail, call AI or
commit data. Reports counts and pass/fail only, never secrets or user records.
"""

from __future__ import annotations

import argparse
import asyncio
from datetime import datetime, timedelta, timezone
from decimal import Decimal
import json
import os
from pathlib import Path
import ssl
from urllib.parse import urlsplit
from uuid import UUID, uuid4

from dotenv import dotenv_values
from sqlalchemy import text, select
from sqlalchemy.engine import make_url
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine


async def run(env_file: str, expected_host: str):
    raw = dotenv_values(env_file).get("DATABASE_URL", "")
    host = urlsplit(raw).hostname or ""
    if not expected_host or host != expected_host or "-pooler" in host or not host.endswith(".neon.tech"):
        raise ValueError("Explicit isolated direct Neon endpoint confirmation required")
    os.environ["ENVIRONMENT"] = "development"
    # Imported model metadata uses this driver, but only the locally owned
    # engine below opens connections. No application lifespan is invoked.
    url = make_url(raw).set(drivername="postgresql+asyncpg", query={})
    os.environ["DATABASE_URL"] = url.render_as_string(hide_password=False)
    from app import models
    from app.db.session import Base
    from app.db.market_schema import ensure_account_market_schema
    from app.db.store_market_schema import ensure_store_market_schema
    from app.db.campaign_market_schema import ensure_campaign_market_schema
    from app.db.regional_offer_evidence_schema import ensure_regional_offer_evidence_schema
    from app.db.uk_store_catalog import UK_STORES, seed_uk_stores
    from app.services.uk_catalogue_import import import_reviewed_uk_catalogue
    from app.services.regional_store_catalogue import list_reviewed_store_products
    from app.services.off_catalogue import import_off_catalogue, search_off_catalogue

    engine = create_async_engine(url, connect_args={
        "ssl": ssl.create_default_context(), "timeout": 20,
        "server_settings": {"application_name": "mealplanner-uk-rollback-smoke", "statement_timeout": "20000", "lock_timeout": "5000"},
    }, echo=False)
    report = {}
    tables = ("users", "stores", "products", "store_products", "recipes", "recipe_ingredients", "purchase_campaigns")
    excluded = "ARRAY['country_code','currency_code','submitted_country_code']::text[]"

    async def fingerprints(connection):
        result = {}
        for table in tables:
            # Identifiers are a hardcoded allowlist. Hash on the server, never
            # transfer private rows/photos/tokens from the cloned database.
            row = (await connection.execute(text(
                f"SELECT count(*), md5(string_agg(md5((to_jsonb(t) - {excluded})::text), '' ORDER BY id)) "
                f"FROM public.{table} t"
            ))).one()
            result[table] = tuple(row)
        return result

    try:
        async with engine.connect() as connection:
            report['baseline_database_bytes'] = (await connection.execute(text(
                'SELECT pg_database_size(current_database())'
            ))).scalar_one()
            before = await fingerprints(connection)
            initial_tables = set((await connection.execute(text(
                "SELECT tablename FROM pg_tables WHERE schemaname='public'"
            ))).scalars())
            await connection.rollback()
            transaction = await connection.begin()
            try:
                await connection.execute(text("SET LOCAL search_path = public"))
                await connection.run_sync(Base.metadata.create_all)
                # Reproduce the previous deployed constraints inside this
                # rollback-only transaction, not just a fresh ORM-created DB.
                for name in ("ck_regional_offer_evidence_kind", "ck_regional_offer_availability_status",
                             "ck_regional_offer_availability_scope", "ck_regional_offer_submission_evidence"):
                    await connection.execute(text(f"ALTER TABLE regional_product_offers DROP CONSTRAINT IF EXISTS {name}"))
                await connection.execute(text("ALTER TABLE regional_product_offers ADD CONSTRAINT ck_regional_offer_availability_status CHECK (availability_status IN ('available_online', 'out_of_stock', 'unknown'))"))
                await connection.execute(text("ALTER TABLE regional_product_offers ADD CONSTRAINT ck_regional_offer_availability_scope CHECK (availability_scope = 'online_catalogue')"))
                for _ in range(2):
                    await ensure_account_market_schema(connection)
                    await ensure_store_market_schema(connection)
                    await ensure_campaign_market_schema(connection)
                    await ensure_regional_offer_evidence_schema(connection)
                report["migration_idempotent"] = True
                report["legacy_regional_evidence_upgrade"] = True
                campaign_countries = (await connection.execute(text(
                    "SELECT count(*) FROM purchase_campaigns WHERE country_code <> 'PL' OR country_code IS NULL"
                ))).scalar_one()
                assert campaign_countries == 0
                report["existing_campaigns_preserved_pl"] = True
                countries = (await connection.execute(text(
                    "SELECT count(*) FROM users WHERE country_code <> 'PL' OR country_code IS NULL"
                ))).scalar_one()
                assert countries == 0, "Pre-existing accounts not all PL"
                async with connection.begin_nested() as savepoint:
                    try:
                        await connection.execute(text("UPDATE users SET country_code='GB' WHERE id=(SELECT id FROM users LIMIT 1)"))
                    except Exception as error:
                        assert getattr(error.orig, "sqlstate", None) == "23514"
                        await savepoint.rollback()
                        report["country_immutable"] = True
                    else:
                        raise AssertionError("Account country update was allowed")
                # Existing PL values must be bit-for-bit unchanged, excluding
                # only the new market columns whose PL defaults are intended.
                assert await fingerprints(connection) == before
                report["existing_pl_rows_unchanged"] = True

                async with AsyncSession(bind=connection, expire_on_commit=False) as session:
                    await seed_uk_stores(session)
                    await seed_uk_stores(session)
                    report["uk_store_count"] = (await session.execute(select(models.Store.id).where(models.Store.country_code == "GB"))).all().__len__()
                    assert report["uk_store_count"] == 10
                    reviewer = models.User(id=uuid4(), email=f"uk-rollback-{uuid4().hex}@example.invalid", password_hash="not-a-login", role="admin", country_code="PL")
                    product = models.Product(id=uuid4(), name="Synthetic migration oat fixture", unit="g", review_status="approved")
                    session.add_all([reviewer, product])
                    await session.flush()
                    now = datetime.now(timezone.utc)
                    sku = f"rollback-fixture-{uuid4().hex}"
                    source = {"url": f"https://www.tesco.com/synthetic/{sku}", "publisher": "Synthetic rollback test", "checked_on": now.date().isoformat()}
                    proposal = {
                        "retailer_slug": "tesco", "retailer_sku": sku,
                        "canonical_product_id": str(product.id), "name_en": "Synthetic test oats 750g",
                        "package": {"quantity": "750", "unit": "g", "source": source},
                        "price": {"amount": "1.25", "kind": "observed", "source": source},
                        "availability_status": "available_online", "availability_source": source,
                    }
                    first = await import_reviewed_uk_catalogue(session, [proposal], reviewer_user_id=reviewer.id, reviewed_at=now, as_of=now.date())
                    second = await import_reviewed_uk_catalogue(session, [proposal], reviewer_user_id=reviewer.id, reviewed_at=now, as_of=now.date())
                    assert (first.created, second.unchanged) == (1, 1)
                    rows = await list_reviewed_store_products(session, UK_STORES[0].id, skip=0, limit=10, search=sku, department_id=None, as_of=now.date())
                    # Search is display-name based, not a private fixture SKU.
                    assert rows == []
                    rows = await list_reviewed_store_products(session, UK_STORES[0].id, skip=0, limit=10, search="Synthetic test oats", department_id=None, as_of=now.date())
                    assert len(rows) == 1 and rows[0].package_quantity == 750 and rows[0].price == 1.25
                    report["asyncpg_import_retry_and_read"] = True
                    # Public product facts stay separate from store offers and
                    # existing app products, even when OFF reports a shop name.
                    off_fixture = {
                        "code": "5025125000006", "product_name_en": "Synthetic rollback yoghurt",
                        "countries_tags": ["en:united-kingdom"], "stores": "Tesco",
                        "product_quantity": 450, "product_quantity_unit": "g",
                        "last_modified_t": 1700000000,
                        "nutriments": {"energy-kcal_100g": 60, "proteins_100g": 4,
                                       "fat_100g": 2, "carbohydrates_100g": 6},
                    }
                    for _ in range(2):
                        await import_off_catalogue(session, [off_fixture], retrieved_at=now)
                    off_rows = await search_off_catalogue(session, "Synthetic rollback yoghurt", country_code="GB", limit=5)
                    assert len(off_rows) == 1 and off_rows[0].kcal_per_100 == 60
                    assert off_rows[0].price_min is None and off_rows[0].existing_product_id is None
                    report["off_facts_isolated_idempotent"] = True
                    for snapshot in (off_fixture,
                        {**off_fixture, "product_quantity": 500, "last_modified_t": 1700000100}):
                        await import_off_catalogue(session, [snapshot], retrieved_at=now - timedelta(hours=1))
                    preserved = (await session.execute(select(
                        models.OffCatalogueProduct.retrieved_at, models.OffCatalogueProduct.package_quantity,
                    ).where(models.OffCatalogueProduct.barcode == off_fixture["code"])) ).one()
                    assert preserved.retrieved_at == now and preserved.package_quantity == 450
                    assert await search_off_catalogue(session, "Synthetic rollback yoghurt", country_code="GB",
                        limit=5, now=now - timedelta(minutes=1)) == []
                    report["off_refresh_monotonic_pg"] = True
                    report["off_future_cache_hidden_pg"] = True
                    # Country-level OFF evidence executes on real PostgreSQL,
                    # not only SQLite. This does not create a retailer quote.
                    product.barcode = off_fixture["code"]
                    recipe = models.Recipe(id=uuid4(), name="Synthetic OFF availability",
                                           meal_type="obiad")
                    session.add(recipe)
                    await session.flush()
                    session.add(models.RecipeIngredient(
                        id=uuid4(), recipe_id=recipe.id, product_id=product.id,
                        quantity=100, unit="g", is_optional=False))
                    await session.flush()
                    from app.services.market_catalog import recipe_market_availability
                    visible = (await session.execute(select(models.Recipe.id).where(
                        models.Recipe.id == recipe.id, recipe_market_availability("GB"),
                    ))).scalar_one_or_none()
                    assert visible == recipe.id
                    report["off_country_availability_pg"] = True
                    # A generic ingredient has no invented GTIN. Review binds
                    # its current identity to an exact existing OFF revision.
                    from app.services.off_ingredient_mapping import import_reviewed_off_mappings
                    from app.services.off_availability import off_available_product_ids
                    generic = models.Product(id=uuid4(), name="Synthetic generic yoghurt",
                                             unit="g", review_status="approved")
                    generic_recipe = models.Recipe(id=uuid4(), name="Synthetic generic availability",
                                                   meal_type="obiad")
                    session.add_all([generic, generic_recipe])
                    await session.flush()
                    session.add(models.RecipeIngredient(id=uuid4(), recipe_id=generic_recipe.id,
                        product_id=generic.id, quantity=100, unit="g", is_optional=False))
                    await session.flush()
                    off = await session.get(models.OffCatalogueProduct, off_fixture["code"])
                    mapping = dict(product_id=generic.id, product_name=generic.name,
                        product_unit=generic.unit, off_barcode=off.barcode,
                        off_fingerprint=off.fingerprint,
                        review_note="Synthetic rollback review of plain yoghurt; not retailer stock.")
                    assert await off_available_product_ids(session, [generic.id], as_of=now.date()) == set()
                    for expected_created, expected_unchanged in [(1, 0), (0, 1)]:
                        result = await import_reviewed_off_mappings(session, [mapping],
                            reviewer_user_id=reviewer.id, reviewed_at=now, as_of=now.date())
                        assert (result.created, result.unchanged) == (expected_created, expected_unchanged)
                    assert await off_available_product_ids(session, [generic.id], as_of=now.date()) == {generic.id}
                    visible = (await session.execute(select(models.Recipe.id).where(
                        models.Recipe.id == generic_recipe.id, recipe_market_availability("GB"),
                    ))).scalar_one_or_none()
                    assert visible == generic_recipe.id and generic.barcode is None
                    off.fingerprint = "a" * 64
                    await session.flush()
                    assert await off_available_product_ids(session, [generic.id], as_of=now.date()) == set()
                    report["generic_off_mapping_pg"] = True
                    # Real seeded food + public OFF record, not just synthetic
                    # unbranded objects. Nothing is committed or fetched here.
                    public_sample = json.loads((Path(__file__).resolve().parents[1]
                        / "tests/fixtures/off_uk_oats_20261023.json").read_text(encoding="utf-8"))
                    seed_id = UUID("c65508d5-139b-5f92-9850-1507938eb5e5")
                    seeded = await session.get(models.Product, seed_id)
                    from app.services.system_content_language import is_system_ingredient
                    assert seeded is not None and is_system_ingredient(seeded)
                    assert seeded.brand and seeded.barcode is None
                    original_food = (seeded.brand, seeded.serving_quantity,
                                     dict(seeded.nutrition_per_100 or {}))
                    await import_off_catalogue(session, [public_sample["product"]], retrieved_at=now)
                    public_off = await session.get(models.OffCatalogueProduct, public_sample["product"]["code"])
                    reviewed_link = dict(product_id=seed_id, product_name=seeded.name,
                        product_unit=seeded.unit, product_brand=seeded.brand,
                        off_barcode=public_off.barcode, off_fingerprint=public_off.fingerprint,
                        review_note="Reviewed plain oats food concept; Polish example brand and UK pack are not substitutes.")
                    for _ in range(2):
                        await import_reviewed_off_mappings(session, [reviewed_link],
                            reviewer_user_id=reviewer.id, reviewed_at=now, as_of=now.date())
                    assert await off_available_product_ids(session, [seed_id], as_of=now.date()) == {seed_id}
                    assert (seeded.brand, seeded.serving_quantity,
                            seeded.nutrition_per_100) == original_food
                    report["real_seed_public_off_mapping_pg"] = True
                    # A real public community price must survive PG JSON/NUMERIC
                    # storage as an estimate with its own date and provenance.
                    # Fixed captured evidence date; never presented as a live price.
                    from app.services.open_prices_reference import prepare_open_prices_reference, community_price_proposal
                    from app.services.regional_offer_pricing import select_uk_offer_quote
                    fixtures = Path(__file__).resolve().parents[1] / "tests/fixtures"
                    foods = json.loads((fixtures / "off_uk_staples_20261023.json").read_text(encoding="utf-8"))
                    prices = json.loads((fixtures / "open_prices_uk_20261023.json").read_text(encoding="utf-8"), parse_float=Decimal)
                    code = "20522605"
                    raw_food = next(row["product"] for row in foods["products"] if row["barcode_requested"] == code)
                    mapping = next(row for row in foods["proposals"] if row["off_barcode"] == code)
                    canonical = await session.get(models.Product, UUID(mapping["product_id"]))
                    assert canonical is not None
                    captured_review = datetime(2026, 10, 23, 18, tzinfo=timezone.utc)
                    await import_off_catalogue(session, [raw_food], retrieved_at=datetime.fromisoformat(foods["retrieved_at"]))
                    await import_reviewed_off_mappings(session, [mapping], reviewer_user_id=reviewer.id,
                        reviewed_at=captured_review, as_of=captured_review.date())
                    cached_food = await session.get(models.OffCatalogueProduct, code)
                    observation = next(row for row in prices["records"] if row["product_code"] == code)
                    reference = prepare_open_prices_reference(observation, mapping=mapping,
                        off_product=cached_food, canonical_product=canonical, as_of=captured_review.date())
                    community = community_price_proposal(reference, package_basis_note=
                        "Reviewed homogeneous passata: ingredient and package use mass as sold.")
                    result = await import_reviewed_uk_catalogue(session, [community], reviewer_user_id=reviewer.id,
                        reviewed_at=captured_review, as_of=captured_review.date())
                    assert result.created == 1
                    stored = await session.get(models.RegionalProductOffer, community.proposal_id)
                    quote = select_uk_offer_quote([stored], product_id=canonical.id, store_id=community.store_id,
                        quantity=Decimal("600"), unit="g", as_of=captured_review.date())
                    assert quote is not None and quote.total_price == Decimal("0.90")
                    assert quote.package_count == 2 and quote.purchased_quantity == 1000
                    assert quote.price_is_estimated and quote.last_verified is None
                    assert quote.price_source["provider"] == "open_prices"
                    assert quote.availability_scope == "store_observation"
                    report["community_price_pg_roundtrip"] = True
                    try:
                        await import_reviewed_uk_catalogue(session, [community], reviewer_user_id=reviewer.id,
                            reviewed_at=captured_review, as_of=captured_review.date(),
                            expected_fingerprints={community.proposal_id: "f" * 64})
                    except ValueError:
                        unchanged_fingerprint = (await session.execute(select(models.RegionalProductOffer.fingerprint)
                            .where(models.RegionalProductOffer.id == community.proposal_id))).scalar_one()
                        assert unchanged_fingerprint == community.fingerprint
                    else:
                        raise AssertionError("Stale refresh overwrote a concurrently changed offer")
                    report["price_refresh_fingerprint_conflict_pg"] = True
                    from app.services.market_catalog import reviewed_uk_offer_conditions
                    live_query = select(models.RegionalProductOffer.id).where(
                        models.RegionalProductOffer.id == community.proposal_id,
                        *reviewed_uk_offer_conditions(as_of=captured_review.date()))
                    assert (await session.execute(live_query)).scalar_one_or_none() == community.proposal_id
                    cached_food.fingerprint = "d" * 64
                    await session.flush()
                    assert (await session.execute(live_query)).scalar_one_or_none() is None
                    cached_food.fingerprint = reference.off_fingerprint
                    await session.flush()
                    report["community_live_identity_guard_pg"] = True
                    # Existing product-review input must be usable in GBP,
                    # without a retailer feed or a fabricated 100g package.
                    from app.services.uk_submission_prices import submitted_price_proposal
                    submitted = models.Product(id=uuid4(), name="Synthetic UK submission yoghurt", unit="g",
                        serving_quantity=450, default_quantity=100, submitted_price=Decimal("1.20"),
                        submitted_country_code="GB", created_by_user_id=reviewer.id,
                        requested_store_ids=[str(UK_STORES[0].id)], review_status="approved", created_at=now)
                    session.add(submitted)
                    await session.flush()
                    submitted_offer = submitted_price_proposal(submitted, UK_STORES[0].id, as_of=now.date())
                    assert submitted_offer is not None
                    for _ in range(2):
                        await import_reviewed_uk_catalogue(session, [submitted_offer], reviewer_user_id=reviewer.id,
                            reviewed_at=now, as_of=now.date())
                    submitted_live = select(models.RegionalProductOffer).where(
                        models.RegionalProductOffer.id == submitted_offer.proposal_id,
                        *reviewed_uk_offer_conditions(as_of=now.date()))
                    stored_submission = (await session.execute(submitted_live)).scalar_one()
                    submission_quote = select_uk_offer_quote([stored_submission], product_id=submitted.id,
                        store_id=UK_STORES[0].id, quantity=Decimal("500"), unit="g", as_of=now.date())
                    assert submission_quote is not None and submission_quote.total_price == Decimal("2.40")
                    assert submission_quote.availability_scope == "user_submission" and submission_quote.price_is_estimated
                    submitted.serving_quantity = 100
                    await session.flush()
                    assert (await session.execute(submitted_live)).scalar_one_or_none() is None
                    report["approved_submission_price_pg"] = True
                    # Exercise the actual controlled starter path on all 31
                    # REAL existing foods, inside this outer rollback only.
                    from app.services.uk_starter_import import load_starter_bundle, stage_starter_bundle
                    starter = load_starter_bundle(Path(__file__).resolve().parents[1]
                        / "app/data/uk_starter_20261024.json")
                    starter_original = {}
                    for row in starter.proposals:
                        food = await session.get(models.Product, row.product_id)
                        assert food is not None and is_system_ingredient(food)
                        assert food.name == row.product_name and food.barcode is None
                        starter_original[food.id] = (food.name, food.brand, food.unit,
                            food.default_quantity, food.serving_quantity,
                            dict(food.nutrition_per_100 or {}), list(food.measure_options or []))
                    await session.flush()
                    for _ in range(2):
                        staged = await stage_starter_bundle(session, starter,
                            reviewer_user_id=reviewer.id, reviewed_at=now, as_of=now.date())
                        assert staged.available_count == 31
                    starter_ids = set(starter_original)
                    assert await off_available_product_ids(session, starter_ids, as_of=now.date()) == starter_ids
                    for product_id, original in starter_original.items():
                        food = await session.get(models.Product, product_id)
                        assert (food.name, food.brand, food.unit, food.default_quantity,
                            food.serving_quantity, food.nutrition_per_100,
                            list(food.measure_options or [])) == original
                    egg_facts = await session.get(models.OffCatalogueProduct, "5060286261408")
                    assert egg_facts.package_quantity is None
                    report["controlled_starter_import_pg"] = True
                    report["reviewed_staple_count_pg"] = len(starter_ids)
                    # Selection is a bounded read, not a live OFF call. Exercise
                    # the correlated generic/exact identity predicates on PG.
                    from app.services.off_on_demand import _public_recipe_refresh_query
                    due_codes = (await session.execute(_public_recipe_refresh_query(
                        now=now + timedelta(days=8)))).scalars().all()
                    assert 0 < len(due_codes) <= 8
                    excluded_codes = (await session.execute(_public_recipe_refresh_query(
                        now=now + timedelta(days=8),
                        excluded_keys=[code.lstrip("0") for code in due_codes]))).scalars().all()
                    assert not set(due_codes).intersection(excluded_codes)
                    report["recipe_off_refresh_selection_pg"] = True
                    # Execute the new per-account timezone expression on PG,
                    # without running application startup or ledger backfills.
                    weeks = dict((await session.execute(text(
                        "SELECT country_code, date_trunc('week', CAST(:stamp AS TIMESTAMPTZ) AT TIME ZONE "
                        "CASE WHEN country_code='GB' THEN 'Europe/London' ELSE 'Europe/Warsaw' END)::date "
                        "FROM (VALUES ('GB'), ('PL')) AS markets(country_code)"
                    ), {"stamp": datetime(2026, 10, 18, 22, 30, tzinfo=timezone.utc)})).all())
                    assert str(weeks["GB"]) == "2026-10-12" and str(weeks["PL"]) == "2026-10-19"
                    report["quota_timezone_expression_valid"] = True
            finally:
                if transaction.is_active:
                    await transaction.rollback()
            assert await fingerprints(connection) == before
            final_tables = set((await connection.execute(text("SELECT tablename FROM pg_tables WHERE schemaname='public'"))).scalars())
            assert final_tables == initial_tables
            report["rollback_verified"] = True
            report["baseline_row_counts"] = {key: value[0] for key, value in before.items()}
            await connection.rollback()
    finally:
        await engine.dispose()
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--env-file", required=True)
    parser.add_argument("--expected-host", required=True)
    args = parser.parse_args()
    try:
        report = asyncio.run(run(args.env_file, args.expected_host))
    except Exception as error:
        # DB exceptions can embed queries/values. No raw exception or DSN in logs.
        print(json.dumps({"passed": False, "error_type": type(error).__name__}))
        raise SystemExit(1)
    print(json.dumps({"passed": True, **report}, indent=2))


if __name__ == "__main__":
    main()
