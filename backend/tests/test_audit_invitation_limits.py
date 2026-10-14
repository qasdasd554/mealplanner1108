"""Authenticated invitation endpoints must limit persisted spam."""

from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock
from uuid import uuid4

import pytest
from fastapi import HTTPException

from app.api.v1.friends import send_invitation
from app.schemas.friendship import FriendInvitationCreate


@pytest.mark.asyncio
async def test_friend_invitation_searches_are_rate_limited():
    user = SimpleNamespace(id=uuid4())
    db = AsyncMock()
    result = MagicMock()
    result.scalar_one_or_none.return_value = None
    db.execute.return_value = result
    codes = []
    for _ in range(31):
        with pytest.raises(HTTPException) as error:
            await send_invitation(FriendInvitationCreate(identifier="missing@example.com"), user, db)
        codes.append(error.value.status_code)
    assert codes[-1] == 429
