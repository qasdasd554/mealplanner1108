"""Historia utworzeń planów, która nie znika po usunięciu planu."""

from __future__ import annotations

import uuid
from datetime import date, datetime

from sqlalchemy import Date, DateTime, ForeignKey, Index, UniqueConstraint, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db.session import Base


class MealPlanCreation(Base):
    __tablename__ = "meal_plan_creations"
    __table_args__ = (
        UniqueConstraint("meal_plan_id", name="uq_meal_plan_creation_plan"),
        Index("ix_meal_plan_creations_user_week", "user_id", "week_start"),
    )

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4,
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False,
    )
    # Bez FK do planu: skasowanie planu nie odnawia limitu tygodniowego.
    meal_plan_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False)
    week_start: Mapped[date] = mapped_column(Date, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False,
    )
