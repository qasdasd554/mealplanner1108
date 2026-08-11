import uuid
from datetime import date, datetime
from typing import TYPE_CHECKING, Optional

from sqlalchemy import Date, DateTime, Enum, Float, ForeignKey, Integer, String, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.session import Base

if TYPE_CHECKING:
    from app.models.recipe import Recipe
    from app.models.user import User


class FoodLogEntry(Base):
    """
    Model reprezentujący pojedynczy wpis w dzienniku posiłków użytkownika.
    Może to być odniesienie do przepisu z bazy, lub niestandardowy wpis ręczny.
    """

    __tablename__ = "food_log_entries"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        server_default=func.gen_random_uuid(),
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    date: Mapped[date] = mapped_column(Date, nullable=False, index=True)
    meal_type: Mapped[str] = mapped_column(String(50), nullable=False)  # e.g., breakfast, lunch, dinner, snack
    
    recipe_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        UUID(as_uuid=True), ForeignKey("recipes.id", ondelete="SET NULL"), nullable=True
    )
    custom_name: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    
    calories: Mapped[float] = mapped_column(Float, default=0.0, nullable=False)
    protein: Mapped[float] = mapped_column(Float, default=0.0, nullable=False)
    fat: Mapped[float] = mapped_column(Float, default=0.0, nullable=False)
    carbs: Mapped[float] = mapped_column(Float, default=0.0, nullable=False)
    servings: Mapped[float] = mapped_column(Float, default=1.0, nullable=False)
    
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=datetime.utcnow, nullable=False
    )

    # Relacje
    user: Mapped["User"] = relationship()
    recipe: Mapped[Optional["Recipe"]] = relationship()
