"""Model udostępniania list zakupów innym użytkownikom w obrębie
aplikacji — celowo POWIĄZANY z MealPlan (nie z samą ShoppingList),
bo to WŁAŚNIE meal_plan_id jest kluczem, po którym cała reszta API
(patrz shopping_lists.py, _get_shopping_list_or_404) identyfikuje
listę zakupów — nie ma osobnego, "publicznego" ID samej ShoppingList
używanego przez frontend."""

from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, String, UniqueConstraint, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.session import Base


class ShoppingListShare(Base):
    """Zaproszenie/udostępnienie listy zakupów drugiej osobie —
    dwuetapowe (pending -> accepted), żeby nikt nie mógł po cichu
    dodać kogoś do WSPÓLNEJ listy bez jego wiedzy/zgody."""

    __tablename__ = "shopping_list_shares"
    __table_args__ = (
        # Ta sama para (plan, odbiorca) nie może mieć dwóch aktywnych
        # zaproszeń naraz — powtórna próba udostępnienia tej samej
        # osobie po prostu nic nowego nie tworzy (patrz endpoint).
        UniqueConstraint("meal_plan_id", "shared_with_user_id", name="uq_share_plan_recipient"),
    )

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        server_default=func.gen_random_uuid(),
    )
    meal_plan_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("meal_plans.id", ondelete="CASCADE"),
        nullable=False,
    )
    shared_by_user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
    )
    shared_with_user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
    )
    status: Mapped[str] = mapped_column(
        String(20), default="pending", nullable=False, comment="pending | accepted"
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )

    meal_plan: Mapped["MealPlan"] = relationship("MealPlan")  # noqa: F821
    shared_by: Mapped["User"] = relationship("User", foreign_keys=[shared_by_user_id])  # noqa: F821
    shared_with: Mapped["User"] = relationship("User", foreign_keys=[shared_with_user_id])  # noqa: F821

    def __repr__(self) -> str:
        return f"<ShoppingListShare plan={self.meal_plan_id} status={self.status!r}>"
