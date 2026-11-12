"""Stage reviewed German prices. Roll back unless the dataset digest is confirmed."""

import argparse
import asyncio
import hashlib
import json
import os
from pathlib import Path
import ssl

from scripts.import_uk_starter import connection_url


def parse_args():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=Path(__file__).resolve().parents[1]
                        / "app/data/de_aldi_sued_reviewed_20261110.json")
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--describe", action="store_true", help="Read the snapshot without connecting")
    mode.add_argument("--apply", action="store_true", help="Commit a previously reviewed snapshot")
    parser.add_argument("--env-file", type=Path)
    parser.add_argument("--expected-host")
    parser.add_argument("--confirm-dataset")
    return parser.parse_args()


async def run(args):
    from app.core.market_clock import market_today
    from app.db.de_store_catalog import reviewed_de_catalogue_date, stage_reviewed_de_catalogue
    from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine

    raw = args.source.read_bytes()
    digest = hashlib.sha256(raw).hexdigest()
    evidence = json.loads(raw)
    as_of = market_today("DE")
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
