"""Shopping response copy follows account country without changing API gates."""

import asyncio
from types import SimpleNamespace as NS
from unittest.mock import AsyncMock, MagicMock
from uuid import uuid4

import pytest
from fastapi import HTTPException

from app.api.v1 import shopping_lists as api
from app.core.exceptions import AppException


@pytest.mark.parametrize("country", ["PL", "GB"])
@pytest.mark.parametrize("kind,pl,en", [
    ("empty_recipes", "Podaj przynajmniej jeden przepis", "Choose at least one recipe."),
    ("empty_shop", "Wybrany sklep nie jest dostępny w kraju tego konta", "The selected shop is not available in this account's country."),
    ("duplicate_merge", "Wybierz co najmniej dwie różne listy.", "Choose at least two different shopping lists."),
    ("missing_list", None, None),
    ("empty_custom", "Wpisz nazwę pozycji", "Enter an item name."),
    ("missing_invitation", "Nie znaleziono tego zaproszenia.", "Shopping invitation not found."),
])
def test_shopping_validation_copy_preserves_language_status_and_no_writes(monkeypatch, country, kind, pl, en):
    account = NS(id=uuid4(), country_code=country)
    key = uuid4()
    result = MagicMock()
    result.scalar_one_or_none.return_value = None
    database = NS(execute=AsyncMock(return_value=result), commit=AsyncMock(), add=MagicMock())
    if kind == "empty_recipes":
        task = api.create_shopping_list_from_recipes(api.ShoppingListFromRecipesRequest(
            recipe_ids=[], store_id=key), account, database)
    elif kind == "empty_shop":
        monkeypatch.setattr(api, "get_store_in_account_market", AsyncMock(return_value=None))
        task = api.create_empty_shopping_list(api.EmptyShoppingListRequest(store_id=key), account, database)
    elif kind == "duplicate_merge":
        task = api.merge_shopping_lists(api.MergeShoppingListsRequest(list_ids=[key, key]), account, database)
    elif kind == "missing_list":
        pl, en = f"Lista zakupów o ID {key} nie została znaleziona", f"Shopping list {key} was not found."
        task = api._get_shopping_list_or_404(key, account, database)
    elif kind == "empty_custom":
        monkeypatch.setattr(api, "_get_shopping_list_or_404", AsyncMock(return_value=NS(items=[])))
        task = api.add_custom_item_to_shopping_list(key, api.AddCustomItemRequest(name=" "), account, database)
    else:
        task = api.accept_share(key, account, database)
    with pytest.raises((HTTPException, AppException)) as failure:
        asyncio.run(task)
    assert failure.value.detail == (en if country == "GB" else pl)
    assert failure.value.status_code == (404 if kind in {"missing_list", "empty_shop", "missing_invitation"} else 400)
    database.commit.assert_not_awaited()
    database.add.assert_not_called()


@pytest.mark.parametrize("country", ["PL", "GB"])
def test_completed_retry_has_localised_message_without_extra_pantry_write(monkeypatch, country):
    account = NS(id=uuid4(), country_code=country)
    monkeypatch.setattr(api, "_get_shopping_list_or_404", AsyncMock(return_value=NS(status="completed")))
    database = NS(execute=AsyncMock(), commit=AsyncMock(), add=MagicMock())
    value = asyncio.run(api.complete_shopping_list(uuid4(), True, account, database))
    assert value == {"detail": "Shopping list completed." if country == "GB" else "Lista zakończona", "moved_to_pantry": 0}
    database.commit.assert_not_awaited()
    database.add.assert_not_called()


@pytest.mark.parametrize("country", ["PL", "GB"])
def test_append_quota_keeps_server_gate_and_existing_client_detection_prefix(monkeypatch, country):
    account = NS(id=uuid4(), country_code=country, is_premium=False, premium_expires_at=None,
        premium_product_id=None, role="user")
    recipe_id = uuid4()
    result = MagicMock()
    result.scalars.return_value.all.return_value = [NS(id=recipe_id)]
    database = NS(execute=AsyncMock(return_value=result), commit=AsyncMock())
    monkeypatch.setattr(api, "get_store_in_account_market", AsyncMock(return_value=NS(id=uuid4())))
    task = api.create_shopping_list_from_recipes(api.ShoppingListFromRecipesRequest(
        recipe_ids=[recipe_id], store_id=uuid4(), existing_list_id=uuid4()), account, database)
    with pytest.raises(HTTPException) as failure:
        asyncio.run(task)
    assert failure.value.status_code == 403
    assert failure.value.detail.startswith("A Standard account can create one shopping list per week"
        if country == "GB" else "Konto standardowe może utworzyć jedną listę zakupów w tygodniu")
    database.commit.assert_not_awaited()
