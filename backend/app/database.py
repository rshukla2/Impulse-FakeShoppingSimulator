from sqlalchemy import create_engine, inspect, text
from sqlalchemy.orm import declarative_base, sessionmaker
from backend.app.config import settings

engine = create_engine(
    settings.DATABASE_URL,
    connect_args={"check_same_thread": False} if "sqlite" in settings.DATABASE_URL else {}
)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base = declarative_base()


PRODUCT_COLUMN_MIGRATIONS = {
    "image_license_url": "VARCHAR(512)",
    "source_url": "VARCHAR(1024)",
    "image_source_url": "VARCHAR(1024)",
    "source_updated_at": "DATETIME",
    "is_active": "BOOLEAN NOT NULL DEFAULT 1",
}


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

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
