"""Stage reviewed German prices. Roll back unless the dataset digest is confirmed."""

import argparse
import asyncio
from collections import Counter, defaultdict
from datetime import date
import hashlib
import json
import os
from pathlib import Path
import ssl

from scripts.import_uk_starter import connection_url


DATA_DIR = Path(__file__).resolve().parents[1] / "app/data"
DEFAULT_SOURCE = DATA_DIR / "de_aldi_sued_reviewed_20261110.json"


def parse_args():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, action="append", help="Catalogue JSON. Repeat with --coverage.")
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--describe", action="store_true", help="Read the snapshot without connecting")
    mode.add_argument("--coverage", action="store_true", help="Report recipe coverage of catalogue files by shop")
    mode.add_argument("--apply", action="store_true", help="Commit a previously reviewed snapshot")
    parser.add_argument("--env-file", type=Path)
    parser.add_argument("--expected-host")
    parser.add_argument("--confirm-dataset")
    args = parser.parse_args()
    if not args.coverage and len(args.source or []) > 1:
        parser.error("Only --coverage accepts more than one source")
    return args


def recipe_coverage(sources, *, as_of):
    from app.db.de_store_catalog import DE_CATALOGUE_MAX_AGE, DE_STORES, reviewed_de_catalogue_date
    from app.db.seed import PRODUCTS_DATA, RECIPES_DATA

    catalogues = defaultdict(set)
    expired_sources = []
    store_currencies = {store.slug: store.currency for store in DE_STORES}
    known_products = {row[0] for row in PRODUCTS_DATA}
    for source in sources:
        evidence = json.loads(source.read_bytes())
        observed_on = date.fromisoformat(evidence["reviewed_on"])
        if observed_on < as_of - DE_CATALOGUE_MAX_AGE:
            expired_sources.append(source.name)
            continue
        reviewed_de_catalogue_date(evidence, as_of=as_of)
        slug = evidence["store_slug"]
        if store_currencies.get(slug) != evidence["currency"]:
            raise ValueError("Unknown German store or currency")
        names = {row["canonical"] for row in evidence["products"]}
        if not names or not names <= known_products:
            raise ValueError("Coverage requires known system products")
        catalogues[slug].update(names)

    required = []
    for recipe in RECIPES_DATA:
        products = {name for name, _, _, optional in recipe["ingredients"] if not optional}
        if products:
            required.append((recipe["meal_type"], products))

    reports = []
    for slug, products in sorted(catalogues.items()):
        complete = Counter()
        almost_complete = Counter()
        for meal_type, ingredients in required:
            missing = tuple(sorted(ingredients - products))
            if not missing:
                complete[meal_type] += 1
            elif len(missing) <= 2:
                almost_complete[missing] += 1
        single = [
            {"product": names[0], "recipes_unlocked": count}
            for names, count in almost_complete.most_common() if len(names) == 1
        ]
        pairs = [
            {"products": names, "recipes_unlocked": count + sum(almost_complete[(name,)] for name in names)}
            for names, count in almost_complete.items() if len(names) == 2
        ]
        pairs.sort(key=lambda row: (-row["recipes_unlocked"], row["products"]))
        reports.append({"store": slug, "catalogue_products": len(products),
                        "covered_recipes": sum(complete.values()), "covered_by_meal_type": dict(complete),
                        "next_products": single[:10], "next_pairs": pairs[:10]})
    return {"mode": "file_coverage", "system_recipes": len(required), "stores": reports,
            "expired_sources": expired_sources}


async def run(args):
    from app.core.market_clock import market_today
    from app.db.de_store_catalog import reviewed_de_catalogue_date, stage_reviewed_de_catalogue
    from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine

    as_of = market_today("DE")
    if args.coverage:
        sources = args.source or sorted(DATA_DIR.glob("de_*_reviewed_*.json"))
        return recipe_coverage(sources, as_of=as_of)
    source = args.source[0] if args.source else DEFAULT_SOURCE
    raw = source.read_bytes()
    digest = hashlib.sha256(raw).hexdigest()
    evidence = json.loads(raw)
    observed_on = reviewed_de_catalogue_date(evidence, as_of=as_of)
    report = {
        "dataset_digest": digest,
        "store": evidence["store_slug"],
        "observed_on": observed_on.isoformat(),
        "offers": len(evidence["products"]),
    }
    if args.describe:
        return {"mode": "files_only", **report}
    if args.apply and args.confirm_dataset != digest:
        raise ValueError("Confirm the digest from the dry run before applying")
    if args.env_file is None or not args.expected_host:
        raise ValueError("Use the private env file and the exact host of the pilot database")

    engine = create_async_engine(connection_url(args.env_file, args.expected_host), connect_args={
        "ssl": ssl.create_default_context(), "timeout": 20,
        "server_settings": {"application_name": "mealplanner-de-catalogue", "lock_timeout": "5000"},
    })
    try:
        async with AsyncSession(engine, autoflush=False) as session:
            inserted = await stage_reviewed_de_catalogue(session, evidence, as_of=as_of)
            if args.apply:
                await session.commit()
            else:
                await session.rollback()
    finally:
        await engine.dispose()

    return {"mode": "committed" if args.apply else "rolled_back", **report,
            "new_offers": inserted, "existing_offers": report["offers"] - inserted}


def main():
    args = parse_args()
    # Application imports initialize configuration. All database operations below
    # use the explicitly supplied connection, independently of app settings.
    os.environ["ENVIRONMENT"] = "development"
    try:
        result = asyncio.run(run(args))
    except Exception as error:
        # Database and connection errors may include credentials or values.
        print(f"German catalogue import failed ({type(error).__name__}).")
        raise SystemExit(1)
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
