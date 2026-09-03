"""Przywracanie cen katalogowych po wygaśnięciu promocji.

Zatwierdzenie promocji typu "price_cut" nadpisuje `StoreProduct.price`
ceną promocyjną, żeby listy zakupów i budżety planów liczyły realny koszt
w trakcie trwania promocji (patrz approve_promotion w
app/api/v1/promotions.py).

BRAKOWAŁO odwrotnej operacji: po zakończeniu promocji nic nie wracało do
ceny regularnej. Promocja poprawnie znikała z zakładki Promocje (filtr
`valid_until >= today`), ale obniżona cena zostawała w katalogu na stałe,
więc aplikacja w nieskończoność pokazywała nieaktualne, zaniżone koszty.
"""

from __future__ import annotations

import logging
from datetime import date

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import Product, Store, StoreProduct

# Promotion importowany BEZPOŚREDNIO z modułu, a nie przez app.models —
# ten pakiet go nie reeksportuje (patrz app/models/__init__.py), więc
# import przez paczkę kończył się ImportError dopiero w RUNTIME, przy
# pierwszym przebiegu zadania w tle. Sam start aplikacji tego nie
# wychwytywał, bo import jest leniwy (wewnątrz pętli), żeby nie tworzyć
# cyklu zależności przy starcie.
from app.models.promotion import Promotion

logger = logging.getLogger(__name__)


async def restore_expired_promotion_prices(db: AsyncSession) -> int:
    """Cofa ceny promocyjne dla promocji, które już się skończyły.

    Zwraca liczbę przywróconych cen.

    Zabezpieczenie przed nadpisaniem nowszych danych: cenę cofamy TYLKO
    wtedy, gdy w katalogu nadal figuruje dokładnie ta cena promocyjna,
    którą ta promocja ustawiła. Jeśli w międzyczasie cenę zmienił scraper
    albo inna, nowsza promocja — zostawiamy ją w spokoju, bo cofnięcie do
    starej ceny regularnej byłoby cofnięciem świeższej informacji.
    """
    today = date.today()

    result = await db.execute(
        select(Promotion).where(
            Promotion.price_applied.is_(True),
            Promotion.valid_until < today,
        )
    )
    expired = list(result.scalars().all())
    if not expired:
        return 0

    restored = 0
    for promo in expired:
        store_result = await db.execute(select(Store).where(Store.name == promo.store_name))
        store = store_result.scalar_one_or_none()
        product_result = await db.execute(
            select(Product).where(Product.name == promo.product_name)
        )
        product = product_result.scalar_one_or_none()

        if store and product:
            sp_result = await db.execute(
                select(StoreProduct).where(
                    StoreProduct.store_id == store.id,
                    StoreProduct.product_id == product.id,
                )
            )
            store_product = sp_result.scalar_one_or_none()
            if store_product is not None and store_product.price == promo.promo_price:
                store_product.price = promo.regular_price
                store_product.last_verified = today
                db.add(store_product)
                restored += 1
                logger.info(
                    "Przywrócono cenę regularną %s dla %s w %s (promocja wygasła %s).",
                    promo.regular_price,
                    promo.product_name,
                    promo.store_name,
                    promo.valid_until,
                )

        # Znacznik zdejmujemy ZAWSZE — również gdy produktu już nie ma
        # albo cenę zmienił ktoś inny. Inaczej ta sama wygasła promocja
        # byłaby sprawdzana w kółko przy każdym przebiegu.
        promo.price_applied = False
        promo.is_active = False
        db.add(promo)

    await db.commit()
    return restored
