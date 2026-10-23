"""DDL compilation is not a live PostgreSQL migration/concurrency test."""

from sqlalchemy import create_engine, inspect
from sqlalchemy.dialects import postgresql
from sqlalchemy.schema import CreateTable

from app.models import Base, ShoppingListItemRegionalSnapshot


def test_regional_snapshot_postgres_ddl_keeps_local_state_additive():
    table = ShoppingListItemRegionalSnapshot.__table__
    ddl = str(CreateTable(table).compile(dialect=postgresql.dialect()))
    assert "CREATE TABLE shopping_list_item_regional_snapshots" in ddl
    assert "PRIMARY KEY (item_id)" in ddl
    assert "manual_extra_quantity NUMERIC(10, 3)" in ddl
    assert "purchase_is_checked BOOLEAN" in ddl
    assert "FOREIGN KEY(item_id) REFERENCES shopping_list_items (id) ON DELETE CASCADE" in ddl
    assert "FOREIGN KEY(product_id) REFERENCES products (id) ON DELETE SET NULL" in ddl
    assert "FOREIGN KEY(offer_id) REFERENCES regional_product_offers (id) ON DELETE SET NULL" in ddl
    assert "ALTER TABLE" not in ddl
    assert "regional_snapshot" not in Base.metadata.tables["shopping_list_items"].columns


def test_additive_metadata_create_is_idempotent_for_an_existing_legacy_schema():
    engine = create_engine("sqlite:///:memory:")
    try:
        legacy = Base.metadata.tables["shopping_list_items"]
        Base.metadata.create_all(engine)
        before = tuple(column["name"] for column in inspect(engine).get_columns(legacy.name))
        ShoppingListItemRegionalSnapshot.__table__.create(engine, checkfirst=True)
        Base.metadata.create_all(engine)
        after = tuple(column["name"] for column in inspect(engine).get_columns(legacy.name))
        assert before == after == tuple(legacy.columns.keys())
        assert "purchase_is_checked" in {
            column["name"] for column in inspect(engine).get_columns("shopping_list_item_regional_snapshots")
        }
    finally:
        engine.dispose()
