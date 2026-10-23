"""UK retailer definitions; importing this module never changes the DB.

The source confirms retailer names, not stock, prices, or branch coverage.
Department labels are generic navigation categories, not claims about a
retailer's actual aisle layout. There are deliberately no StoreProduct rows or
prices here. Before market release, verified local product-to-store links and
explicit provenance for any labelled GBP estimates must be supplied.

The explicit seed below requires country-aware Store storage and query
isolation. It is deliberately separate from the existing Polish seed.
"""

from __future__ import annotations

import re
from dataclasses import dataclass
from datetime import date
from typing import TYPE_CHECKING
from uuid import NAMESPACE_URL, UUID, uuid5

if TYPE_CHECKING:
    from sqlalchemy.ext.asyncio import AsyncSession


@dataclass(frozen=True, slots=True)
class CatalogueSource:
    """Evidence for retailer identity only; not a price/availability feed."""

    publisher: str
    title: str
    url: str
    checked_on: date


UK_STORE_SOURCE = CatalogueSource(
    publisher="Department for Environment, Food & Rural Affairs",
    title="Food statistics in your pocket: Grocery market shares",
    url=(
        "https://www.gov.uk/government/statistics/food-statistics-pocketbook/"
        "food-statistics-in-your-pocket#grocery-market-shares"
    ),
    checked_on=date(2026, 10, 15),
)

# Shared English shopping categories, not retailer-specific department names.
UK_DEPARTMENT_NAMES: tuple[str, ...] = (
    "Fruit and vegetables",
    "Bakery",
    "Meat and poultry",
    "Fish and seafood",
    "Dairy and eggs",
    "Dry goods",
    "Frozen food",
    "Herbs, spices and sauces",
    "Tinned food",
)


def store_catalogue_id(country_code: str, slug: str) -> UUID:
    """Stable country-scoped ID, independent of future display-name changes."""
    country = country_code.strip().upper()
    retailer = slug.strip().lower()
    if re.fullmatch(r"[A-Z]{2}", country) is None:
        raise ValueError("country_code must be a two-letter country code")
    if re.fullmatch(r"[a-z0-9]+(?:-[a-z0-9]+)*", retailer) is None:
        raise ValueError("slug must contain lowercase words separated by hyphens")
    return uuid5(
        NAMESPACE_URL,
        f"https://mealplannerpolska.pl/catalogue/stores/{country}/{retailer}",
    )


@dataclass(frozen=True, slots=True)
class UKStoreDefinition:
    """Immutable preparation data, not a live or fully stocked store."""

    slug: str
    name: str
    country_code: str = "GB"
    currency: str = "GBP"
    department_names: tuple[str, ...] = UK_DEPARTMENT_NAMES
    source: CatalogueSource = UK_STORE_SOURCE

    def __post_init__(self) -> None:
        if self.country_code != "GB" or self.currency != "GBP":
            raise ValueError("UK catalogue entries must use country GB and currency GBP")
        if not self.name.strip():
            raise ValueError("A retailer display name is required")
        store_catalogue_id(self.country_code, self.slug)

    @property
    def id(self) -> UUID:
        return store_catalogue_id(self.country_code, self.slug)


# Defra's published market-share table is a retailer list, not a stock feed.
# Tuple + frozen definitions keep this preparatory catalogue immutable.
UK_STORES: tuple[UKStoreDefinition, ...] = (
    UKStoreDefinition(slug="tesco", name="Tesco"),
    UKStoreDefinition(slug="sainsburys", name="Sainsbury's"),
    UKStoreDefinition(slug="asda", name="Asda"),
    UKStoreDefinition(slug="aldi", name="Aldi"),
    UKStoreDefinition(slug="morrisons", name="Morrisons"),
    UKStoreDefinition(slug="lidl", name="Lidl"),
    UKStoreDefinition(slug="co-op", name="Co-op"),
    UKStoreDefinition(slug="waitrose", name="Waitrose"),
    UKStoreDefinition(slug="iceland", name="Iceland"),
    UKStoreDefinition(slug="ocado", name="Ocado"),
)


async def seed_uk_stores(session: AsyncSession) -> None:
    """Add missing UK stores/departments without replacing administrator edits.

    No commit is performed: the startup caller owns the transaction. This
    creates only retailer navigation data, not product availability. Product
    mappings must be independently validated before the market is released.
    """
    from app.models.store import Store, StoreDepartment

    for definition in UK_STORES:
        store = await session.get(Store, definition.id)
        if store is None:
            store = Store(
                id=definition.id,
                name=definition.name,
                country_code=definition.country_code,
                currency_code=definition.currency,
                logo_url=None,
                department_order={
                    name: position
                    for position, name in enumerate(definition.department_names)
                },
            )
            session.add(store)
            # Flush the parent before child lookups, including sessions whose
            # autoflush is disabled. Identifiers remain explicit UUIDs.
            await session.flush()
        elif (
            store.country_code != definition.country_code
            or store.currency_code != definition.currency
        ):
            raise ValueError("UK store identity belongs to a different market or currency")

        for position, department_name in enumerate(definition.department_names):
            department_id = uuid5(definition.id, f"department:{department_name}")
            if await session.get(StoreDepartment, department_id) is None:
                session.add(StoreDepartment(
                    id=department_id,
                    store_id=definition.id,
                    name=department_name,
                    sort_order=position,
                ))

    await session.flush()
