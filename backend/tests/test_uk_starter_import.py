"""One controlled starter batch, no production credentials or live HTTP."""

import asyncio
from contextlib import asynccontextmanager
from copy import deepcopy
from datetime import datetime, timedelta, timezone
import json
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import AsyncMock, Mock
from uuid import uuid4

import pytest
from sqlalchemy import event, func, select

from app.db.seed import NUTRITION_DATA, PRODUCTS_DATA
from app.models import OffCatalogueProduct, OffIngredientMapping, Product, RegionalProductOffer, User
from app.services.off_availability import off_available_product_ids
from app.services.off_catalogue import import_off_catalogue
from app.services.product_measures import build_measure_options
from app.services.uk_starter_import import load_starter_bundle, stage_starter_bundle
from tests.test_uk_catalogue_import import AsyncAdapter, catalogue_db


NOW = datetime(2026, 10, 24, 20, tzinfo=timezone.utc)
FIXTURES = Path(__file__).parent / "fixtures"


def call(session, reviewer, bundle=None, now=NOW):
    return asyncio.run(stage_starter_bundle(AsyncAdapter(session), bundle or load_starter_bundle(FIXTURES),
        reviewer_user_id=reviewer, reviewed_at=now, as_of=now.date()))


def seed_foods(session, bundle):
    seeds = {row[0]: row for row in PRODUCTS_DATA}
    for proposal in bundle.proposals:
        row = seeds[proposal.product_name]
        session.add(Product(id=proposal.product_id, name=row[0], unit=row[1],
            default_quantity=row[2], serving_quantity=None, brand=proposal.product_brand,
            review_status="approved", nutrition_per_100=deepcopy(NUTRITION_DATA[row[0]]),
            measure_options=build_measure_options(row[0], row[1], row[2], None)))
    session.commit()


def counts(session):
    return tuple(session.scalar(select(func.count()).select_from(model))
        for model in (Product, OffCatalogueProduct, OffIngredientMapping, RegionalProductOffer))


def test_prepared_bundle_is_bounded_pinned_and_keeps_original_fetch_dates():
    bundle = load_starter_bundle(FIXTURES)
    assert len(bundle.products) == len(bundle.proposals) == 31
    assert len(bundle.digest) == 64
    assert len({row.product_id for row in bundle.proposals}) == 31
    assert all(record.retrieved_at < NOW for record in bundle.products)
    assert {record.retrieved_at.date().isoformat() for record in bundle.products} == {"2026-10-23", "2026-10-24"}


def test_complete_batch_is_idempotent_preserves_pl_and_outer_rollback(catalogue_db):
    session, reviewer, _ = catalogue_db
    bundle = load_starter_bundle(FIXTURES)
    seed_foods(session, bundle)
    before = counts(session)
    originals = {p.id: {col.name: deepcopy(getattr(p, col.name)) for col in Product.__table__.columns}
        for p in session.scalars(select(Product))}
    for attempt in range(2):
        result = call(session, reviewer, bundle)
        assert result.links.created == (31 if attempt == 0 else 0)
        assert result.links.unchanged == (0 if attempt == 0 else 31)
        assert result.available_count == 31 and result.dataset_digest == bundle.digest
    ids = {p.product_id for p in bundle.proposals}
    assert asyncio.run(off_available_product_ids(AsyncAdapter(session), ids, as_of=NOW.date())) == ids
    for product in session.scalars(select(Product)):
        assert {col.name: getattr(product, col.name) for col in Product.__table__.columns} == originals[product.id]
    for record in bundle.products:
        cached = session.get(OffCatalogueProduct, record.values["barcode"])
        assert cached.retrieved_at.replace(tzinfo=timezone.utc) == record.retrieved_at
    assert counts(session) == (before[0], 31, 31, 0)
    session.rollback()
    assert counts(session) == before


@pytest.mark.parametrize("kind", ["missing", "ordinary", "banned"])
def test_no_cache_writes_before_real_administrator_authorization(catalogue_db, kind):
    session, reviewer, _ = catalogue_db
    bundle = load_starter_bundle(FIXTURES)
    seed_foods(session, bundle)
    if kind == "missing":
        reviewer = uuid4()
    else:
        user = session.get(User, reviewer)
        if kind == "ordinary":
            user.role = "user"
        else:
            user.is_banned = True
        session.commit()
    before = counts(session)
    with pytest.raises(PermissionError):
        call(session, reviewer, bundle)
    assert counts(session) == before


@pytest.mark.parametrize("kind", ["missing", "renamed", "pending", "authored", "barcode", "dimension"])
def test_one_changed_canonical_identity_rejects_whole_batch(catalogue_db, kind):
    session, reviewer, _ = catalogue_db
    bundle = load_starter_bundle(FIXTURES)
    seed_foods(session, bundle)
    product = session.get(Product, bundle.proposals[-1].product_id)
    if kind == "missing":
        session.delete(product)
    elif kind == "renamed":
        product.name = "Different food"
    elif kind == "pending":
        product.review_status = "pending"
    elif kind == "authored":
        product.created_by_user_id = reviewer
    elif kind == "barcode":
        product.barcode = "20071974"
    else:
        product.unit, product.measure_options = "ml", None
    session.commit()
    before = counts(session)
    with pytest.raises(ValueError):
        call(session, reviewer, bundle)
    assert counts(session) == before


def test_current_persisted_package_representation_does_not_rewrite_canonical(catalogue_db):
    session, reviewer, _ = catalogue_db
    bundle = load_starter_bundle(FIXTURES)
    seed_foods(session, bundle)
    product = session.get(Product, bundle.proposals[0].product_id)
    product.unit = "opak"
    product.measure_options = [{"code": "g", "base_unit": "g", "base_quantity": 1}]
    product.brand = "Existing PL example brand"
    session.commit()
    call(session, reviewer, bundle)
    mapping = session.get(OffIngredientMapping, (product.id, bundle.proposals[0].off_barcode))
    assert mapping.product_unit == product.unit == "opak"
    assert mapping.product_brand == product.brand == "Existing PL example brand"


@pytest.mark.parametrize("offset", [-1, 31])
def test_future_or_expired_evidence_is_not_redated_to_today(catalogue_db, offset):
    session, reviewer, _ = catalogue_db
    bundle = load_starter_bundle(FIXTURES)
    seed_foods(session, bundle)
    before = counts(session)
    clock = NOW + timedelta(days=offset)
    with pytest.raises(ValueError):
        call(session, reviewer, bundle, now=clock)
    assert counts(session) == before


def test_newer_changed_cache_is_not_overwritten_or_silently_reapproved(catalogue_db):
    session, reviewer, _ = catalogue_db
    bundle = load_starter_bundle(FIXTURES)
    seed_foods(session, bundle)
    record = bundle.products[0]
    raw = deepcopy(record.raw)
    raw["product_name_en"] = "Changed food identity"
    asyncio.run(import_off_catalogue(AsyncAdapter(session), [raw], retrieved_at=NOW))
    session.commit()
    before = counts(session)
    original = session.get(OffCatalogueProduct, raw["code"]).fingerprint
    with pytest.raises(ValueError):
        call(session, reviewer, bundle)
    assert counts(session) == before
    assert session.get(OffCatalogueProduct, raw["code"]).fingerprint == original


def test_same_facts_keep_newer_real_fetch_time(catalogue_db):
    session, reviewer, _ = catalogue_db
    bundle = load_starter_bundle(FIXTURES)
    seed_foods(session, bundle)
    record = bundle.products[0]
    asyncio.run(import_off_catalogue(AsyncAdapter(session), [record.raw], retrieved_at=NOW))
    session.commit()
    call(session, reviewer, bundle)
    assert session.get(OffCatalogueProduct, record.raw["code"]).retrieved_at.replace(tzinfo=timezone.utc) == NOW


def test_pending_caller_edit_is_not_flushed_or_rolled_back(catalogue_db):
    session, reviewer, product_id = catalogue_db
    product = session.get(Product, product_id)
    product.name = "Unsaved caller work"
    with pytest.raises(ValueError, match="clean session"):
        call(session, reviewer)
    assert product in session.dirty and product.name == "Unsaved caller work"


def test_failure_after_sql_keeps_no_partial_facts_or_links(catalogue_db):
    session, reviewer, _ = catalogue_db
    bundle = load_starter_bundle(FIXTURES)
    seed_foods(session, bundle)
    before = counts(session)
    def fail(connection, cursor, statement, parameters, context, executemany):
        if statement.lower().startswith("insert into off_ingredient_mappings"):
            raise RuntimeError("after insertion")
    event.listen(session.bind, "after_cursor_execute", fail)
    try:
        with pytest.raises(RuntimeError, match="after insertion"):
            call(session, reviewer, bundle)
    finally:
        event.remove(session.bind, "after_cursor_execute", fail)
    assert counts(session) == before


def test_changed_or_relabelled_source_file_is_rejected(tmp_path):
    for name in ("off_uk_staples_20261023.json", "off_uk_staples_20261024.json",
            "off_uk_priority_staples_20261024.json", "off_uk_cooking_staples_20261024.json"):
        data = json.loads((FIXTURES / name).read_text(encoding="utf-8"))
        if name.endswith("20261023.json"):
            data["products"][0]["retrieved_at"] = NOW.isoformat()
        (tmp_path / name).write_text(json.dumps(data), encoding="utf-8")
    with pytest.raises(ValueError, match="digest"):
        load_starter_bundle(tmp_path)


def test_runtime_data_is_same_reviewed_bundle_without_shipping_test_code():
    runtime = load_starter_bundle(Path(__file__).parents[1] / "app/data/uk_starter_20261024.json")
    captured = load_starter_bundle(FIXTURES)
    assert runtime == captured
    assert len(runtime.products) == 31


def test_crlf_and_utf8_bom_do_not_look_like_changed_food_facts(tmp_path):
    for name in ("off_uk_staples_20261023.json", "off_uk_staples_20261024.json",
            "off_uk_priority_staples_20261024.json", "off_uk_cooking_staples_20261024.json"):
        packet = json.loads((FIXTURES / name).read_text(encoding="utf-8"))
        (tmp_path / name).write_bytes(b"\xef\xbb\xbf" + json.dumps(packet, ensure_ascii=False,
            indent=3).replace("\n", "\r\n").encode("utf-8"))
    assert load_starter_bundle(tmp_path) == load_starter_bundle(FIXTURES)


def test_describe_never_opens_database_or_imports_application_startup(monkeypatch):
    from scripts import import_uk_starter as cli
    import sqlalchemy.ext.asyncio as sa
    engine = Mock(side_effect=AssertionError("Must not connect"))
    monkeypatch.setattr(sa, "create_async_engine", engine)
    result = asyncio.run(cli.run(cli.parser().parse_args(["--describe"])))
    assert result["mode"] == "files_only" and result["product_count"] == 31
    engine.assert_not_called()


@pytest.mark.parametrize("flags", [["--apply"], ["--apply", "--confirm-dataset", "bad"]])
def test_apply_without_exact_dataset_confirmation_never_opens_database(monkeypatch, flags):
    from scripts import import_uk_starter as cli
    import sqlalchemy.ext.asyncio as sa
    engine = Mock(side_effect=AssertionError("Must not connect"))
    monkeypatch.setattr(sa, "create_async_engine", engine)
    with pytest.raises(ValueError, match="confirmation"):
        asyncio.run(cli.run(cli.parser().parse_args(flags)))
    engine.assert_not_called()


@pytest.mark.parametrize("apply", [False, True])
def test_cli_default_rollback_and_explicit_confirmed_commit(catalogue_db, monkeypatch, tmp_path, apply):
    from scripts import import_uk_starter as cli
    import sqlalchemy.ext.asyncio as sa
    session, reviewer, _ = catalogue_db
    bundle = load_starter_bundle(FIXTURES)
    seed_foods(session, bundle)
    before = counts(session)
    adapter = AsyncAdapter(session)
    adapter.rollback = AsyncMock(side_effect=session.rollback)
    adapter.commit = AsyncMock(side_effect=session.commit)
    @asynccontextmanager
    async def factory(engine, **kwargs):
        try:
            yield adapter
        finally:
            session.rollback()
    engine = SimpleNamespace(dispose=AsyncMock())
    create = Mock(return_value=engine)
    monkeypatch.setattr(sa, "create_async_engine", create)
    monkeypatch.setattr(sa, "AsyncSession", factory)
    monkeypatch.setattr(cli, "datetime", SimpleNamespace(now=lambda tz: NOW))
    env_file = tmp_path / "private.env"
    env_file.write_text("DATABASE_URL=postgresql://test_user:test_password@isolated.test/test_db?sslmode=require", encoding="utf-8")
    flags = ["--env-file", str(env_file), "--expected-host", "isolated.test", "--reviewer-id", str(reviewer)]
    if apply:
        flags += ["--apply", "--confirm-dataset", bundle.digest]
    result = asyncio.run(cli.run(cli.parser().parse_args(flags)))
    assert result["mode"] == ("committed" if apply else "rolled_back")
    assert result["available_count"] == 31
    assert adapter.commit.await_count == int(apply)
    assert adapter.rollback.await_count == int(not apply)
    assert counts(session) == ((before[0], 31, 31, 0) if apply else before)
    engine.dispose.assert_awaited_once()
    url = create.call_args.args[0]
    assert url.host == "isolated.test" and not url.query
    assert create.call_args.kwargs["echo"] is False
    assert create.call_args.kwargs["connect_args"]["ssl"].check_hostname


@pytest.mark.parametrize("kind", ["mismatch", "pooler", "no-host", "wrong-driver"])
def test_cli_refuses_unconfirmed_or_pooled_target_before_connecting(tmp_path, kind):
    from scripts import import_uk_starter as cli
    host = "isolated.test-pooler" if kind == "pooler" else "isolated.test"
    driver = "mysql" if kind == "wrong-driver" else "postgresql"
    env_file = tmp_path / "private.env"
    env_file.write_text(f"DATABASE_URL={driver}://test_user:test_password@{host}/test_db", encoding="utf-8")
    expected = "another.test" if kind == "mismatch" else (None if kind == "no-host" else host)
    with pytest.raises(ValueError):
        cli.connection_url(env_file, expected)
