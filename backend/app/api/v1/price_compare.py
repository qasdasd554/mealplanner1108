"""Porównywanie cen planu posiłków między sklepami.

UWAGA (naprawa): suma tutaj wcześniej różniła się od sumy na liście
zakupów, bo liczono ją INACZEJ — tu proporcjonalnie do dokładnie
potrzebnej ilości (np. 0.3 opakowania = 30% ceny), a na liście zakupów
zaokrąglano W GÓRĘ do pełnych opakowań (bo tyle realnie się kupuje —
sklep nie sprzeda 30% kostki masła). Teraz obie strony liczą dokładnie
tak samo, korzystając z tych samych funkcji konwersji jednostek co
``ShoppingListBuilder``.
"""

import math
import uuid
from datetime import date
from decimal import Decimal
from typing import List

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy import exists, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import aliased, selectinload

from app.api.deps import get_current_user, get_db
from app.core.language import account_text
from app.core.markets import account_country
from app.models.meal_plan import MealPlan, MealPlanEntry
from app.db.uk_store_catalog import UK_STORES
from app.models.recipe import Recipe, RecipeIngredient
from app.models.product import Product, StoreProduct
from app.models.store import Store
from app.models.user import User
from app.models.pantry import PantryItem
from app.models.regional_product_offer import RegionalProductOffer
from app.services.nutrition_calculator import grams_to_quantity, quantity_to_grams
from app.services.regional_requirements import aggregate_regional_requirements, subtract_regional_quantity
from app.services.regional_offer_pricing import select_uk_offer_quote
from app.services.market_catalog import reviewed_uk_offer_conditions, utc_market_date
from app.services.regional_shopping import (
    regional_pantry_coverage, regional_snapshot_requirement,
    frozen_regional_purchase_quote,
)

router = APIRouter()
from app.services.uk_ons_pricing import quote_national_requirement

class PriceCompareItem(BaseModel):
    product_name: str
    quantity_needed: float
    unit: str
    price_in_store: float
    # Marka własna sklepu dla tego produktu (np. "Mleczna Dolina"), jeśli
    # potwierdzona — puste, jeśli w tej kategorii sklep nie ma marki własnej.
    store_brand_name: str | None = None
    price_is_estimated: bool = True
    last_verified: date | None = None
    regional_offer_id: uuid.UUID | None = None
    package_quantity: float | None = None
    package_unit: str | None = None
    package_count: int | None = None
    purchased_quantity: float | None = None
    price_per_package: float | None = None
    price_source: dict | None = None
    offer_fingerprint: str | None = None
    is_from_pantry: bool = False
    is_checked: bool = False

class PriceCompareStoreResult(BaseModel):
    store_id: uuid.UUID
    store_name: str
    total_price: float | None
    is_cheapest: bool
    savings_vs_most_expensive: float
    items: List[PriceCompareItem]
    has_estimated_prices: bool = True
    is_complete: bool = True
    missing_products: List[str] = Field(default_factory=list)
    currency_code: str = "PLN"


def _uk_comparison_item(quote, *, fingerprint=None, checked=False):
    return PriceCompareItem(
        product_name=quote.name_en, quantity_needed=float(quote.required_quantity), unit=quote.unit,
        price_in_store=float(quote.total_price), price_is_estimated=quote.price_is_estimated,
        last_verified=quote.last_verified, regional_offer_id=quote.offer_id,
        package_quantity=float(quote.package_quantity) if quote.package_quantity is not None else None,
        package_unit=quote.unit if quote.package_quantity is not None else None,
        package_count=quote.package_count,
        purchased_quantity=float(quote.purchased_quantity) if quote.package_quantity is not None else None,
        price_per_package=float(quote.price_per_package) if quote.price_per_package is not None else None,
        price_source=quote.price_source, offer_fingerprint=fingerprint, is_checked=checked)


def _has_national_reference(results):
    return any((item.price_source or {}).get("provider") == "ons_national_average"
        for result in results for item in result.items)


def _positive_finite_float(value) -> float | None:
    """Nieznana/nieprawidłowa cena lub gramatura nie oznacza darmowego produktu."""
    try:
        number = float(value)
    except (TypeError, ValueError, OverflowError):
        return None
    return number if math.isfinite(number) and number > 0 else None


async def _compare_uk_prices(db, meal_plan, stores) -> list[PriceCompareStoreResult]:
    """Price exact aggregated requirements using reviewed local whole packs.

    PL package/default quantities and name-based mass/volume guesses never
    enter this branch. Missing provenance or quantity is unknown, not £0.
    """
    requirements = aggregate_regional_requirements(meal_plan)
    from app.services.system_content_language import ingredient_display_name
    if not requirements:
        return []
    as_of = utc_market_date()
    offers = (await db.execute(select(RegionalProductOffer).where(
        RegionalProductOffer.store_id.in_([store.id for store in stores]),
        RegionalProductOffer.product_id.in_(list(requirements)),
        *reviewed_uk_offer_conditions(as_of=as_of),
    ))).scalars().all()
    pantry = {}
    if (meal_plan.preferences or {}).get("include_pantry", True):
        pantry = {row.product_id: row for row in (await db.execute(select(PantryItem).where(
            PantryItem.user_id == meal_plan.user_id,
            PantryItem.product_id.in_(list(requirements)),
        ))).scalars().all()}
    by_pair: dict[tuple[uuid.UUID, uuid.UUID], list] = {}
    by_id = {offer.id: offer for offer in offers}
    for offer in offers:
        by_pair.setdefault((offer.store_id, offer.product_id), []).append(offer)
    results = []
    for store in stores:
        total = Decimal("0.00")
        items = []
        missing = []
        for product_id, requirement in requirements.items():
            quote = None
            name = ingredient_display_name(requirement.product, country_code="GB") if requirement.product else str(product_id)
            if requirement.quantity is not None and requirement.unit is not None:
                covered = regional_pantry_coverage(
                    requirement.product, requirement.quantity, requirement.unit,
                    pantry.get(product_id),
                ) if requirement.product is not None else Decimal(0)
                if covered > 0:
                    items.append(PriceCompareItem(
                        product_name=name,
                        quantity_needed=float(covered), unit=requirement.unit,
                        price_in_store=0, price_is_estimated=False, is_from_pantry=True,
                    ))
                purchase_quantity = subtract_regional_quantity(requirement.quantity, covered)
                if purchase_quantity <= 0:
                    continue
                quote = select_uk_offer_quote(
                    by_pair.get((store.id, product_id), []), product_id=product_id,
                    store_id=store.id, quantity=purchase_quantity,
                    unit=requirement.unit, as_of=as_of,
                )
                if quote is None:
                    quote = quote_national_requirement(requirement.product, purchase_quantity,
                        requirement.unit, store_id=store.id, as_of=as_of)
            if quote is None:
                missing.append(name)
                continue
            total += quote.total_price
            items.append(_uk_comparison_item(quote,
                fingerprint=by_id[quote.offer_id].fingerprint if quote.offer_id is not None else None))
        results.append(PriceCompareStoreResult(
            store_id=store.id, store_name=store.name,
            total_price=float(total) if not missing else None,
            is_cheapest=False, savings_vs_most_expensive=0,
            items=items,
            has_estimated_prices=bool(missing) or any(item.price_is_estimated for item in items),
            is_complete=not missing, missing_products=sorted(set(missing)),
            currency_code="GBP",
        ))
    complete = [result.total_price for result in results if result.is_complete]
    if complete and not _has_national_reference(results):
        cheapest, most_expensive = min(complete), max(complete)
        for result in results:
            if result.is_complete:
                result.is_cheapest = result.total_price == cheapest
                result.savings_vs_most_expensive = round(most_expensive - result.total_price, 2)
    results.sort(key=lambda value: (
        not value.is_complete,
        value.total_price if value.total_price is not None else float("inf"),
        value.store_name,
    ))
    return results

@router.get("/shopping-list/{list_id}", response_model=List[PriceCompareStoreResult])
async def compare_shopping_list_prices(
    list_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Compare persisted UK shopping rows, not their old recipe requirements.

    Public shopping IDs are meal_plan_id. Accepted collaborators retain the
    list's GBP market even when their own account belongs to Poland. Reading
    this endpoint never rebuilds a plan, subtracts pantry stock or changes a
    purchased package. Separate row partitions keep the same whole-pack
    semantics as the list-specific store switch.
    """
    from app.api.v1.shopping_lists import _get_shopping_list_or_404

    shopping = await _get_shopping_list_or_404(list_id, current_user, db, refresh=True)
    if shopping.status not in {"pending", "in_progress"}:
        raise HTTPException(status_code=409, detail=account_text(current_user,
            "Ceny można porównywać tylko dla otwartej listy zakupów.",
            "Only an open shopping list can compare stores."))
    plan = await db.get(MealPlan, shopping.meal_plan_id)
    owner = await db.get(User, plan.user_id) if plan is not None else None
    source = shopping.store
    if (owner is not None and account_country(owner) == "PL" and source is not None
            and source.country_code == "PL" and source.currency_code == "PLN"
            and plan.store_id == shopping.store_id):
        return await _compare_polish_list_prices(db, shopping)
    if (owner is None or owner.country_code != "GB" or source is None
            or source.country_code != "GB" or source.currency_code != "GBP"
            or plan.store_id != shopping.store_id):
        raise HTTPException(status_code=404, detail=account_text(current_user,
            "Nie znaleziono listy zakupów na rynku UK.", "Shopping list not found in the UK market."))
    rows = list(shopping.items)
    if not rows:
        return []

    stores = list((await db.execute(select(Store).where(
        Store.country_code == "GB", Store.currency_code == "GBP",
        Store.id.in_([store.id for store in UK_STORES]),
    ).order_by(Store.name))).scalars().all())
    requirements = {item.id: regional_snapshot_requirement(item) for item in rows}
    product_ids = {value[0] for value in requirements.values() if value is not None}
    products = {product.id: product for product in (await db.execute(
        select(Product).where(Product.id.in_(product_ids)))).scalars().all()} if product_ids else {}
    as_of = utc_market_date()
    offers = list((await db.execute(select(RegionalProductOffer).where(
        RegionalProductOffer.store_id.in_([store.id for store in stores]),
        RegionalProductOffer.product_id.in_(product_ids),
        *reviewed_uk_offer_conditions(as_of=as_of),
    ))).scalars().all()) if product_ids and stores else []
    by_pair = {}
    fingerprints = {}
    for offer in offers:
        by_pair.setdefault((offer.store_id, offer.product_id), []).append(offer)
        fingerprints[offer.id] = offer.fingerprint

    results = []
    for store in stores:
        total, items, missing = Decimal("0.00"), [], []
        for item in rows:
            snapshot = item.regional_snapshot
            name = snapshot.name_en if snapshot is not None else item.custom_name
            name = name or "Unknown product"
            requirement = requirements[item.id]
            if item.is_from_pantry:
                if (requirement is None or snapshot.quote_status != "pantry"
                        or not item.is_checked or item.estimated_price != Decimal(0)):
                    missing.append(name)
                    continue
                _, quantity, unit = requirement
                items.append(PriceCompareItem(
                    product_name=name, quantity_needed=float(quantity), unit=unit,
                    price_in_store=0, price_is_estimated=False,
                    is_from_pantry=True, is_checked=True,
                ))
                continue
            if item.is_checked:
                quote = frozen_regional_purchase_quote(item, as_of=as_of)
                fingerprint = (snapshot.quote_data or {}).get("offer_fingerprint") if snapshot else None
            elif requirement is not None:
                product_id, quantity, unit = requirement
                quote = select_uk_offer_quote(
                    by_pair.get((store.id, product_id), []), product_id=product_id,
                    store_id=store.id, quantity=quantity, unit=unit, as_of=as_of,
                )
                if quote is None:
                    quote = quote_national_requirement(products.get(product_id), quantity, unit,
                        store_id=store.id, as_of=as_of)
                fingerprint = fingerprints.get(quote.offer_id) if quote else None
            else:
                quote, fingerprint = None, None
            if quote is None:
                missing.append(name)
                continue
            total += quote.total_price
            items.append(_uk_comparison_item(quote, fingerprint=fingerprint, checked=item.is_checked))
        results.append(PriceCompareStoreResult(
            store_id=store.id, store_name=store.name,
            total_price=None if missing else float(total),
            is_cheapest=False, savings_vs_most_expensive=0, items=items,
            has_estimated_prices=bool(missing) or any(item.price_is_estimated for item in items),
            is_complete=not missing, missing_products=sorted(set(missing)), currency_code="GBP",
        ))
    complete = [result.total_price for result in results if result.is_complete]
    if complete and not _has_national_reference(results):
        cheapest, highest = min(complete), max(complete)
        for result in results:
            if result.is_complete:
                result.is_cheapest = result.total_price == cheapest
                result.savings_vs_most_expensive = round(highest - result.total_price, 2)
    results.sort(key=lambda result: (
        not result.is_complete,
        result.total_price if result.total_price is not None else float("inf"),
        result.store_name,
    ))
    return results


async def _compare_polish_list_prices(db, shopping):
    from app.services.polish_list_prices import quote_polish_list
    if not shopping.items:
        return []
    stores = list((await db.execute(select(Store).where(
        Store.country_code == "PL", Store.currency_code == "PLN",
    ).order_by(Store.name))).scalars().all())
    quotes = await quote_polish_list(db, shopping, stores)
    results = []
    for store in stores:
        quoted = quotes[store.id]
        missing = [
            (item.store_product.product.name if item.store_product else item.custom_name) or "Nieznany produkt"
            for item, _, quote in quoted if quote is None
        ]
        items = [PriceCompareItem(**quote) for _, _, quote in quoted if quote is not None]
        total = round(sum(item.price_in_store for item in items), 2)
        results.append(PriceCompareStoreResult(
            store_id=store.id, store_name=store.name, currency_code="PLN",
            total_price=None if missing else total, is_cheapest=False,
            savings_vs_most_expensive=0, items=items, is_complete=not missing,
            has_estimated_prices=bool(missing) or any(item.price_is_estimated for item in items),
            missing_products=sorted(set(missing)),
        ))
    complete = [row.total_price for row in results if row.is_complete]
    if complete:
        for row in results:
            if row.is_complete:
                row.is_cheapest = row.total_price == min(complete)
                row.savings_vs_most_expensive = round(max(complete) - row.total_price, 2)
    results.sort(key=lambda row: (not row.is_complete, row.total_price if row.total_price is not None else math.inf, row.store_name))
    return results


@router.get("/{meal_plan_id}", response_model=List[PriceCompareStoreResult])
async def compare_prices(
    meal_plan_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.execute(
        select(MealPlan)
        .where(MealPlan.id == meal_plan_id)
        .options(
            selectinload(MealPlan.entries)
            .selectinload(MealPlanEntry.recipe)
            .selectinload(Recipe.ingredients)
            .selectinload(RecipeIngredient.product)
        )
    )
    meal_plan = result.scalar_one_or_none()
    if not meal_plan:
        raise HTTPException(status_code=404, detail=account_text(current_user,
            "Nie znaleziono planu posiłków", "Meal plan not found."))
    if meal_plan.user_id != current_user.id:
        raise HTTPException(status_code=403, detail=account_text(current_user,
            "Brak uprawnień do tego planu posiłków", "You do not have access to this meal plan."))
    # Porównanie cen nie jest tylnym wejściem do usuniętego planu lub
    # płatnego archiwum; stosuje tę samą regułę co podgląd planu.
    from app.api.v1.meal_plans import _ensure_plan_access
    _ensure_plan_access(meal_plan, current_user)

    # Ownership was verified above: the persisted owner's market is the
    # source of truth, never a device hint or a client-supplied store name.
    country = account_country(current_user)
    currency = "GBP" if country == "GB" else "PLN"
    planned_store = aliased(Store)
    plan_matches_market = exists(
        select(1).select_from(MealPlan)
        .join(planned_store, planned_store.id == MealPlan.store_id)
        .where(
            MealPlan.id == meal_plan_id,
            MealPlan.user_id == current_user.id,
            planned_store.country_code == country,
            planned_store.currency_code == currency,
        )
        .correlate(None)
    )
    stores = (await db.execute(select(Store).where(
        Store.country_code == country,
        Store.currency_code == currency,
        plan_matches_market,
    ))).scalars().all()
    if not stores:
        return []
    if country == "GB":
        return await _compare_uk_prices(db, meal_plan, stores)

    # ── Agreguj wymagane ilości SKŁADNIKÓW we wspólnej bazie (gramy/ml) ──
    # Wcześniej sumowanie zakładało, że jednostki zawsze się zgadzają
    # ("Assuming units match... simplified") — kruche założenie. Konwersja
    # do wspólnej bazy (tak jak w ShoppingListBuilder) jest odporna na to,
    # że ten sam produkt może być użyty w różnych przepisach w różnych
    # jednostkach.
    product_requirements: dict[uuid.UUID, dict] = {}

    for entry in meal_plan.entries:
        recipe = entry.recipe
        if not recipe:
            continue
        # UWAGA: `servings_multiplier` zapisany na wpisie planu JEST JUŻ
        # finalnym mnożnikiem całego przepisu (np. 0.5 = pół przepisu,
        # 2.0 = podwójna porcja) — dokładnie tak samo liczy to
        # ShoppingListBuilder._aggregate_ingredients(). Wcześniej ten plik
        # DZIELIŁ go dodatkowo przez recipe.servings, co zaniżało ilości
        # (i cenę) względem listy zakupów — stąd różne sumy na obu ekranach
        # dla tego samego planu.
        servings_multiplier = float(entry.servings_multiplier or 1)

        for ingredient in recipe.ingredients:
            product = ingredient.product
            if not product:
                continue
            req_qty_native = float(ingredient.quantity) * servings_multiplier
            req_qty_grams = quantity_to_grams(
                product.name,
                req_qty_native,
                ingredient.unit,
                getattr(product, "serving_quantity", None),
                getattr(product, "measure_options", None),
            )

            if product.id not in product_requirements:
                product_requirements[product.id] = {
                    "product": product,
                    "grams": req_qty_grams,
                    "quantity_known": _positive_finite_float(req_qty_grams) is not None,
                }
            else:
                product_requirements[product.id]["grams"] += req_qty_grams
                if _positive_finite_float(req_qty_grams) is None:
                    product_requirements[product.id]["quantity_known"] = False

    if not product_requirements:
        return []

    # ── Policz cenę w każdym sklepie — identyczna logika co lista zakupów ──
    store_results = []

    # Pobierz ceny jednym zapytaniem zamiast wykonywać osobny SELECT dla
    # każdej pary sklep–produkt. Przy większej liście usuwa to setki rund
    # komunikacji z bazą bez zmiany sposobu liczenia ceny.
    store_product_by_pair: dict[tuple[uuid.UUID, uuid.UUID], StoreProduct] = {}
    if product_requirements:
        store_products = (
            await db.execute(
                select(StoreProduct).where(
                    StoreProduct.store_id.in_([store.id for store in stores]),
                    StoreProduct.product_id.in_(list(product_requirements)),
                )
            )
        ).scalars().all()
        store_product_by_pair = {
            (row.store_id, row.product_id): row for row in store_products
        }

    for store in stores:
        total_price = 0.0
        items = []
        missing_products = []

        for prod_id, req in product_requirements.items():
            product = req["product"]
            total_grams = req["grams"]

            store_product = store_product_by_pair.get((store.id, prod_id))

            if not store_product or not getattr(store_product, "is_available", True):
                missing_products.append(product.name)
                continue

            price = _positive_finite_float(store_product.price)
            total_grams = _positive_finite_float(total_grams)
            if price is None or total_grams is None or not req["quantity_known"]:
                missing_products.append(product.name)
                continue

            product_unit = product.unit or "szt"
            default_qty_native = _positive_finite_float(product.default_quantity)
            if default_qty_native is None:
                missing_products.append(product.name)
                continue
            default_qty_grams = quantity_to_grams(
                product.name,
                default_qty_native,
                product_unit,
                getattr(product, "serving_quantity", None),
                getattr(product, "measure_options", None),
            )

            default_qty_grams = _positive_finite_float(default_qty_grams)
            if default_qty_grams is None:
                # Brak masy opakowania nie może skutkować zakupem fikcyjnego
                # jednego opakowania ani sugerowaniem wiarygodnej sumy.
                missing_products.append(product.name)
                continue

            package_count = math.ceil(total_grams / default_qty_grams)
            item_cost = round(price * package_count, 2)
            total_price += item_cost

            items.append(PriceCompareItem(
                product_name=product.name,
                quantity_needed=round(
                    grams_to_quantity(
                        product.name,
                        total_grams,
                        product_unit,
                        getattr(product, "serving_quantity", None),
                        getattr(product, "measure_options", None),
                    ),
                    2,
                ),
                unit=product_unit,
                price_in_store=item_cost,
                store_brand_name=store_product.store_brand_name,
                price_is_estimated=getattr(store_product, "last_verified", None) is None,
                last_verified=getattr(store_product, "last_verified", None),
            ))

        store_results.append({
            "store_id": store.id,
            "store_name": store.name,
            "total_price": round(total_price, 2),
            "items": items,
            "has_estimated_prices": any(item.price_is_estimated for item in items),
            "is_complete": bool(product_requirements) and not missing_products,
            "missing_products": sorted(set(missing_products)),
        })

    if not store_results:
        return []

    # Nie porównuj części koszyka z całym koszykiem. Najpierw pokazujemy
    # pełne zestawy; brakujących cen nie wolno interpretować jako 0 zł.
    store_results.sort(key=lambda x: (not x["is_complete"], x["total_price"], x["store_name"]))
    complete_prices = [res["total_price"] for res in store_results if res["is_complete"]]
    cheapest_price = min(complete_prices) if complete_prices else None
    most_expensive_price = max(complete_prices) if complete_prices else None

    final_results = []
    for res in store_results:
        final_results.append(
            PriceCompareStoreResult(
                store_id=res["store_id"],
                store_name=res["store_name"],
                total_price=res["total_price"],
                is_cheapest=(res["is_complete"] and res["total_price"] == cheapest_price),
                savings_vs_most_expensive=(
                    round(most_expensive_price - res["total_price"], 2)
                    if res["is_complete"] and most_expensive_price is not None else 0.0
                ),
                items=res["items"],
                has_estimated_prices=res["has_estimated_prices"],
                is_complete=res["is_complete"],
                missing_products=res["missing_products"],
                currency_code=currency,
            )
        )

    return final_results
