"""Extend existing Polish promotion records with explicit market provenance."""

from sqlalchemy import text

from app.db.market_schema import ensure_german_market_constraint


async def ensure_promotion_market_schema(connection) -> None:
    for table, constraint in (
        ("promotions", "ck_promotion_country"),
        ("promotion_scan_jobs", "ck_promotion_scan_country"),
    ):
        await connection.execute(text(
            f"ALTER TABLE {table} ADD COLUMN IF NOT EXISTS country_code VARCHAR(2) NOT NULL DEFAULT 'PL'"
        ))
        await connection.execute(text(ensure_german_market_constraint(
            table, constraint, "country_code IN ('PL', 'DE')",
        )))
        await connection.execute(text(
            f"CREATE INDEX IF NOT EXISTS ix_{table}_country_code ON {table} (country_code)"
        ))
    await connection.execute(text(
        "ALTER TABLE promotions ADD COLUMN IF NOT EXISTS store_product_id UUID "
        "REFERENCES store_products(id) ON DELETE SET NULL"
    ))
    await connection.execute(text(
        "ALTER TABLE store_products ADD COLUMN IF NOT EXISTS retailer_sku VARCHAR(100)"
    ))
