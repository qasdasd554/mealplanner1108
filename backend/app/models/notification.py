"""Model ORM powiadomień w aplikacji (dzwoneczek).

Na razie to powiadomienia WEWNĄTRZ aplikacji — widoczne dopiero po jej
otwarciu, nie prawdziwe powiadomienia systemowe (push), które "wyskakują"
nawet gdy aplikacja jest zamknięta. Prawdziwy push wymaga skonfigurowania
Firebase Cloud Messaging (projektu Firebase, google-services.json,
klucza serwera) — infrastruktury, której nie da się założyć bez udziału
właściciela konta. To wewnętrzne powiadomienia to solidna podstawa, którą
później można rozszerzyć o wysyłkę push, nie zmieniając samego modelu
danych.
"""

from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import Boolean, DateTime, ForeignKey, String, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.session import Base


class Notification(Base):
    """Powiadomienie dla użytkownika — na razie tylko "nowy komentarz w
    wątku, w którym już brałeś udział" (recipe_comment), ale struktura
    (`notification_type`) jest gotowa na kolejne typy w przyszłości."""

    __tablename__ = "notifications"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    # Odbiorca powiadomienia.
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    notification_type: Mapped[str] = mapped_column(String(50), nullable=False, default="recipe_comment")
    # Gotowa, czytelna wiadomość ("Ala skomentowała: Kotlet schabowy...") —
    # budowana raz przy tworzeniu powiadomienia, żeby frontend nie musiał
    # doklejać nazw przepisów/autorów przy każdym wyświetleniu listy.
    message: Mapped[str] = mapped_column(String(500), nullable=False)
    recipe_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("recipes.id", ondelete="CASCADE"), nullable=True
    )
    comment_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("recipe_comments.id", ondelete="CASCADE"), nullable=True
    )
    is_read: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    recipe: Mapped["Recipe"] = relationship()  # noqa: F821
