"""Country-scoped store identity. PostgreSQL only, run before seeding stores.

This migration adds no stock, prices, products or claims of availability.
The same retail chain has independent records and prices in PL and GB.
"""

from sqlalchemy import text


POSTGRES_STORE_MARKET_DDL = (
    "ALTER TABLE stores ADD COLUMN IF NOT EXISTS country_code VARCHAR(2) NOT NULL DEFAULT 'PL'",
    "ALTER TABLE stores ADD COLUMN IF NOT EXISTS currency_code VARCHAR(3) NOT NULL DEFAULT 'PLN'",
    "CREATE INDEX IF NOT EXISTS ix_stores_country_code ON stores (country_code)",
    "ALTER TABLE products ADD COLUMN IF NOT EXISTS submitted_country_code VARCHAR(2) NOT NULL DEFAULT 'PL'",
    """DO $$ BEGIN
        IF NOT EXISTS (
            SELECT 1 FROM pg_constraint
            WHERE conrelid = 'products'::regclass
              AND conname = 'ck_products_submission_market'
        ) THEN
            ALTER TABLE products ADD CONSTRAINT ck_products_submission_market
                CHECK (submitted_country_code IN ('PL', 'GB'));
        END IF;
    END $$""",
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
        IF NOT EXISTS (
            SELECT 1 FROM pg_constraint
            WHERE conrelid = 'stores'::regclass AND conname = 'ck_stores_market_currency'
        ) THEN
            ALTER TABLE stores ADD CONSTRAINT ck_stores_market_currency CHECK (
                (country_code = 'PL' AND currency_code = 'PLN') OR
                (country_code = 'GB' AND currency_code = 'GBP')
            );
        END IF;
    END $$""",
)


async def ensure_store_market_schema(connection) -> None:
    """Extend existing PostgreSQL tables; fresh SQLite uses ORM metadata."""
    if connection.dialect.name != "postgresql":
        raise RuntimeError("Store-market deployment migration requires PostgreSQL")
    for statement in POSTGRES_STORE_MARKET_DDL:
        await connection.execute(text(statement))
