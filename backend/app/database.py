from sqlalchemy import create_engine, event, inspect, text
from sqlalchemy.orm import declarative_base, sessionmaker
from backend.app.config import settings

IS_SQLITE = settings.DATABASE_URL.startswith("sqlite:")

engine = create_engine(
    settings.DATABASE_URL,
    connect_args={
        "check_same_thread": False,
        "timeout": settings.SQLITE_BUSY_TIMEOUT_MS / 1000,
    } if IS_SQLITE else {},
    pool_pre_ping=True,
)


def configure_sqlite_connection(dbapi_connection, _connection_record=None) -> None:
    """Apply safe, persistent settings to every SQLite connection."""
    cursor = dbapi_connection.cursor()
    try:
        cursor.execute("PRAGMA foreign_keys=ON")
        cursor.execute(f"PRAGMA busy_timeout={int(settings.SQLITE_BUSY_TIMEOUT_MS)}")
        cursor.execute("PRAGMA journal_mode=WAL")
        cursor.execute("PRAGMA synchronous=NORMAL")
    finally:
        cursor.close()


if IS_SQLITE:
    event.listen(engine, "connect", configure_sqlite_connection)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base = declarative_base()


PRODUCT_COLUMN_MIGRATIONS = {
    "image_license_url": "VARCHAR(512)",
    "source_url": "VARCHAR(1024)",
    "image_source_url": "VARCHAR(1024)",
    "source_updated_at": "DATETIME",
    "is_active": "BOOLEAN NOT NULL DEFAULT 1",
}

PRODUCT_INDEX_MIGRATIONS = (
    "CREATE INDEX IF NOT EXISTS ix_products_type_active ON products (type, is_active)",
    "CREATE INDEX IF NOT EXISTS ix_products_country_type_active ON products (country_code, type, is_active)",
    "CREATE INDEX IF NOT EXISTS ix_products_source_active ON products (source, is_active)",
)


def migrate_database() -> None:
    """Apply additive, SQLite-safe schema migrations without deleting cache."""
    # Import registers all models with Base before create_all.
    from backend.app import models  # noqa: F401

    Base.metadata.create_all(bind=engine)
    inspector = inspect(engine)
    if "products" not in inspector.get_table_names():
        return
    existing = {column["name"] for column in inspector.get_columns("products")}
    with engine.begin() as connection:
        for name, declaration in PRODUCT_COLUMN_MIGRATIONS.items():
            if name not in existing:
                connection.execute(text(f"ALTER TABLE products ADD COLUMN {name} {declaration}"))
        for statement in PRODUCT_INDEX_MIGRATIONS:
            connection.execute(text(statement))

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
