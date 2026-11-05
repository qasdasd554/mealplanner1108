"""Premium receipt preview and atomic import into the caller's pantry."""

import hashlib
import json
import uuid
from datetime import datetime, timedelta, timezone
from decimal import Decimal

import jwt
from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel, Field, ValidationError
from sqlalchemy import func, or_, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_premium
from app.core.config import settings
from app.core.language import account_text
from app.core.markets import account_country
from app.core.rate_limit import SlidingWindowRateLimiter, enforce_user_rate_limit
from app.db.session import get_db
from app.models import PantryItem, PantryReceipt, Product, User
from app.services.ai_recipe_import import AIRecipeImportError
from app.services.pantry_receipt_recognition import (
    InvalidReceiptPhoto, InvalidReceiptResult, MAX_PHOTO_BASE64, MAX_RECEIPT_ITEMS,
    ReceiptLine, ReceiptUnit, recognize_receipt,
)
from app.services.pantry_shopping_sync import sync_product_in_shopping_lists
from app.services.product_measures import canonical_measure_code
from app.services.system_content_language import english_ingredient_name_in, ingredient_display_name

router = APIRouter(prefix="/receipt")
scan_limiter = SlidingWindowRateLimiter(max_events=6, window_seconds=300)
save_limiter = SlidingWindowRateLimiter(max_events=12, window_seconds=300)


class ReceiptPreview(BaseModel):
    token: str | None = None
    items: list[ReceiptLine]


class ReceiptSelection(BaseModel):
    index: int = Field(ge=0, lt=MAX_RECEIPT_ITEMS)
    quantity: Decimal = Field(ge=Decimal("0.001"), le=100_000, decimal_places=3)
    unit: ReceiptUnit


class ReceiptImport(BaseModel):
    token: str = Field(min_length=1, max_length=100_000)
    items: list[ReceiptSelection] = Field(min_length=1, max_length=MAX_RECEIPT_ITEMS)


class ReceiptImportResult(BaseModel):
    saved_count: int
    skipped_count: int
    already_saved: bool = False


def _preview_token(user: User, receipt_id: uuid.UUID, lines: list[ReceiptLine]) -> str:
    return jwt.encode({
        "sub": str(user.id), "type": "pantry-receipt", "jti": str(receipt_id),
        "exp": datetime.now(timezone.utc) + timedelta(hours=1),
        "items": [line.model_dump() for line in lines],
    }, settings.SECRET_KEY, algorithm=settings.ALGORITHM)


def _read_preview(payload: ReceiptImport, user: User) -> tuple[uuid.UUID, list[ReceiptLine]]:
    try:
        claims = jwt.decode(payload.token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM],
                            options={"require": ["exp", "sub", "jti", "type"]})
        if claims["type"] != "pantry-receipt" or claims["sub"] != str(user.id):
            raise ValueError
        receipt_id = uuid.UUID(claims["jti"])
        lines = [ReceiptLine.model_validate(line) for line in claims["items"]]
        indexes = {item.index for item in payload.items}
        if len(indexes) != len(payload.items) or max(indexes) >= len(lines):
            raise ValueError
        return receipt_id, lines
    except (jwt.InvalidTokenError, KeyError, TypeError, ValueError, ValidationError) as exc:
        raise HTTPException(422, account_text(user,
            "Podgląd paragonu wygasł lub jest nieprawidłowy. Zeskanuj go ponownie.",
            "This receipt preview has expired or is invalid. Scan the receipt again.",
        )) from exc


async def _read_photo(request: Request) -> str:
    # Bound the body even for a client that sends chunked data without Content-Length.
    body = bytearray()
    async for chunk in request.stream():
        if len(body) + len(chunk) > MAX_PHOTO_BASE64 + 1024:
            raise InvalidReceiptPhoto
        body.extend(chunk)
    try:
        payload = json.loads(body)
    except (ValueError, RecursionError) as exc:
        raise InvalidReceiptPhoto from exc
    photo = payload.get("photo") if isinstance(payload, dict) else None
    if not isinstance(photo, str) or not 0 < len(photo) <= MAX_PHOTO_BASE64:
        raise InvalidReceiptPhoto
    return photo


@router.post("/scan", response_model=ReceiptPreview)
async def scan_receipt(
    request: Request,
    user: User = Depends(get_current_premium),
    db: AsyncSession = Depends(get_db),
) -> ReceiptPreview:
    enforce_user_rate_limit(scan_limiter, user.id, "receipt scan")
    # The user fields are already loaded. Release the pool connection before
    # waiting for the image upload or the external recognition service.
    await db.close()
    try:
        photo = await _read_photo(request)
        lines = await recognize_receipt(photo, country_code=account_country(user))
    except InvalidReceiptPhoto as exc:
        raise HTTPException(422, account_text(user,
            "Wybierz zdjęcie JPG, PNG lub WebP do 8 MB.",
            "Choose a JPG, PNG or WebP photo up to 8 MB.",
        )) from exc
    except InvalidReceiptResult as exc:
        raise HTTPException(422, account_text(user,
            "Nie udało się odczytać paragonu. Spróbuj zrobić wyraźniejsze zdjęcie.",
            "We couldn't read the receipt. Try taking a clearer photo.",
        )) from exc
    except AIRecipeImportError as exc:
        raise HTTPException(503, account_text(user,
            "Skanowanie paragonów jest chwilowo niedostępne.",
            "Receipt scanning is temporarily unavailable.",
        )) from exc
    if not lines:
        return ReceiptPreview(items=[])
    digest = hashlib.sha256(photo.encode("ascii")).hexdigest()
    return ReceiptPreview(items=lines, token=_preview_token(user, uuid.uuid5(user.id, digest), lines))


def _stock_amount(quantity: Decimal, unit: str) -> tuple[Decimal, str]:
    unit = canonical_measure_code(unit)
    if unit in {"kg", "l"}:
        return quantity * 1000, {"kg": "g", "l": "ml"}[unit]
    return quantity, unit


async def _catalogue_candidates(db: AsyncSession, names: set[str], country: str) -> dict[str, list[Product]]:
    # Only use an exact generic identity. Retail packs with unknown size are
    # kept separate, and shop availability is never inferred from a receipt.
    match = (Product.submitted_country_code == country) & func.lower(Product.name).in_(names)
    if country == "GB":
        match = or_(match, english_ingredient_name_in(Product, names))
    products = (await db.execute(select(Product).where(
        match, Product.review_status == "approved", Product.created_by_user_id.is_(None),
        Product.barcode.is_(None),
    ))).scalars().all()
    result: dict[str, list[Product]] = {}
    for product in products:
        name = ingredient_display_name(product, country_code=country).casefold()
        if name in names:
            result.setdefault(name, []).append(product)
    return result


def _catalogue_match(candidates: list[Product], unit: str) -> Product | None:
    compatible = [
        product for product in candidates
        if unit != "opak" and _stock_amount(Decimal(1), product.unit)[1] == unit
    ]
    return compatible[0] if len(compatible) == 1 else None


@router.post("/save", response_model=ReceiptImportResult)
async def save_receipt(
    payload: ReceiptImport,
    user: User = Depends(get_current_premium),
    db: AsyncSession = Depends(get_db),
) -> ReceiptImportResult:
    enforce_user_rate_limit(save_limiter, user.id, "receipt save")
    receipt_id, lines = _read_preview(payload, user)
    # Serialise receipt saves for this account, including concurrent retries.
    await db.execute(select(User.id).where(User.id == user.id).with_for_update())
    previous = await db.get(PantryReceipt, receipt_id)
    if previous is not None:
        return ReceiptImportResult(saved_count=previous.saved_count,
                                   skipped_count=previous.skipped_count, already_saved=True)
    country = account_country(user)
    candidates = await _catalogue_candidates(
        db, {lines[selection.index].name.casefold() for selection in payload.items}, country,
    )
    grouped: dict[uuid.UUID, tuple[str, str, Decimal]] = {}
    for selection in payload.items:
        name = lines[selection.index].name
        product = _catalogue_match(candidates.get(name.casefold(), []), selection.unit)
        product_id = product.id if product is not None else uuid.uuid5(
            user.id, f"receipt-food:{country}:{selection.unit}:{name.casefold()}",
        )
        existing = grouped.get(product_id)
        quantity = selection.quantity + (existing[2] if existing else Decimal(0))
        grouped[product_id] = (name, selection.unit, quantity)

    saved_ids = []
    try:
        for product_id, (name, unit, quantity) in grouped.items():
            if quantity > 1_000_000:
                continue
            stock = (await db.execute(select(PantryItem).where(
                PantryItem.user_id == user.id, PantryItem.product_id == product_id,
            ).with_for_update())).scalar_one_or_none()
            if stock is not None:
                if stock.quantity is None or stock.unit is None:
                    continue
                amount, stock_unit = _stock_amount(stock.quantity, stock.unit)
                if stock_unit != unit or amount + quantity > 1_000_000:
                    continue
                stock.quantity = amount + quantity
                stock.unit = unit
            else:
                if await db.get(Product, product_id) is None:
                    db.add(Product(id=product_id, name=name, unit=unit,
                        review_status="private", created_by_user_id=user.id,
                        submitted_country_code=country))
                    await db.flush()
                db.add(PantryItem(user_id=user.id, product_id=product_id, quantity=quantity, unit=unit))
            saved_ids.append(product_id)

        result = ReceiptImportResult(saved_count=len(saved_ids), skipped_count=len(grouped) - len(saved_ids))
        if saved_ids:
            db.add(PantryReceipt(id=receipt_id, user_id=user.id,
                                 saved_count=result.saved_count, skipped_count=result.skipped_count))
            await db.flush()
            for product_id in saved_ids:
                await sync_product_in_shopping_lists(db, user.id, product_id)
            await db.commit()
        return result
    except IntegrityError as exc:
        await db.rollback()
        raise HTTPException(409, account_text(user,
            "Spiżarnia zmieniła się podczas zapisu. Spróbuj ponownie.",
            "Your pantry changed while saving. Please try again.",
        )) from exc
