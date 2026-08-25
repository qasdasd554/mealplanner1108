"""Model spiżarni — produkty, które użytkownik faktycznie ma w domu.

Osobna, prosta tabela (user_id + product_id + ilość opcjonalnie) —
świadomie NIE łączona z ShoppingListItem, bo to koncepcyjnie inna rzecz:
lista zakupów to "co trzeba kupić NA KONKRETNY plan", spiżarnia to
"co mam w domu NIEZALEŻNIE od żadnego planu", trwałe do czasu ręcznego
usunięcia albo zużycia.
"""

from __future__ import annotations

import uuid
from datetime import datetime
from decimal import Decimal

from sqlalchemy import DateTime, ForeignKey, Numeric, String, UniqueConstraint, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.session import Base


class PantryItem(Base):
    """Pojedynczy produkt w spiżarni użytkownika."""

    __tablename__ = "pantry_items"
    __table_args__ = (
        # Jeden produkt raz na użytkownika — powtórne dodanie tego
        # samego produktu AKTUALIZUJE istniejący wpis (ilość), zamiast
        # tworzyć duplikat.
        UniqueConstraint("user_id", "product_id", name="uq_pantry_user_product"),
    )

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        server_default=func.gen_random_uuid(),
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
    )
    product_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("products.id", ondelete="CASCADE"),
        nullable=False,
    )
    # Ilość jest CELOWO opcjonalna i informacyjna — dopasowywanie
    # przepisów sprawdza tylko OBECNOŚĆ produktu w spiżarni, nie ilość
    # (upraszcza logikę; użytkownik i tak wie, ile realnie ma).
    quantity: Mapped[Decimal | None] = mapped_column(Numeric(10, 3), nullable=True)
    unit: Mapped[str | None] = mapped_column(String(20), nullable=True)
    added_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )

    product: Mapped["Product"] = relationship("Product")  # noqa: F821

    def __repr__(self) -> str:
        return f"<PantryItem user={self.user_id} product={self.product_id}>"
