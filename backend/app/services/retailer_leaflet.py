"""Shared offer fields and bounded downloads from retailer websites."""

from dataclasses import dataclass
from datetime import date
from decimal import Decimal

import httpx


@dataclass(frozen=True)
class LeafletOffer:
    sku: str
    catalogue_sku: str | None
    name: str
    brand: str
    pack: str
    quantity: Decimal | None
    unit: str | None
    regular: Decimal
    discount: Decimal
    start: date
    end: date
    source_url: str | None = None


async def download_leaflet(url: str) -> bytes:
    html = bytearray()
    async with httpx.AsyncClient(timeout=15) as client:
        async with client.stream("GET", url) as response:
            response.raise_for_status()
            async for chunk in response.aiter_bytes():
                html.extend(chunk)
                if len(html) > 4_000_000:
                    raise ValueError("Retailer leaflet exceeds the expected size")
    return bytes(html)
