"""Versioned UK evidence constraints; no price, product or account rewrites."""

from sqlalchemy import text


POSTGRES_REGIONAL_EVIDENCE_DDL = """DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conrelid = 'regional_product_offers'::regclass
          AND conname = 'ck_regional_offer_submission_evidence'
    ) THEN
        ALTER TABLE regional_product_offers DROP CONSTRAINT IF EXISTS ck_regional_offer_availability_status;
        ALTER TABLE regional_product_offers DROP CONSTRAINT IF EXISTS ck_regional_offer_availability_scope;
        ALTER TABLE regional_product_offers DROP CONSTRAINT IF EXISTS ck_regional_offer_evidence_kind;
        ALTER TABLE regional_product_offers ADD CONSTRAINT ck_regional_offer_availability_status
            CHECK (availability_status IN ('available_online', 'out_of_stock', 'unknown', 'reported_available'));
        ALTER TABLE regional_product_offers ADD CONSTRAINT ck_regional_offer_availability_scope
            CHECK (availability_scope IN ('online_catalogue', 'store_observation', 'user_submission'));
        ALTER TABLE regional_product_offers ADD CONSTRAINT ck_regional_offer_evidence_kind CHECK (
            (availability_scope = 'online_catalogue' AND availability_status IN ('available_online', 'out_of_stock', 'unknown')) OR
            (availability_scope IN ('store_observation', 'user_submission') AND availability_status = 'reported_available' AND price_kind = 'estimate')
        );
        ALTER TABLE regional_product_offers ADD CONSTRAINT ck_regional_offer_submission_evidence CHECK (
            availability_scope <> 'user_submission' OR (availability_status = 'reported_available' AND price_kind = 'estimate')
        );
    END IF;
END $$"""


async def ensure_regional_offer_evidence_schema(connection):
    """Caller owns the transaction; fresh SQLite uses ORM constraints."""
    if connection.dialect.name != "postgresql":
        raise RuntimeError("Regional evidence deployment migration requires PostgreSQL")
    await connection.execute(text(POSTGRES_REGIONAL_EVIDENCE_DDL))
