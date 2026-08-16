"""Shared implementation for single-provider maintenance scripts."""

from backend.app.config import settings
from backend.app.database import SessionLocal, migrate_database
from backend.app.models import CatalogCountrySyncModel
from backend.app.services.catalog_sync import sync_sources
from backend.app.services.seed_service import seed_database_if_empty


async def run_one(source: str, countries=None):
    migrate_database()
    db = SessionLocal()
    try:
        seed_database_if_empty(db)
        cached = [row[0] for row in db.query(CatalogCountrySyncModel.country_code).filter_by(source="openfoodfacts").all()]
        selected_countries = countries or sorted(set(settings.openfoodfacts_country_codes + cached))
        return await sync_sources(db, [source], countries=selected_countries)
    finally:
        db.close()
