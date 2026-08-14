"""Model ORM komentarzy pod przepisami (z opcjonalnym zdjęciem) i ich lubień."""

from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, String, Text, UniqueConstraint, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.session import Base


class RecipeComment(Base):
    """Komentarz użytkownika pod przepisem, z opcjonalnym zdjęciem.

    UWAGA: zdjęcie jest przechowywane jako dane zakodowane w Base64
    BEZPOŚREDNIO W BAZIE DANYCH (kolumna `photo_base64`), a nie jako plik
    na dysku serwera. Backend działa na Render, którego system plików
    NIE jest trwały — pliki zapisane lokalnie znikają przy każdym
    wdrożeniu. Baza danych (Neon Postgres) jest jedynym trwałym miejscem
    dostępnym bez konfigurowania dodatkowej usługi (np. S3). Zdjęcia są
    kompresowane i ograniczane rozmiarowo przed zapisem (patrz walidacja
    w schemacie), żeby nie rozdymać nadmiernie bazy.
    """

    __tablename__ = "recipe_comments"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    recipe_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("recipes.id", ondelete="CASCADE"), nullable=False, index=True
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    text: Mapped[str | None] = mapped_column(Text, nullable=True)
    # Zdjęcie zakodowane w Base64 (data URI bez prefiksu "data:image/...").
    # Nullable — komentarz może być samym tekstem, samym zdjęciem, albo obu.
    photo_base64: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    recipe: Mapped["Recipe"] = relationship()  # noqa: F821
    user: Mapped["User"] = relationship()  # noqa: F821
    likes: Mapped[list["RecipeCommentLike"]] = relationship(
        back_populates="comment", cascade="all, delete-orphan"
    )


class RecipeCommentLike(Base):
    """Polubienie komentarza przez użytkownika.

    Jeden użytkownik może polubić dany komentarz tylko raz — wymuszone
    ograniczeniem unikalności (comment_id, user_id) na poziomie bazy, więc
    nawet przy równoległych żądaniach nie da się "podwójnie" polubić.
    """

    __tablename__ = "recipe_comment_likes"
    __table_args__ = (
        UniqueConstraint("comment_id", "user_id", name="uq_recipe_comment_like_user"),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    comment_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("recipe_comments.id", ondelete="CASCADE"), nullable=False, index=True
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    comment: Mapped["RecipeComment"] = relationship(back_populates="likes")
