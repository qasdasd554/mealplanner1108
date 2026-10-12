import asyncio
from datetime import datetime, timedelta, timezone
from uuid import uuid4

from sqlalchemy.dialects import postgresql
from app.api.v1.users import claim_app_review_prompt
from app.models.user import User


class Result:
    def __init__(self, value):
        self.value = value

    def scalar_one_or_none(self):
        return self.value


class Database:
    def __init__(self, user_id, last=None, offer=None):
        self.user_id = user_id
        self.last = last
        self.offer = offer
        self.commits = 0
        self.rollbacks = 0

    async def execute(self, statement):
        await asyncio.sleep(0)
        compiled = statement.compile(dialect=postgresql.dialect())
        sql = str(compiled)
        values = compiled.params
        assert 'users.id =' in sql and values['id_1'] == self.user_id
        assert 'review_prompt_last_requested_at IS NULL' in sql
        assert 'RETURNING users.review_prompt_last_requested_at' in sql
        now = values['review_prompt_last_requested_at']
        threshold = values['review_prompt_last_requested_at_1']
        assert now - threshold == timedelta(days=10)
        offer_threshold = values['premium_offer_last_shown_at_1']
        assert now - offer_threshold == timedelta(days=1)
        if (self.last is None or self.last <= threshold) and (
            self.offer is None or self.offer <= offer_threshold
        ):
            self.last = now
            return Result(now)
        return Result(None)

    async def commit(self):
        self.commits += 1

    async def rollback(self):
        self.rollbacks += 1


def test_first_request_is_allowed_and_records_ten_day_cooldown():
    user = User(id=uuid4())
    db = Database(user.id)
    result = asyncio.run(claim_app_review_prompt(current_user=user, db=db))
    assert result.allowed
    assert result.next_eligible_at == db.last + timedelta(days=10)
    assert db.commits == 1


def test_nine_days_is_too_early():
    user = User(id=uuid4())
    db = Database(user.id, last=datetime.now(timezone.utc) - timedelta(days=9))
    result = asyncio.run(claim_app_review_prompt(current_user=user, db=db))
    assert not result.allowed and db.commits == 0 and db.rollbacks == 1


def test_ten_days_is_allowed():
    user = User(id=uuid4())
    db = Database(user.id, last=datetime.now(timezone.utc) - timedelta(days=10))
    result = asyncio.run(claim_app_review_prompt(current_user=user, db=db))
    assert result.allowed


def test_recent_trial_offer_suppresses_rating_request():
    user = User(id=uuid4())
    db = Database(user.id, offer=datetime.now(timezone.utc))
    result = asyncio.run(claim_app_review_prompt(current_user=user, db=db))
    assert not result.allowed


def test_two_devices_can_only_claim_once():
    async def run():
        user = User(id=uuid4())
        db = Database(user.id)
        results = await asyncio.gather(
            claim_app_review_prompt(current_user=user, db=db),
            claim_app_review_prompt(current_user=user, db=db),
        )
        assert sum(result.allowed for result in results) == 1
        assert db.commits == 1
    asyncio.run(run())
