"""Regresje relacji znajomych."""

from uuid import UUID

from app.models.friendship import canonical_friend_ids


def test_friend_pair_is_identical_in_both_directions() -> None:
    first = UUID("00000000-0000-0000-0000-000000000002")
    second = UUID("00000000-0000-0000-0000-000000000001")

    assert canonical_friend_ids(first, second) == (second, first)
    assert canonical_friend_ids(second, first) == (second, first)
