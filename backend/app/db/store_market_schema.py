"""Country-scoped store identity. PostgreSQL only, run before seeding stores.

This migration adds no stock, prices, products or claims of availability.
The same retail chain has independent records and prices in PL and GB.
"""

from sqlalchemy import text

from app.db.market_schema import ensure_german_market_constraint

POSTGRES_STORE_MARKET_DDL = (
    "ALTER TABLE stores ADD COLUMN IF NOT EXISTS country_code VARCHAR(2) NOT NULL DEFAULT 'PL'",
    "ALTER TABLE stores ADD COLUMN IF NOT EXISTS currency_code VARCHAR(3) NOT NULL DEFAULT 'PLN'",
    "ALTER TABLE store_products ADD COLUMN IF NOT EXISTS package_quantity NUMERIC(10, 3)",
    "ALTER TABLE store_products ADD COLUMN IF NOT EXISTS package_unit VARCHAR(8)",
    "ALTER TABLE shopping_list_items ADD COLUMN IF NOT EXISTS catalogue_product_id UUID "
    "REFERENCES products(id) ON DELETE SET NULL",
    "CREATE INDEX IF NOT EXISTS ix_stores_country_code ON stores (country_code)",
    "ALTER TABLE products ADD COLUMN IF NOT EXISTS submitted_country_code VARCHAR(2) NOT NULL DEFAULT 'PL'",
    ensure_german_market_constraint("products", "ck_products_submission_market",
                                    "submitted_country_code IN ('PL', 'GB', 'DE')"),
    ensure_german_market_constraint(
        "stores", "ck_stores_market_currency",
        "(country_code = 'PL' AND currency_code = 'PLN') OR "
        "(country_code = 'GB' AND currency_code = 'GBP') OR "
        "(country_code = 'DE' AND currency_code = 'EUR')",
    ),
    """DO $$ DECLARE old_unique RECORD; BEGIN
        FOR old_unique IN
            SELECT c.conname FROM pg_constraint c
            JOIN pg_attribute a ON a.attrelid = c.conrelid AND a.attname = 'name'
            WHERE c.conrelid = 'stores'::regclass AND c.contype = 'u'
              AND c.conkey = ARRAY[a.attnum]::smallint[]
        LOOP
            EXECUTE format('ALTER TABLE stores DROP CONSTRAINT %I', old_unique.conname);
        END LOOP;
        IF NOT EXISTS (
            SELECT 1 FROM pg_constraint
            WHERE conrelid = 'stores'::regclass AND conname = 'uq_store_country_name'
        ) THEN
            ALTER TABLE stores ADD CONSTRAINT uq_store_country_name UNIQUE (country_code, name);
        END IF;
    END $$""",
)


async def ensure_store_market_schema(connection) -> None:
    """Extend existing PostgreSQL tables; fresh SQLite uses ORM metadata."""
    if connection.dialect.name != "postgresql":
        raise RuntimeError("Store-market deployment migration requires PostgreSQL")
    for statement in POSTGRES_STORE_MARKET_DDL:
        await connection.execute(text(statement))
