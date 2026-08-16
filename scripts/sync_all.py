#!/usr/bin/env python3
"""Synchronize Impulse's external catalogs into the local SQLite cache."""

from __future__ import annotations

import argparse
import asyncio
import json
import os
import sys
from pathlib import Path

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from backend.app.config import settings
from backend.app.database import SessionLocal, migrate_database
from backend.app.models import CatalogCountrySyncModel
from backend.app.services.catalog_sync import SyncSummaryError, sync_sources
from backend.app.services.seed_service import seed_database_if_empty
from scripts.update_geoip_database import install_archive


SOURCES = ("frankfurter", "icecat", "openfoodfacts", "wikidata")


async def run(args) -> dict:
    migrate_database()
    if args.geoip_archive:
        install_archive(Path(args.geoip_archive), Path(settings.GEOIP_DATABASE_PATH))
    db = SessionLocal()
    try:
        seeds = seed_database_if_empty(db)
        selected = args.source or list(SOURCES)
        cached_countries = [row[0] for row in db.query(CatalogCountrySyncModel.country_code).filter_by(source="openfoodfacts").all()]
        countries = [code.upper() for code in args.country] if args.country else sorted(set(settings.openfoodfacts_country_codes + cached_countries))
        synchronized = await sync_sources(db, selected, countries=countries, dry_run=args.dry_run)
        return {"dry_run": args.dry_run, "seeds": seeds, "synchronized": synchronized}
    finally:
        db.close()


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", action="append", choices=SOURCES, help="Source to sync; repeat for multiple (default: all)")
    parser.add_argument("--country", action="append", help="ISO country for Open Food Facts; repeat for multiple")
    parser.add_argument("--dry-run", action="store_true", help="Validate and normalize without changing catalog/rate data")
    parser.add_argument("--full", action="store_true", help="Explicitly request a full refresh (currently the default provider behavior)")
    parser.add_argument("--geoip-archive", help="Install a local GeoLite archive before synchronization")
    args = parser.parse_args()
    try:
        summary = asyncio.run(run(args))
    except SyncSummaryError as exc:
        print(json.dumps({"synchronized": exc.results, "errors": exc.errors}, indent=2), file=sys.stderr)
        raise SystemExit(1)
    except Exception as exc:
        print(f"Sync failed: {type(exc).__name__}: {exc}", file=sys.stderr)
        raise SystemExit(1)
    print(json.dumps(summary, indent=2, default=str))


if __name__ == "__main__":
    main()
