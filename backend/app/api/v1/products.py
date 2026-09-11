"""Endpointy produktów i zamienników."""

import uuid
from decimal import Decimal
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel, Field
from sqlalchemy import or_, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.api.deps import get_current_admin, get_current_user
from app.core.exceptions import NotFoundException
from app.db.session import get_db
from app.models import Product, ProductSubstitute, StoreProduct
from app.models.user import User
from app.schemas.product import ProductResponse, StoreProductResponse, SubstituteResponse
from app.services import ProductSubstitutionService


# UWAGA (naprawa bezpieczeństwa): endpointy w tym pliku były CAŁKOWICIE
# otwarte — bez tokenu każdy mógł pobrać pełny katalog produktów, sklepów
# i cen (a więc też zeskrobać całą bazę jednym skryptem). To dane, na
# których opiera się aplikacja, i nie ma powodu udostępniać ich anonimowo.
# Router chroniony JEDNĄ zależnością na poziomie całego routera, zamiast
# dopisywania Depends do każdej funkcji z osobna — trudniej o pominięcie
# przy dodawaniu kolejnego endpointu w przyszłości.
router = APIRouter(dependencies=[Depends(get_current_user)])


class BarcodeLookupResponse(BaseModel):
    """Wynik wyszukiwania po kodzie kreskowym — gotowy do wypełnienia
    formularza zgłoszenia, albo (gdy `existing_product_id` ustawione)
    do bezpośredniego wybrania istniejącego produktu bez zgłaszania
    niczego od nowa."""

    found: bool
    source: str | None = None  # "catalog" | "open_food_facts" | None
    name: str | None = None
    brand: str | None = None
    unit: str = "g"
    kcal_per_100: float | None = None
    protein_per_100: float | None = None
    fat_per_100: float | None = None
    carbs_per_100: float | None = None
    existing_product_id: uuid.UUID | None = None


@router.get(
    "/",
    response_model=list[ProductResponse],
    summary="Lista produktów",
)
async def list_products(
    skip: int = Query(0, ge=0, description="Liczba rekordów do pominięcia"),
    limit: int = Query(50, ge=1, le=200, description="Maksymalna liczba wyników"),
    search: str | None = Query(None, description="Szukaj po nazwie produktu"),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> list[Product]:
    """Zwraca listę produktów z opcjonalnym wyszukiwaniem.

    Widoczne są produkty ZAAKCEPTOWANE oraz WŁASNE zgłoszenia bieżącego
    użytkownika — te ostatnie jeszcze przed decyzją administratora, żeby
    dało się ich od razu użyć w dzienniku kalorii. Cudze zgłoszenia
    oczekujące pozostają ukryte, dopóki nie zostaną zatwierdzone.
    """
    query = select(Product).where(
        or_(
            Product.review_status == "approved",
            Product.created_by_user_id == current_user.id,
        )
    )

    if search:
        query = query.where(Product.name.ilike(f"%{search}%"))

    query = query.order_by(Product.name).offset(skip).limit(limit)

    result = await db.execute(query)
    return list(result.scalars().all())


@router.get(
    "/barcode/{barcode}",
    response_model=BarcodeLookupResponse,
    summary="Wyszukaj produkt po kodzie kreskowym",
)
async def lookup_barcode(
    barcode: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> BarcodeLookupResponse:
    """Dwuetapowe wyszukiwanie: najpierw WŁASNY katalog (produkty
    zeskanowane i zgłoszone wcześniej przez kogokolwiek — natychmiastowe,
    zawiera cenę), potem Open Food Facts jako zewnętrzne źródło (bez ceny,
    tylko nazwa i wartości odżywcze — cenę użytkownik wpisuje sam).

    404, gdy nic nie znaleziono w ŻADNYM źródle — frontend pokazuje wtedy
    pusty formularz zgłoszenia z już wpisanym kodem kreskowym, zamiast
    blokować użytkownika.
    """
    # 1. Własny katalog — widoczne to, co widziałby zwykły GET /products
    # (zaakceptowane PLUS własne zgłoszenia), żeby nie pokazywać komuś
    # cudzego jeszcze niezatwierdzonego zgłoszenia jako "gotowy produkt".
    result = await db.execute(
        select(Product).where(
            Product.barcode == barcode,
            or_(
                Product.review_status == "approved",
                Product.created_by_user_id == current_user.id,
            ),
        )
    )
    existing = result.scalar_one_or_none()
    if existing is not None:
        return BarcodeLookupResponse(
            found=True,
            source="catalog",
            name=existing.name,
            brand=existing.brand,
            unit=existing.unit,
            kcal_per_100=(existing.nutrition_per_100 or {}).get("kcal"),
            protein_per_100=(existing.nutrition_per_100 or {}).get("protein"),
            fat_per_100=(existing.nutrition_per_100 or {}).get("fat"),
            carbs_per_100=(existing.nutrition_per_100 or {}).get("carbs"),
            existing_product_id=existing.id,
        )

    # 2. Open Food Facts — zewnętrzne, może nie znać lokalnej marki.
    from app.services.barcode_lookup import lookup_barcode_external

    off_result = await lookup_barcode_external(barcode)
    if off_result is not None:
        return BarcodeLookupResponse(
            found=True,
            source="open_food_facts",
            name=off_result.name,
            brand=off_result.brand,
            unit="g",
            kcal_per_100=off_result.kcal_per_100,
            protein_per_100=off_result.protein_per_100,
            fat_per_100=off_result.fat_per_100,
            carbs_per_100=off_result.carbs_per_100,
            existing_product_id=None,
        )

    return BarcodeLookupResponse(found=False, source=None, name=None)


@router.get(
    "/mine",
    response_model=list[ProductResponse],
    summary="Produkty zgłoszone przeze mnie — dowolny status",
)
async def list_my_products(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> list[Product]:
    """Wszystkie WŁASNE zgłoszenia użytkownika, niezależnie od statusu.

    NAPRAWA BRAKUJĄCEJ FUNKCJI: zgłoszony produkt zapisywał się
    w bazie (endpoint /submit działał), ale nigdzie w aplikacji nie było
    miejsca, które by go pokazało — ekran katalogu (`ProductsScreen`)
    wyświetla wyłącznie produkty POWIĄZANE ZE SKLEPEM (StoreProduct),
    a zgłoszenie świadomie nie tworzy takiego powiązania (patrz
    komentarz w submit_product). Efekt: produkt istniał w bazie, ale dla
    użytkownika wyglądało to tak, jakby zniknął bez śladu.
    """
    result = await db.execute(
        select(Product)
        .where(Product.created_by_user_id == current_user.id)
        .order_by(Product.created_at.desc())
    )
    return list(result.scalars().all())


# WAŻNA KOLEJNOŚĆ: ta trasa MUSI stać PRZED "/{product_id}" niżej.
# FastAPI dopasowuje trasy w kolejności rejestracji — gdyby "/{product_id}"
# było pierwsze, żądanie GET /products/mine trafiałoby właśnie w nie,
# z "mine" jako wartością product_id. Ponieważ ta wartość nie jest
# poprawnym UUID, Pydantic odrzucał żądanie błędem "Input should be
# a valid uuid" — dokładnie ten zgłoszony błąd.
@router.get(
    "/{product_id}",
    response_model=ProductResponse,
    summary="Szczegóły produktu",
)
async def get_product(
    product_id: UUID,
    db: AsyncSession = Depends(get_db),
) -> Product:
    """Zwraca szczegóły produktu wraz z dostępnością w sklepach."""
    result = await db.execute(
        select(Product)
        .options(selectinload(Product.store_products))
        .where(Product.id == product_id)
    )
    product = result.scalar_one_or_none()
    if product is None:
        raise NotFoundException(
            detail=f"Produkt o ID {product_id} nie został znaleziony"
        )
    return product


@router.get(
    "/{product_id}/substitutes",
    response_model=list[SubstituteResponse],
    summary="Zamienniki produktu",
)
async def get_product_substitutes(
    product_id: UUID,
    store_id: UUID | None = Query(
        None, description="ID sklepu do filtrowania dostępnych zamienników"
    ),
    db: AsyncSession = Depends(get_db),
) -> list[dict]:
    """Zwraca listę zamienników dla danego produktu.

    Opcjonalnie filtruje zamienniki po dostępności w wybranym sklepie.
    """
    # Sprawdź czy produkt istnieje
    product_result = await db.execute(
        select(Product).where(Product.id == product_id)
    )
    if product_result.scalar_one_or_none() is None:
        raise NotFoundException(
            detail=f"Produkt o ID {product_id} nie został znaleziony"
        )

    if store_id is None:
        result = await db.execute(
            select(Product)
            .join(ProductSubstitute, ProductSubstitute.substitute_product_id == Product.id)
            .where(ProductSubstitute.original_product_id == product_id)
        )
        return [
            {
                "id": p.id,
                "name": p.name,
                "brand": p.brand,
                "price": None,
                "similarity_score": None,
            }
            for p in result.scalars().all()
        ]

    substitution_service = ProductSubstitutionService(db)
    results = await substitution_service.find_substitutes(
        product_id=product_id, store_id=store_id, limit=10
    )
    if not results:
        # Brak predefiniowanych zamienników (tabela product_substitutes) —
        # użyj wyszukiwania po podobieństwie wartości odżywczych w tym samym
        # dziale sklepu, tak jak robi to automatyczna obsługa wycofania produktu.
        results = await substitution_service.auto_find_similar(
            product_id=product_id, store_id=store_id, limit=10
        )
    response_list = []
    for r in results:
        prod = r["product"]
        store_prod = r.get("store_product")
        kcal = None
        if prod.nutrition_per_100 and "kcal" in prod.nutrition_per_100:
            try:
                kcal = int(prod.nutrition_per_100["kcal"])
            except:
                pass
        response_list.append({
            "id": prod.id,
            "name": prod.name,
            "brand": prod.brand,
            "price": store_prod.price if store_prod else None,
            "kcal": kcal,
            "similarity_score": r.get("similarity_score")
        })
    return response_list


# ══════════════════════════════════════════════════════════════════
# PRODUKTY ZGŁASZANE PRZEZ UŻYTKOWNIKÓW
# ══════════════════════════════════════════════════════════════════
class ProductSubmission(BaseModel):
    """Zgłoszenie własnego produktu do katalogu.

    Wymagane są tylko nazwa i cena — makroskładniki są opcjonalne, bo
    użytkownik nie zawsze ma etykietę pod ręką, a produkt bez nich i tak
    jest przydatny na liście zakupów. Przy braku danych odżywczych wpis
    w dzienniku kalorii doda po prostu 0 kcal.
    """

    name: str = Field(..., min_length=2, max_length=300)
    price: Decimal = Field(..., gt=0, le=10_000)
    unit: str = Field("szt", max_length=20)
    brand: str | None = Field(None, max_length=200)
    kcal_per_100: float | None = Field(None, ge=0, le=2_000)
    protein_per_100: float | None = Field(None, ge=0, le=200)
    fat_per_100: float | None = Field(None, ge=0, le=200)
    carbs_per_100: float | None = Field(None, ge=0, le=200)
    # OPCJONALNE — sklepy, w których zgłaszający chciałby widzieć ten
    # produkt. Sama lista niczego jeszcze nie tworzy; dopiero akceptacja
    # administratora zamienia każdy wskazany sklep na prawdziwy wiersz
    # StoreProduct z podaną ceną (patrz review_product niżej).
    store_ids: list[uuid.UUID] = []
    # OPCJONALNE — jeśli produkt zgłoszono po zeskanowaniu kodu, zapisujemy
    # go, żeby KOLEJNE skanowanie tego samego produktu (przez kogokolwiek)
    # trafiało od razu w "własny katalog" (najszybsza, pierwsza gałąź
    # w lookup_barcode), zamiast za każdym razem pytać Open Food Facts.
    barcode: str | None = Field(None, max_length=50)


@router.post(
    "/submit",
    response_model=ProductResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Zgłoś własny produkt do katalogu",
)
async def submit_product(
    payload: ProductSubmission,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> Product:
    """Dodaje produkt oczekujący na akceptację administratora.

    Produkt jest od razu widoczny dla ZGŁASZAJĄCEGO (patrz filtr
    w list_products), więc może go użyć w dzienniku kalorii bez czekania.
    Dla pozostałych pojawi się dopiero po zatwierdzeniu.

    ŚWIADOMIE nie trafia do generatora przepisów ani planów posiłków:
    tamte korzystają z produktów powiązanych ze sklepami (StoreProduct),
    a zgłoszenie takiego powiązania nie ma. Dopiero administrator może
    je utworzyć przy akceptacji.
    """
    from app.core.rate_limit import enforce_user_rate_limit, product_submission_limiter

    enforce_user_rate_limit(
        product_submission_limiter, current_user.id, "zgłaszanie produktów"
    )

    nutrition = None
    if payload.kcal_per_100 is not None:
        nutrition = {
            "kcal": payload.kcal_per_100,
            "protein": payload.protein_per_100 or 0,
            "fat": payload.fat_per_100 or 0,
            "carbs": payload.carbs_per_100 or 0,
            "fiber": 0,
        }

    product = Product(
        name=payload.name.strip(),
        brand=(payload.brand or "").strip() or None,
        unit=payload.unit.strip() or "szt",
        default_quantity=Decimal(1),
        nutrition_per_100=nutrition,
        created_by_user_id=current_user.id,
        review_status="pending",
        submitted_price=payload.price,
        requested_store_ids=[str(sid) for sid in payload.store_ids] or None,
        barcode=payload.barcode.strip() if payload.barcode else None,
    )
    db.add(product)
    try:
        await db.commit()
    except IntegrityError:
        # Ktoś inny zdążył zgłosić produkt z tym samym kodem kreskowym
        # (kolumna ma ograniczenie unikalności) — nie jest to prawdziwy
        # błąd użytkownika, tylko wyścig dwóch zgłoszeń naraz.
        await db.rollback()
        raise HTTPException(
            status_code=409,
            detail="Produkt z tym kodem kreskowym został już zgłoszony przez kogoś innego.",
        )
    await db.refresh(product)
    return product


@router.put(
    "/{product_id}",
    response_model=ProductResponse,
    summary="Edytuj własny zgłoszony produkt",
)
async def update_own_product(
    product_id: uuid.UUID,
    payload: ProductSubmission,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> Product:
    """Edytuje WŁASNE zgłoszenie — nie działa na produktach oficjalnych
    (created_by_user_id puste) ani na cudzych zgłoszeniach.

    Edycja cofa produkt do statusu "pending", nawet jeśli był już
    zatwierdzony — inaczej użytkownik mógłby podmienić dane zatwierdzonego
    produktu (np. na coś nieodpowiedniego) bez ponownej moderacji.
    """
    product = await db.get(Product, product_id)
    if product is None:
        raise HTTPException(status_code=404, detail="Nie znaleziono produktu")
    if product.created_by_user_id != current_user.id:
        raise HTTPException(
            status_code=403, detail="Możesz edytować tylko własne zgłoszenia."
        )

    nutrition = None
    if payload.kcal_per_100 is not None:
        nutrition = {
            "kcal": payload.kcal_per_100,
            "protein": payload.protein_per_100 or 0,
            "fat": payload.fat_per_100 or 0,
            "carbs": payload.carbs_per_100 or 0,
            "fiber": 0,
        }

    product.name = payload.name.strip()
    product.brand = (payload.brand or "").strip() or None
    product.unit = payload.unit.strip() or "szt"
    product.nutrition_per_100 = nutrition
    product.submitted_price = payload.price
    product.requested_store_ids = [str(sid) for sid in payload.store_ids] or None
    # Tylko gdy jawnie podane — formularz edycji nie zawsze wysyła kod
    # kreskowy (np. gdy edytujący nie skanował ponownie), więc pusta
    # wartość NIE MA kasować już zapisanego kodu.
    if payload.barcode:
        product.barcode = payload.barcode.strip()
    # Patrz docstring — każda edycja wraca do kolejki moderacji.
    product.review_status = "pending"

    db.add(product)
    try:
        await db.commit()
    except IntegrityError:
        await db.rollback()
        raise HTTPException(
            status_code=409,
            detail="Ten kod kreskowy jest już przypisany do innego produktu.",
        )
    await db.refresh(product)
    return product


@router.delete(
    "/{product_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    response_model=None,
    summary="Usuń własny zgłoszony produkt",
)
async def delete_own_product(
    product_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> None:
    """Usuwa WŁASNE zgłoszenie. Nie działa na produktach oficjalnych ani
    cudzych zgłoszeniach — te może usunąć wyłącznie administrator
    (patrz osobny endpoint admina niżej, jeśli dodany)."""
    product = await db.get(Product, product_id)
    if product is None:
        raise HTTPException(status_code=404, detail="Nie znaleziono produktu")
    if product.created_by_user_id != current_user.id:
        raise HTTPException(
            status_code=403, detail="Możesz usunąć tylko własne zgłoszenia."
        )
    await db.delete(product)
    await db.commit()


@router.get(
    "/admin/pending",
    response_model=list[ProductResponse],
    summary="Produkty zgłoszone przez użytkowników (admin)",
)
async def list_pending_products(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_admin),
) -> list[Product]:
    result = await db.execute(
        select(Product)
        .where(Product.review_status == "pending")
        .order_by(Product.created_at.desc())
    )
    return list(result.scalars().all())


@router.post(
    "/admin/{product_id}/review",
    status_code=status.HTTP_204_NO_CONTENT,
    response_model=None,
    summary="Zatwierdź lub odrzuć zgłoszony produkt (admin)",
)
async def review_product(
    product_id: uuid.UUID,
    approve: bool = Query(..., description="true = zatwierdź, false = odrzuć"),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_admin),
) -> None:
    product = await db.get(Product, product_id)
    if product is None:
        raise HTTPException(status_code=404, detail="Nie znaleziono produktu")

    product.review_status = "approved" if approve else "rejected"
    db.add(product)

    # Przy akceptacji: każdy sklep zaproponowany przez zgłaszającego
    # zamieniamy na prawdziwy wiersz StoreProduct z podaną ceną — dopiero
    # to sprawia, że produkt faktycznie pojawia się w bazie danego sklepu
    # (a nie tylko w ogólnym katalogu). Pomijamy sklepy, które już mają
    # jakiś wpis dla tego produktu (ograniczenie unikalności store+product
    # i tak by to odrzuciło, ale sprawdzamy jawnie, żeby dać się temu
    # wykonać bezpiecznie również przy PONOWNEJ akceptacji po edycji).
    created_links = 0
    if approve and product.requested_store_ids:
        from app.models.product import StoreProduct
        from app.models.store import Store

        for store_id_str in product.requested_store_ids:
            try:
                store_id = uuid.UUID(store_id_str)
            except (ValueError, TypeError):
                continue

            store = await db.get(Store, store_id)
            if store is None:
                continue

            existing = await db.execute(
                select(StoreProduct).where(
                    StoreProduct.store_id == store_id,
                    StoreProduct.product_id == product.id,
                )
            )
            if existing.scalar_one_or_none() is not None:
                continue

            db.add(
                StoreProduct(
                    store_id=store_id,
                    product_id=product.id,
                    price=product.submitted_price or 0,
                )
            )
            created_links += 1

    # Powiadomienie dla zgłaszającego — bez niego nigdy by się nie
    # dowiedział, co się stało z jego zgłoszeniem.
    if product.created_by_user_id:
        from app.models.notification import Notification

        n = Notification(
            user_id=product.created_by_user_id,
            notification_type="product_reviewed",
            message=(
                f'Twój produkt "{product.name}" został '
                + ("dodany do katalogu." if approve else "odrzucony.")
            ),
        )
        db.add(n)

    await db.commit()

    if product.created_by_user_id:
        try:
            from app.services.push import is_push_enabled, push_for_notification

            if is_push_enabled():
                await push_for_notification(db, n)
        except Exception:
            pass
