"""Regresja widoczności produktów niezwiązanych z konkretnym sklepem."""

import asyncio
import uuid
from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock

from sqlalchemy.dialects import postgresql

from app.api.v1.products import list_products


def test_catalog_searches_product_name_and_brand() -> None:
    result = MagicMock()
    result.scalars.return_value.all.return_value = []
    db = SimpleNamespace(execute=AsyncMock(return_value=result))

    asyncio.run(
        list_products(
            skip=0,
            limit=50,
            search="KFC",
            db=db,
            current_user=SimpleNamespace(id=uuid.uuid4()),
        )
    )

    statement = db.execute.await_args.args[0]
    sql = str(
        statement.compile(
            dialect=postgresql.dialect(),
            compile_kwargs={"literal_binds": True},
        )
    ).lower()
    assert "products.name" in sql
    assert "products.brand" in sql
    assert "%kfc%" in sql

