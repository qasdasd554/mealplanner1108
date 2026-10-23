"""Supported account markets; device region is used only when creating an account."""

from typing import Literal

MarketCode = Literal["PL", "GB"]

DEFAULT_COUNTRY = "PL"
SUPPORTED_COUNTRIES = frozenset({"PL", "GB"})


def registration_country(device_region: object) -> str:
    """Old clients and unsupported regions retain the existing Polish market.

    This is a device locale preference, not a claim of verified residence or
    physical location. It is deliberately not inferred from a changing IP.
    """
    if not isinstance(device_region, str):
        return DEFAULT_COUNTRY
    region = device_region.strip().upper()
    if region == "UK":
        region = "GB"
    return region if region in SUPPORTED_COUNTRIES else DEFAULT_COUNTRY


def account_country(user: object) -> str:
    """Read a persisted market without reinterpreting a later device locale."""
    country = getattr(user, "country_code", None)
    return country if country in SUPPORTED_COUNTRIES else DEFAULT_COUNTRY


def signup_country(device_region: object) -> str:
    """Do not silently assign a UK account to PL before its market is ready.

    Called only inside the new-account branch, never for existing logins.
    This release switch is server-owned, not a user-editable preference.
    """
    from fastapi import HTTPException
    from app.core.config import settings

    country = registration_country(device_region)
    if country == "GB" and not settings.UK_MARKET_ENABLED:
        raise HTTPException(
            status_code=503,
            detail="Meal Planner is not yet available in the United Kingdom.",
        )
    return country


def requested_market(user: object, admin_market: str | None = None) -> str:
    """An explicit admin catalogue context never changes the account country."""
    if admin_market is None:
        return account_country(user)
    from fastapi import HTTPException

    if getattr(user, "role", "user") != "admin":
        raise HTTPException(status_code=403, detail="Wybór rynku jest dostępny wyłącznie administratorowi.")
    if admin_market not in SUPPORTED_COUNTRIES:
        raise HTTPException(status_code=422, detail="Nieobsługiwany rynek.")
    return admin_market
