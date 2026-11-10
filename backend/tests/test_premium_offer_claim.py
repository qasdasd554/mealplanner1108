from datetime import datetime, timedelta, timezone
from unittest.mock import AsyncMock, Mock
from uuid import uuid4

import pytest

from app.api.v1.users import PremiumOfferClaimRequest, claim_contextual_premium_offer
from app.models.user import User


@pytest.mark.asyncio
async def test_premium_offer_cooldown_does_not_reload_user_after_rollback():
    user_id = uuid4()
    user = User(id=user_id, role="user", is_premium=False)
    last_shown_at = datetime.now(timezone.utc) - timedelta(hours=1)
    db = AsyncMock()
    db.execute.return_value = Mock(scalar_one_or_none=Mock(return_value=None))
    db.scalar.return_value = last_shown_at

    async def rollback():
        # A real rollback expires the ORM instance, including its primary key.
        del user.id

    db.rollback.side_effect = rollback

    result = await claim_contextual_premium_offer(
        PremiumOfferClaimRequest(context="recipe"), current_user=user, db=db
    )

    assert result.allowed is False
    assert result.next_eligible_at == last_shown_at + timedelta(hours=24)
    db.rollback.assert_awaited_once()
    db.commit.assert_not_awaited()
    statement = db.scalar.await_args.args[0]
    assert statement.compile().params == {"id_1": user_id}
