"""Model ORM promocji sklepowych."""

from __future__ import annotations

import uuid
from datetime import date, datetime
from decimal import Decimal

from sqlalchemy import (
    Boolean,
    Date,
    DateTime,
    ForeignKey,
    Integer,
    Numeric,
    String,
    Text,
    func,
)
from sqlalchemy.dialects.postgresql import JSON, UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.session import Base


class Promotion(Base):
    """Promocja na produkt w konkretnym sklepie.

    Typy promocji (promo_type):
      - "price_cut"    → obniżka ceny regulowanej (np. 7.99 → 5.49 zł)
      - "multipack"    → wielosztuka (np. 2+1 gratis, 3 w cenie 2)
      - "loyalty_card" → cena z kartą lojalnościową (Moja Biedronka / Lidl Plus)
      - "weekend"      → promocja weekendowa / jednodniowa
      - "clearance"    → wyprzedaż / cena ostateczna
    """

    __tablename__ = "promotions"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        server_default=func.gen_random_uuid(),
    )

    # Powiązanie z produktem i sklepem
    product_name: Mapped[str] = mapped_column(
        String(300), nullable=False, index=True,
        comment="Nazwa produktu (np. 'Masło extra 200g')",
    )
    store_name: Mapped[str] = mapped_column(
        String(100), nullable=False, index=True,
        comment="Nazwa sklepu (Biedronka / Lidl / Dino)",
    )

    # Ceny
    regular_price: Mapped[Decimal] = mapped_column(
        Numeric(10, 2), nullable=False,
        comment="Cena regularna w PLN",
    )
    promo_price: Mapped[Decimal] = mapped_column(
        Numeric(10, 2), nullable=False,
        comment="Cena promocyjna w PLN",
    )

    # Typ i szczegóły promocji
    promo_type: Mapped[str] = mapped_column(
        String(50), nullable=False, default="price_cut",
        comment="Typ: price_cut, multipack, loyalty_card, weekend, clearance",
    )
    promo_description: Mapped[str | None] = mapped_column(
        Text, nullable=True,
        comment="Opis np. '2+1 gratis', '-30%', 'Z kartą Moja Biedronka'",
    )
    promo_details: Mapped[dict | None] = mapped_column(
        JSON, nullable=True,
        comment="Dodatkowe dane: min_qty, free_qty, card_required, etc.",
    )

    # Ważność
    valid_from: Mapped[date] = mapped_column(
        Date, nullable=False,
        comment="Data rozpoczęcia promocji",
    )
    valid_until: Mapped[date] = mapped_column(
        Date, nullable=False,
        comment="Data zakończenia promocji",
    )

    # Źródło danych
    source: Mapped[str | None] = mapped_column(
        String(100), nullable=True,
        comment="Źródło: gazetka, aplikacja, paragon_user, scraper",
    )
    requires_loyalty_card: Mapped[bool] = mapped_column(
        Boolean, nullable=False, default=False,
        comment="Czy wymaga karty lojalnościowej",
    )

    # Audyt
    # Czy zatwierdzenie tej promocji faktycznie NADPISAŁO cenę bazową
    # produktu w katalogu (StoreProduct.price). Bez tego znacznika nie
    # da się po wygaśnięciu ustalić, którym promocjom trzeba cenę cofnąć
    # — a bez cofania obniżona cena zostawała w katalogu NA ZAWSZE
    # (promocja znikała z zakładki Promocje, ale listy zakupów i budżety
    # planów dalej liczyły po cenie promocyjnej).
    price_applied: Mapped[bool] = mapped_column(
        Boolean, default=False, nullable=False, server_default="false"
    )
    is_active: Mapped[bool] = mapped_column(
        Boolean, nullable=False, default=True,
    )
    # Status akceptacji — istotny TYLKO dla promocji znalezionych
    # automatycznie przez AI (source="ai_scan"). Promocje z innych źródeł
    # (ręczne, stary scraper HTML) mają domyślnie "approved", żeby nie
    # zmieniać ich dotychczasowego zachowania.
    #   "approved" — zastosowana, wpływa na ceny widoczne w aplikacji
    #   "pending"  — czeka na akceptację administratora
    #   "rejected" — administrator odrzucił, NIE wpływa na ceny
    review_status: Mapped[str] = mapped_column(
        String(20), nullable=False, default="approved",
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False,
    )
    updated_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), onupdate=func.now(), nullable=True,
    )

    def __repr__(self) -> str:
        return (
            f"<Promotion {self.product_name!r} @ {self.store_name}: "
            f"{self.regular_price}→{self.promo_price} ({self.promo_type})>"
        )

    @property
    def savings(self) -> Decimal:
        """Ile użytkownik oszczędza."""
        return self.regular_price - self.promo_price

    @property
    def savings_percent(self) -> int:
        """Procent oszczędności."""
        if self.regular_price <= 0:
            return 0
        return round(float(self.savings / self.regular_price) * 100)
