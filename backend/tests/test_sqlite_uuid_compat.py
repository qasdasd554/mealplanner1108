"""Guard the test adapter without weakening PostgreSQL model contracts."""

from types import SimpleNamespace
from uuid import uuid4

from sqlalchemy import Integer, String, Uuid, create_engine, event, func
from sqlalchemy.orm import DeclarativeBase, Mapped, Session, mapped_column

from tests.sqlite_uuid_compat import supply_sqlite_uuid_defaults


class _Base(DeclarativeBase):
    pass


class _ServerUuid(_Base):
    __tablename__ = "synthetic_server_uuid"
    id: Mapped[object] = mapped_column(Uuid, primary_key=True, server_default=func.gen_random_uuid())
    label: Mapped[str] = mapped_column(String)


class _ClientUuid(_Base):
    __tablename__ = "synthetic_client_uuid"
    id: Mapped[object] = mapped_column(Uuid, primary_key=True, default=uuid4)


class _IntegerId(_Base):
    __tablename__ = "synthetic_integer_id"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)


def test_legacy_session_gets_only_missing_server_uuid_without_mutating_metadata():
    engine = create_engine("sqlite://")
    _Base.metadata.create_all(engine)
    engine.dialect.insert_returning = False
    known = uuid4()
    with Session(engine) as session:
        assert supply_sqlite_uuid_defaults(session) is True
        generated = _ServerUuid(label="generated")
        explicit = _ServerUuid(id=known, label="explicit")
        client = _ClientUuid()
        integer = _IntegerId()
        session.add_all([generated, explicit, client, integer])
        session.flush()
        assert generated.id is not None
        assert explicit.id == known
        assert client.id is not None
        assert integer.id == 1
        assert session.get(_ServerUuid, generated.id) is generated
    column = _ServerUuid.__table__.c.id
    assert column.default is None
    assert str(column.server_default.arg) == "gen_random_uuid()"
    engine.dispose()


def test_native_returning_keeps_the_database_generated_value():
    engine = create_engine("sqlite://")
    native_id = uuid4()
    @event.listens_for(engine, "connect")
    def configure(connection, _):
        connection.create_function("gen_random_uuid", 0, lambda: native_id.hex)
    _Base.metadata.create_all(engine)
    if not engine.dialect.insert_returning:
        # The default-returning branch is tested on capable hosts; on the
        # older Codespace exercise the no-op guard with the same dialect flag.
        assert supply_sqlite_uuid_defaults(SimpleNamespace(get_bind=lambda: SimpleNamespace(
            dialect=SimpleNamespace(name="sqlite", insert_returning=True)))) is False
        engine.dispose()
        return
    with Session(engine) as session:
        assert supply_sqlite_uuid_defaults(session) is False
        row = _ServerUuid(label="native")
        session.add(row)
        session.flush()
        assert row.id == native_id
    engine.dispose()


def test_postgres_is_never_given_a_sqlite_test_adapter():
    session = SimpleNamespace(get_bind=lambda: SimpleNamespace(
        dialect=SimpleNamespace(name="postgresql", insert_returning=False)))
    assert supply_sqlite_uuid_defaults(session) is False


def test_session_adapter_does_not_leak_to_another_session():
    engine = create_engine("sqlite://")
    _Base.metadata.create_all(engine)
    engine.dialect.insert_returning = False
    with Session(engine) as adapted, Session(engine) as untouched:
        supply_sqlite_uuid_defaults(adapted)
        row = _ServerUuid(label="untouched")
        untouched.add(row)
        untouched.dispatch.before_flush(untouched, None, None)
        assert row.id is None
    engine.dispose()
