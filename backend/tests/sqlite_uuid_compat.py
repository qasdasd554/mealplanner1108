"""Test-session adapter for SQLite < 3.35; never changes app model defaults."""

from uuid import uuid4

from sqlalchemy import Uuid, event, inspect


def supply_sqlite_uuid_defaults(session) -> bool:
    """SQLite without INSERT RETURNING cannot give ORM a server UUID.

    Reproduce PostgreSQL's generated UUID only for the local test session.
    Native RETURNING tests continue to exercise the server default itself.
    Do not attach globally or change mapped Columns: PostgreSQL must retain
    gen_random_uuid(), constraints and normal identity loading.
    """
    dialect = session.get_bind().dialect
    if dialect.name != "sqlite" or dialect.insert_returning:
        return False

    @event.listens_for(session, "before_flush")
    def supply_ids(test_session, _flush_context, _instances):
        for row in test_session.new:
            column = inspect(type(row)).columns.get("id")
            if (
                column is not None
                and column.primary_key
                and isinstance(column.type, Uuid)
                and column.default is None
                and column.server_default is not None
                and str(column.server_default.arg) == "gen_random_uuid()"
                and getattr(row, "id", None) is None
            ):
                row.id = uuid4()

    return True
