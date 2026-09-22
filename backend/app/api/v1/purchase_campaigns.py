"""Kampanie rabatowe dla zakupów Premium i punktów.

Rabat jest realizowany przez ofertę sklepu, nigdy przez zmianę kwoty w API.
Obecna integracja udostępnia linki do kodów ofertowych Apple. Dla Google Play
nie emitujemy kampanii, dopóki zakup nie będzie wybierał właściwego offerToken.
"""

from datetime import datetime, timezone
from urllib.parse import parse_qs, urlparse
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel, Field, model_validator
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_admin, get_current_user, get_db
from app.models.purchase_campaign import PurchaseCampaign
from app.models.user import User

router = APIRouter()


class CampaignCreate(BaseModel):
    name: str = Field(min_length=3, max_length=120)
    kind: str
    product_id: str
    discount_percent: int = Field(ge=1, le=90)
    audience: str
    target_email: str | None = None
    starts_at: datetime
    ends_at: datetime
    ios_offer_url: str = Field(max_length=1000)

    @model_validator(mode="after")
    def validate_campaign(self):
        if self.kind not in {"premium", "points"}:
            raise ValueError("Rodzaj kampanii musi być premium albo points")
        allowed = {
            "premium": {"premium_weekly_v2", "premium_monthly", "premium_yearly"},
            "points": {"points_10", "points_20", "points_50"},
        }
        if self.product_id not in allowed[self.kind]:
            raise ValueError("Produkt nie pasuje do rodzaju kampanii")
        if self.audience not in {"all", "user"}:
            raise ValueError("Odbiorcy muszą być all albo user")
        if self.audience == "user" and not (self.target_email or "").strip():
            raise ValueError("Podaj e-mail użytkownika")
        if self.starts_at.tzinfo is None or self.ends_at.tzinfo is None:
            raise ValueError("Daty muszą zawierać strefę czasową")
        if self.ends_at <= self.starts_at:
            raise ValueError("Koniec kampanii musi być później niż początek")
        parsed = urlparse(self.ios_offer_url)
        if (parsed.scheme != "https" or parsed.hostname != "apps.apple.com"
                or parsed.path != "/redeem"
                or parse_qs(parsed.query).get("ctx") != ["offercodes"]):
            raise ValueError("Podaj link do kodu ofertowego z apps.apple.com/redeem?ctx=offercodes")
        return self


def _admin_response(campaign: PurchaseCampaign) -> dict:
    return {
        "id": str(campaign.id),
        "name": campaign.name,
        "kind": campaign.kind,
        "product_id": campaign.product_id,
        "discount_percent": campaign.discount_percent,
        "audience": campaign.audience,
        "target_email": campaign.target_email,
        "starts_at": campaign.starts_at.isoformat(),
        "ends_at": campaign.ends_at.isoformat(),
        "ios_offer_url": campaign.ios_offer_url,
        "is_active": campaign.is_active,
    }


@router.get("/admin")
async def list_campaigns(
    db: AsyncSession = Depends(get_db),
    _admin: User = Depends(get_current_admin),
):
    result = await db.execute(select(PurchaseCampaign).order_by(PurchaseCampaign.created_at.desc()))
    return [_admin_response(c) for c in result.scalars().all()]


@router.post("/admin", status_code=201)
async def create_campaign(
    payload: CampaignCreate,
    db: AsyncSession = Depends(get_db),
    _admin: User = Depends(get_current_admin),
):
    target_email = payload.target_email.strip().lower() if payload.audience == "user" and payload.target_email else None
    if target_email:
        user = await db.scalar(select(User.id).where(func.lower(User.email) == target_email))
        if user is None:
            raise HTTPException(404, "Nie znaleziono użytkownika z tym adresem e-mail")
    campaign = PurchaseCampaign(
        name=payload.name.strip(), kind=payload.kind,
        product_id=payload.product_id,
        discount_percent=payload.discount_percent, audience=payload.audience,
        target_email=target_email,
        starts_at=payload.starts_at.astimezone(timezone.utc),
        ends_at=payload.ends_at.astimezone(timezone.utc),
        ios_offer_url=payload.ios_offer_url.strip(), is_active=False,
    )
    db.add(campaign)
    await db.commit()
    await db.refresh(campaign)
    return _admin_response(campaign)


@router.patch("/admin/{campaign_id}")
async def set_campaign_active(
    campaign_id: UUID,
    is_active: bool,
    db: AsyncSession = Depends(get_db),
    _admin: User = Depends(get_current_admin),
):
    campaign = await db.get(PurchaseCampaign, campaign_id)
    if campaign is None:
        raise HTTPException(404, "Nie znaleziono kampanii")
    campaign.is_active = is_active
    await db.commit()
    return _admin_response(campaign)


@router.delete("/admin/{campaign_id}", status_code=204)
async def delete_campaign(
    campaign_id: UUID,
    db: AsyncSession = Depends(get_db),
    _admin: User = Depends(get_current_admin),
):
    campaign = await db.get(PurchaseCampaign, campaign_id)
    if campaign is None:
        raise HTTPException(404, "Nie znaleziono kampanii")
    await db.delete(campaign)
    await db.commit()


@router.get("/active")
async def active_campaigns(
    request: Request,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if request.headers.get("x-platform") != "ios":
        return []
    now = datetime.now(timezone.utc)
    result = await db.execute(
        select(PurchaseCampaign).where(
            PurchaseCampaign.is_active.is_(True),
            PurchaseCampaign.starts_at <= now,
            PurchaseCampaign.ends_at > now,
        )
    )
    return [
        {"kind": c.kind, "product_id": c.product_id, "discount_percent": c.discount_percent, "ios_offer_url": c.ios_offer_url}
        for c in result.scalars().all()
        if c.audience == "all" or c.target_email == current_user.email.lower()
    ]
