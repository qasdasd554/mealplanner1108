"""Controlled, bounded transfer of reviewed UK references; never startup work.

The caller owns commit/rollback. Original OFF retrieval times remain original;
this is neither a live fetch nor authority to renew stale or changed evidence.
Only OFF cache and reviewed country links are written, never Polish food facts.
"""

from dataclasses import dataclass
from datetime import date, datetime, timedelta
import hashlib
import json
from pathlib import Path
from uuid import UUID

from sqlalchemy import select

from app.models import OffCatalogueProduct, Product, User
from app.services.off_availability import off_available_product_ids
from app.services.off_catalogue import catalogue_values, import_off_catalogue
from app.services.off_ingredient_mapping import (
    OffMappingImportResult, OffMappingProposal, import_reviewed_off_mappings,
)
from app.services.system_content_language import is_system_ingredient
from app.services.uk_catalogue_import import _normalised_utc, _review_clock, canonical_base_unit


# Canonical JSON hashes, not CRLF-sensitive file hashes. Any data/review change
# needs another reviewed manifest, never an installer stripping safety checks.
_PACKETS = (
    ("off_uk_staples_20261023.json", "39d7d0f44c535fdb13567014525956347676d0d04eac0f83e8e9f984942feb90"),
    ("off_uk_staples_20261024.json", "d92e5a770ecfefe7f607c8a63e8bc8f826efa20d2e819572583f249903cf9959"),
    ("off_uk_priority_staples_20261024.json", "da7a13668625dd9b29e3ae182babbb8d5467f444f4939aade1f092e21877d01e"),
    ("off_uk_cooking_staples_20261024.json", "4626e8099f3923afd4fd70b5761b5b3efa53c6caaf939393803560defe5373ca"),
)


def _canonical(value):
    return json.dumps(value, sort_keys=True, ensure_ascii=False, separators=(",", ":"), allow_nan=False)


def _sha(value):
    return hashlib.sha256(value.encode("utf-8")).hexdigest()


@dataclass(frozen=True)
class StarterProduct:
    raw_json: str
    retrieved_at: datetime

    @property
    def raw(self):
        return json.loads(self.raw_json)

    @property
    def values(self):
        values = catalogue_values(self.raw, retrieved_at=self.retrieved_at)
        if values is None:
            raise ValueError("Invalid UK starter product evidence")
        return values


@dataclass(frozen=True)
class StarterBundle:
    packets: tuple[str, ...]

    def validated_packets(self):
        if len(self.packets) != len(_PACKETS):
            raise ValueError("Incomplete starter dataset")
        rows = []
        for text, (_, digest) in zip(self.packets, _PACKETS):
            packet = json.loads(text)
            if _sha(_canonical(packet)) != digest:
                raise ValueError("Starter dataset digest differs from the reviewed source")
            rows.append(packet)
        return rows

    @property
    def digest(self):
        self.validated_packets()
        return _sha("".join(digest for _, digest in _PACKETS))

    @property
    def products(self):
        records = []
        for packet in self.validated_packets():
            for row in packet["products"]:
                record = StarterProduct(_canonical(row["product"]), datetime.fromisoformat(row["retrieved_at"]))
                if (row["http_status"] != 200 or row["barcode_requested"] != record.raw["code"]
                        or record.values["fingerprint"] != row["fingerprint"]):
                    raise ValueError("Starter product differs from its reviewed facts")
                records.append(record)
        return tuple(records)

    @property
    def proposals(self):
        return tuple(OffMappingProposal.model_validate(row)
            for packet in self.validated_packets() for row in packet["proposals"])


def load_starter_bundle(source: Path) -> StarterBundle:
    source = Path(source)
    if source.is_file():
        data = source.read_bytes()
        if len(data) > 4_000_000:
            raise ValueError("Starter source exceeds its bounded size")
        bundle = StarterBundle(tuple(_canonical(row)
            for row in json.loads(data.decode("utf-8-sig"))["packets"]))
        bundle.validated_packets()
        return bundle
    packets = []
    for name, _ in _PACKETS:
        data = (source / name).read_bytes()
        if len(data) > 1_000_000:
            raise ValueError("Starter source exceeds its bounded size")
        packets.append(_canonical(json.loads(data.decode("utf-8-sig"))))
    bundle = StarterBundle(tuple(packets))
    bundle.validated_packets()
    return bundle


@dataclass(frozen=True)
class StarterImportResult:
    dataset_digest: str
    available_count: int
    links: OffMappingImportResult


async def stage_starter_bundle(session, bundle: StarterBundle, *, reviewer_user_id: UUID,
                               reviewed_at: datetime, as_of: date) -> StarterImportResult:
    """Stage all 31 reviewed food concepts atomically, never commit them here.

    Existing seed IDs/names must match. A deployed canonical representation
    (e.g. opak with explicit g measures) is snapshotted, not overwritten or
    treated as an OFF package. No synthetic admin, offers, prices or GTINs.
    """
    now = _review_clock(reviewed_at, as_of)
    if not isinstance(reviewer_user_id, UUID):
        raise ValueError("An authenticated reviewer UUID is required")
    if session.new or session.dirty or session.deleted:
        raise ValueError("Starter import requires a clean session")
    digest, records, proposals = bundle.digest, bundle.products, bundle.proposals
    ids = {row.product_id for row in proposals}
    by_code = {row.values["barcode"]: row for row in records}
    if len(ids) != 31 or len(by_code) != 31 or len(proposals) != 31:
        raise ValueError("Unexpected or duplicate starter identities")
    if any(not now - timedelta(days=30) <= row.retrieved_at <= now for row in records):
        raise ValueError("Starter evidence is future or expired; fetch and review a new dataset")

    async with session.begin_nested():
        reviewer = (await session.execute(select(User.role, User.is_banned)
            .where(User.id == reviewer_user_id).with_for_update())).one_or_none()
        if reviewer is None or reviewer.role != "admin" or reviewer.is_banned:
            raise PermissionError("An unbanned database administrator must approve the starter import")
        products = (await session.scalars(select(Product).where(Product.id.in_(ids))
            .order_by(Product.id).with_for_update().execution_options(populate_existing=True))).all()
        by_id = {row.id: row for row in products}
        current = (await session.scalars(select(OffCatalogueProduct)
            .where(OffCatalogueProduct.barcode.in_(by_code)).order_by(OffCatalogueProduct.barcode)
            .with_for_update().execution_options(populate_existing=True))).all()
        if any(row.fingerprint != by_code[row.barcode].values["fingerprint"]
                or _normalised_utc(row.retrieved_at) > now for row in current):
            raise ValueError("Existing OFF facts changed; a separate identity review is required")
        reviewed_links = []
        for proposal in proposals:
            product = by_id.get(proposal.product_id)
            facts = by_code[proposal.off_barcode].values
            if (product is None or not is_system_ingredient(product)
                    or product.name != proposal.product_name or product.barcode is not None
                    or product.review_status != "approved"
                    or canonical_base_unit(product) != facts["base_unit"]
                    or proposal.off_fingerprint != facts["fingerprint"]):
                raise ValueError("Starter canonical identity changed or is unavailable")
            reviewed_links.append(proposal.model_copy(update={
                "product_unit": product.unit, "product_brand": product.brand}))
        # Every identity was checked before the first write. A concurrent new
        # cache revision can still win its upsert; the mapping importer below
        # reloads/locks its fingerprint and rolls the whole batch back on conflict.
        for record in records:
            await import_off_catalogue(session, [record.raw], retrieved_at=record.retrieved_at)
        links = await import_reviewed_off_mappings(session, reviewed_links,
            reviewer_user_id=reviewer_user_id, reviewed_at=now, as_of=as_of)
        available = await off_available_product_ids(session, ids, as_of=as_of)
        if available != ids:
            raise ValueError("Starter availability verification failed")
        return StarterImportResult(digest, len(available), links)
