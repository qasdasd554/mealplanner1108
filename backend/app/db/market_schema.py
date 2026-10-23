"""Idempotent account-market schema; call inside the normal startup transaction.

No connection is opened here. Production uses PostgreSQL DDL; SQLite support
exists for local tests only. Run production migrations on an isolated Neon
branch first and through a direct connection, following deployment policy.
"""

from sqlalchemy import text


POSTGRES_ACCOUNT_MARKET_DDL = (
    "ALTER TABLE users ADD COLUMN IF NOT EXISTS country_code VARCHAR(2) NOT NULL DEFAULT 'PL'",
    "UPDATE users SET country_code = 'PL' WHERE country_code IS NULL",
    "ALTER TABLE users ALTER COLUMN country_code SET DEFAULT 'PL'",
    "ALTER TABLE users ALTER COLUMN country_code SET NOT NULL",
    """DO $$ BEGIN
        IF NOT EXISTS (
            SELECT 1 FROM pg_constraint
            WHERE conname = 'ck_users_country_code_supported'
              AND conrelid = 'users'::regclass
        ) THEN
            ALTER TABLE users ADD CONSTRAINT ck_users_country_code_supported
                CHECK (country_code IN ('PL', 'GB'));
        END IF;
    END $$""",
    """CREATE OR REPLACE FUNCTION enforce_user_country_immutable()
    RETURNS trigger LANGUAGE plpgsql AS $$
    BEGIN
        IF NEW.country_code IS DISTINCT FROM OLD.country_code THEN
            RAISE EXCEPTION USING
                ERRCODE = '23514',
                CONSTRAINT = 'ck_users_country_code_immutable',
                MESSAGE = 'Account country cannot change after registration';
        END IF;
        RETURN NEW;
    END;
    $$""",
    """DO $$ BEGIN
        IF NOT EXISTS (
            SELECT 1 FROM pg_trigger
            WHERE tgname = 'trg_users_country_immutable'
              AND tgrelid = 'users'::regclass
              AND NOT tgisinternal
        ) THEN
            CREATE TRIGGER trg_users_country_immutable
                BEFORE UPDATE OF country_code ON users
                FOR EACH ROW EXECUTE FUNCTION enforce_user_country_immutable();
        END IF;
    END $$""",
)


async def ensure_account_market_schema(connection) -> None:
    """Backfill pre-existing accounts as PL and prevent subsequent reassignment."""
    dialect = connection.dialect.name
    if dialect == "postgresql":
        for statement in POSTGRES_ACCOUNT_MARKET_DDL:
            await connection.execute(text(statement))
        return
    if dialect != "sqlite":
        raise RuntimeError(f"Unsupported account-market migration dialect: {dialect}")

    columns = await connection.execute(text("PRAGMA table_info(users)"))
    if "country_code" not in {column[1] for column in columns}:
        await connection.execute(text(
            "ALTER TABLE users ADD COLUMN country_code VARCHAR(2) NOT NULL "
            "DEFAULT 'PL' CHECK (country_code IN ('PL', 'GB'))"
        ))
    await connection.execute(text("UPDATE users SET country_code = 'PL' WHERE country_code IS NULL"))
    await connection.execute(text("""
        CREATE TRIGGER IF NOT EXISTS trg_users_country_immutable
        BEFORE UPDATE OF country_code ON users
        WHEN NEW.country_code IS NOT OLD.country_code
        BEGIN SELECT RAISE(ABORT, 'Account country cannot change after registration'); END
    """))
