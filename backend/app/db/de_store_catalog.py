"""German store identities from official retailer sites."""

from dataclasses import dataclass
from decimal import Decimal
import json
from pathlib import Path
from urllib.parse import urlparse
from uuid import uuid5

from sqlalchemy import select

from app.db.uk_store_catalog import seed_store_definitions, store_catalogue_id


@dataclass(frozen=True, slots=True)
class GermanStoreDefinition:
    slug: str
    name: str
    website: str
    country_code: str = "DE"
    currency: str = "EUR"
    department_names: tuple[str, ...] = (
        "Obst und Gemüse", "Backwaren", "Fleisch und Geflügel",
        "Fisch und Meeresfrüchte", "Milchprodukte und Eier", "Trockenwaren",
        "Tiefkühlkost", "Kräuter, Gewürze und Soßen", "Konserven",
    )

    @property
    def id(self):
        return store_catalogue_id(self.country_code, self.slug)


DE_STORES = (
    GermanStoreDefinition("rewe", "REWE", "https://www.rewe.de/shop/"),
    GermanStoreDefinition("edeka", "EDEKA", "https://www.edeka.de/angebote/"),
    GermanStoreDefinition("aldi-nord", "ALDI Nord", "https://www.aldi-nord.de/sortiment.html"),
    GermanStoreDefinition("aldi-sued", "ALDI SÜD", "https://www.aldi-sued.de/produkte"),
    GermanStoreDefinition("lidl", "Lidl", "https://www.lidl.de/c/rund-um-die-filiale/s10007548"),
    GermanStoreDefinition("kaufland", "Kaufland", "https://filiale.kaufland.de/angebote.html"),
    GermanStoreDefinition("penny", "PENNY", "https://www.penny.de/angebote"),
)


async def seed_de_stores(session) -> None:
    await seed_store_definitions(session, DE_STORES)


async def seed_de_test_catalogue(session, *, store_slug: str = "aldi-sued") -> int:
    """Insert a reviewed German shop sample in a development database only.

    The ordinary startup seed deliberately does not publish these estimates.
    Fixed retailer packs are stored on the offer, independently of the shared food.
    """
    from app.core.config import settings
    from app.db.seed import DEPARTMENT_NAMES, PRODUCTS_DATA, _uid
    from app.models import Product, Store, StoreProduct
    from app.services.polish_list_prices import _amount

    if settings.ENVIRONMENT != "development":
        raise RuntimeError("German catalogue estimates are only for development")
    filenames = {
        "aldi-sued": "de_aldi_sued_starter.json",
        "aldi-nord": "de_aldi_nord_starter.json",
        "kaufland": "de_kaufland_starter.json",
        "edeka": "de_edeka_starter.json",
        "rewe": "de_rewe_starter.json",
        "penny": "de_penny_starter.json",
        "lidl": "de_lidl_starter.json",
    }
    if store_slug not in filenames:
        raise ValueError("No German test catalogue exists for this store")
    path = Path(__file__).resolve().parents[1] / "data" / filenames[store_slug]
    evidence = json.loads(path.read_text(encoding="utf-8"))
    if evidence["store_slug"] != store_slug:
        raise ValueError("The German sample must match the requested shop")
    definition = next(store for store in DE_STORES if store.slug == store_slug)
    store = await session.get(Store, definition.id)
    if store is None or store.country_code != "DE" or store.currency_code != evidence["currency"]:
        raise ValueError("The German store must be seeded before its sample catalogue")

    shop_host = urlparse(definition.website).hostname.removeprefix("www.")
    source_hosts = {shop_host, f"www.{shop_host}"}
    if store_slug == "lidl":
        source_hosts.add("unternehmen.lidl.de")  # Official published shelf prices.
    for url in evidence["sources"].values():
        source = urlparse(url)
        if source.scheme != "https" or source.hostname not in source_hosts:
            raise ValueError("Catalogue evidence must come from the shop's own website")

    catalogue = {row[0]: row[1:4] for row in PRODUCTS_DATA}
    department_names = dict(zip(DEPARTMENT_NAMES, definition.department_names, strict=True))
    prices = {}
    for row in evidence["products"]:
        name = row["canonical"]
        unit, size, department = catalogue[name]
        pack_size, pack_unit = _amount(row["quantity"]), row["unit"]
        if pack_unit not in {"g", "kg", "ml", "l", "szt"} or (
            pack_unit == "szt" and pack_size != pack_size.to_integral_value()
        ) or pack_size != pack_size.quantize(Decimal("0.001")):
            raise ValueError(f"Invalid retailer package for {name}")
        product_id = _uid(f"product:{name}")
        price = Decimal(row["price"])
        if (product_id in prices or not price.is_finite() or not 0 < price <= Decimal("99999999.99")
                or price != price.quantize(Decimal("0.01")) or row["source"] not in evidence["sources"]):
            raise ValueError(f"Invalid catalogue evidence for {name}")
        department_id = uuid5(definition.id, f"department:{department_names[department]}")
        prices[product_id] = (name, unit, size, department_id, price, row["brand"], pack_size, pack_unit)

    products = (await session.scalars(select(Product).where(Product.id.in_(prices)))).all()
    existing = set(await session.scalars(select(StoreProduct.product_id).where(
        StoreProduct.store_id == definition.id,
        StoreProduct.product_id.in_(prices),
    )))
    if len(products) != len(prices):
        raise ValueError("The shared system catalogue must be seeded before the German sample")
    rows = []
    for product in products:
        name, unit, size, department_id, price, brand, pack_size, pack_unit = prices[product.id]
        if product.name != name or product.unit != unit or product.default_quantity != size:
            raise ValueError(f"The stored canonical purchase unit changed for {name}")
        if product.id not in existing:
            rows.append(StoreProduct(
                id=uuid5(definition.id, f"product:{product.id}"),
                store_id=definition.id,
                product_id=product.id,
                department_id=department_id,
                price=price,
                package_quantity=pack_size,
                package_unit=pack_unit,
                store_brand_name=brand,
                is_available=True,
                last_verified=None,
            ))
    session.add_all(rows)
    await session.flush()
    return len(rows)
