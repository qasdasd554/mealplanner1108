"""Explicit UK starter transfer; rollback by default, no app startup or network feeds.

Run from backend with PYTHONPATH=. The only connection is the supplied exact
direct PostgreSQL host. This script neither migrates schemas nor enables UK.
"""

import argparse
import asyncio
from dataclasses import asdict
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import ssl
from uuid import UUID


def parser():
    result = argparse.ArgumentParser(description=__doc__)
    result.add_argument("--source", type=Path, default=Path(__file__).resolve().parents[1]
        / "app/data/uk_starter_20261024.json")
    result.add_argument("--describe", action="store_true", help="Validate bundled files without opening a database")
    result.add_argument("--env-file", type=Path)
    result.add_argument("--expected-host")
    result.add_argument("--reviewer-id", type=UUID)
    result.add_argument("--apply", action="store_true", help="Commit only with an explicit dataset digest confirmation")
    result.add_argument("--confirm-dataset")
    return result


def connection_url(env_file, expected_host):
    from dotenv import dotenv_values
    from sqlalchemy.engine import make_url

    raw = dotenv_values(env_file).get("DATABASE_URL", "")
    url = make_url(raw)
    if (not expected_host or url.host != expected_host or "-pooler" in expected_host
            or url.get_backend_name() != "postgresql" or not url.username
            or not url.password or not url.database):
        raise ValueError("The exact direct PostgreSQL host and private env file are required")
    return url.set(drivername="postgresql+asyncpg", query={})


async def run(args):
    # No application startup/session factory. The local engine alone connects.
    os.environ["ENVIRONMENT"] = "development"
    from app.services.uk_starter_import import load_starter_bundle, stage_starter_bundle

    bundle = load_starter_bundle(args.source)
    if args.apply and args.confirm_dataset != bundle.digest:
        raise ValueError("Explicit confirmation of the reviewed dataset digest is required")
    if args.describe:
        if args.apply:
            raise ValueError("Describe cannot apply data")
        return {"mode": "files_only", "dataset_digest": bundle.digest,
            "product_count": len(bundle.products), "link_count": len(bundle.proposals),
            "earliest_fetch": min(row.retrieved_at for row in bundle.products).isoformat(),
            "latest_fetch": max(row.retrieved_at for row in bundle.products).isoformat()}
    if args.env_file is None or args.reviewer_id is None:
        raise ValueError("An env file and existing database administrator UUID are required")
    from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine

    url = connection_url(args.env_file, args.expected_host)
    engine = create_async_engine(url, echo=False, connect_args={
        "ssl": ssl.create_default_context(), "timeout": 20,
        "server_settings": {"application_name": "mealplanner-uk-starter-review",
            "statement_timeout": "20000", "lock_timeout": "5000"},
    })
    try:
        async with AsyncSession(engine, autoflush=False) as session:
            now = datetime.now(timezone.utc)
            result = await stage_starter_bundle(session, bundle, reviewer_user_id=args.reviewer_id,
                reviewed_at=now, as_of=now.date())
            if args.apply:
                await session.commit()
            else:
                await session.rollback()
            return {"mode": "committed" if args.apply else "rolled_back", **asdict(result)}
    finally:
        await engine.dispose()


def main():
    args = parser().parse_args()
    try:
        report = asyncio.run(run(args))
    except Exception as error:
        # Exceptions/DSNs may embed credentials and user data. Types only.
        print(json.dumps({"passed": False, "error_type": type(error).__name__}))
        raise SystemExit(1)
    print(json.dumps({"passed": True, **report}, indent=2))


if __name__ == "__main__":
    main()
