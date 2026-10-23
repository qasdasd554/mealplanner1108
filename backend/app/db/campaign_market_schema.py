"""Idempotent campaign-market migration; existing campaigns remain Polish.

The caller owns the connection/transaction. No connection or commit is made.
"""
from sqlalchemy import text


async def ensure_campaign_market_schema(connection) -> None:
    if connection.dialect.name == "postgresql":
        statements = (
            "ALTER TABLE purchase_campaigns ADD COLUMN IF NOT EXISTS country_code VARCHAR(2) NOT NULL DEFAULT 'PL'",
            "UPDATE purchase_campaigns SET country_code='PL' WHERE country_code IS NULL",
            "ALTER TABLE purchase_campaigns ALTER COLUMN country_code SET DEFAULT 'PL'",
            "ALTER TABLE purchase_campaigns ALTER COLUMN country_code SET NOT NULL",
            """DO $$ BEGIN
                IF NOT EXISTS (SELECT 1 FROM pg_constraint
                    WHERE conrelid='purchase_campaigns'::regclass
                    AND conname='ck_purchase_campaign_country') THEN
                    ALTER TABLE purchase_campaigns ADD CONSTRAINT ck_purchase_campaign_country
                        CHECK (country_code IN ('PL', 'GB'));
                END IF;
            END $$""",
        )
        for statement in statements:
            await connection.execute(text(statement))
    elif connection.dialect.name == "sqlite":
        columns = await connection.execute(text("PRAGMA table_info(purchase_campaigns)"))
        if "country_code" not in {column[1] for column in columns}:
            await connection.execute(text("ALTER TABLE purchase_campaigns ADD COLUMN country_code VARCHAR(2) NOT NULL DEFAULT 'PL' CHECK(country_code IN ('PL','GB'))"))
    else:
        raise RuntimeError("Unsupported campaign-market migration dialect")
    await connection.execute(text("CREATE INDEX IF NOT EXISTS ix_purchase_campaigns_country_code ON purchase_campaigns (country_code)"))
