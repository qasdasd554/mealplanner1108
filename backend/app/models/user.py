"""Modele ORM użytkowników i ich alergenów."""

from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import Boolean, DateTime, Float, ForeignKey, Integer, String, Text, func
from sqlalchemy.dialects.postgresql import JSON, UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.session import Base


class User(Base):
    """Użytkownik aplikacji."""

    __tablename__ = "users"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        server_default=func.gen_random_uuid(),
    )
    email: Mapped[str] = mapped_column(
        String(320), unique=True, nullable=False
    )
    password_hash: Mapped[str] = mapped_column(String(500), nullable=False)
    display_name: Mapped[str | None] = mapped_column(String(200), nullable=True)
    preferred_store_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("stores.id", ondelete="SET NULL"),
        nullable=True,
    )
    dietary_preferences: Mapped[dict | None] = mapped_column(
        JSON,
        nullable=True,
        comment="Preferencje dietetyczne w formacie JSON",
    )
    household_size: Mapped[int] = mapped_column(
        Integer, default=1, nullable=False
    )
    # Dane do kalkulatora zapotrzebowania kalorycznego (Śledzenie) — wzór
    # Mifflin-St Jeor, ten sam standard, na którym opierają się
    # najpopularniejsze kalkulatory tego typu (w tym NFZ). Wszystkie
    # opcjonalne — kalkulator po prostu poprosi o brakujące dane, gdy
    # użytkownik zechce z niego skorzystać.
    weight_kg: Mapped[float | None] = mapped_column(Float, nullable=True)
    height_cm: Mapped[float | None] = mapped_column(Float, nullable=True)
    age: Mapped[int | None] = mapped_column(Integer, nullable=True)
    # "male" | "female" — wzór Mifflin-St Jeor ma osobny człon dla każdej
    # płci (różnica w typowym stosunku masy mięśniowej do tłuszczowej).
    gender: Mapped[str | None] = mapped_column(String(10), nullable=True)
    # "sedentary" | "light" | "moderate" | "active" | "very_active" —
    # mnożnik aktywności fizycznej (standardowe wartości Harris-Benedict/
    # Mifflin, patrz app/services/nutrition_calculator.py).
    activity_level: Mapped[str | None] = mapped_column(String(20), nullable=True)
    # Dzienny cel kaloryczny WYBRANY przez użytkownika (kafelek albo
    # suwak w kalkulatorze) — to on jest pokazywany jako "cel" w
    # podsumowaniu dnia w Śledzeniu, niezależnie od tego, kiedy/czy
    # użytkownik ponownie przeliczy kalkulator.
    daily_kcal_goal: Mapped[int | None] = mapped_column(Integer, nullable=True)
    # Rola konta — "user" (domyślnie) albo "admin". Admin może usuwać
    # KAŻDY komentarz (nie tylko własny) i w miarę rozwoju aplikacji
    # będzie naturalnym miejscem na kolejne uprawnienia moderacyjne.
    # Nadanie roli admina NIE JEST możliwe przez żaden endpoint API —
    # celowo, żeby nikt nie mógł sam się mianować administratorem;
    # ustawia się to bezpośrednio w bazie danych.
    role: Mapped[str] = mapped_column(String(20), default="user", nullable=False)
    # Fundament pod płatną subskrypcję premium — teraz w pełni podłączone
    # pod Google Play Billing (patrz app/services/google_play_billing.py):
    # is_premium/premium_expires_at aktualizowane automatycznie po
    # zweryfikowaniu zakupu przez Google Play Developer API. Nadal można
    # też ustawić ręcznie/administracyjnie (np. konta testowe).
    is_premium: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    premium_expires_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    # Który dokładnie produkt subskrypcyjny (premium_monthly /
    # premium_yearly) — do wyświetlenia użytkownikowi "Twój plan" i do
    # ponownej weryfikacji przy odnowieniu.
    premium_product_id: Mapped[str | None] = mapped_column(String(100), nullable=True)
    # Token zakupu z Google Play — potrzebny do ponownej weryfikacji
    # stanu subskrypcji (czy nadal aktywna, czy anulowana/zwrócona) bez
    # konieczności czekania na kolejne zdarzenie od użytkownika.
    premium_purchase_token: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )

    # ── Relacje ──────────────────────────────────────────────────
    preferred_store: Mapped["Store | None"] = relationship(
        "Store", foreign_keys=[preferred_store_id]
    )
    meal_plans: Mapped[list["MealPlan"]] = relationship(
        "MealPlan", back_populates="user", cascade="all, delete-orphan"
    )
    allergens: Mapped[list["Allergen"]] = relationship(
        "Allergen",
        secondary="user_allergens",
        lazy="selectin",
    )

    def __repr__(self) -> str:
        return f"<User {self.email!r}>"


class UserAllergen(Base):
    """Tabela asocjacyjna — alergeny użytkownika."""

    __tablename__ = "user_allergens"

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        primary_key=True,
    )
    allergen_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("allergens.id", ondelete="CASCADE"),
        primary_key=True,
    )
