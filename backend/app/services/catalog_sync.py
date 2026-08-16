"""Provider orchestration used by maintenance commands."""

from __future__ import annotations

from typing import Dict, Iterable, List

from sqlalchemy.orm import Session

from backend.app.services.catalog_store import fail_sync, finish_sync, replace_source_products, start_sync
from backend.app.services.currency_service import sync_frankfurter_rates
from backend.app.services.icecat_service import sync_icecat_products
from backend.app.services.openfoodfacts_service import sync_seed_countries
from backend.app.services.wikidata_food_service import fetch_wikidata_food


class SyncSummaryError(RuntimeError):
    def __init__(self, results, errors):
        super().__init__("; ".join(errors))
        self.results = results
        self.errors = errors


async def _tracked_sync(db: Session, source: str, fetcher, *, product_type=None, dry_run=False) -> int:
    run = None if dry_run else start_sync(db, source)
    try:
        result = await fetcher()
        if product_type:
            written = replace_source_products(db, result, source=source, product_type=product_type, dry_run=dry_run)
            seen = len(result)
        else:
            written = int(result)
            seen = written
        if run:
            finish_sync(db, run, seen, written)
        return written
    except Exception as exc:
        db.rollback()
        if run:
            fail_sync(db, run, exc)
        raise


async def sync_sources(
    db: Session,
    sources: Iterable[str],
    *,
    countries: List[str],
    dry_run: bool = False,
) -> Dict[str, object]:
    result: Dict[str, object] = {}
    errors = []
    for source in sources:
        try:
            if source == "frankfurter":
                result[source] = await _tracked_sync(
                    db, source, lambda: sync_frankfurter_rates(db, dry_run=dry_run), dry_run=dry_run
                )
            elif source == "icecat":
                result[source] = await _tracked_sync(
                    db, source, sync_icecat_products, product_type="shopping", dry_run=dry_run
                )
            elif source == "openfoodfacts":
                result[source] = await sync_seed_countries(db, countries, dry_run=dry_run)
                failed = [code for code, value in result[source].items() if isinstance(value, dict) and value.get("error")]
                if failed:
                    errors.append(f"openfoodfacts failed for {','.join(failed)}")
            elif source == "wikidata":
                result[source] = await _tracked_sync(
                    db, source, lambda: fetch_wikidata_food(db), product_type="food", dry_run=dry_run
                )
            else:
                raise ValueError(f"Unknown synchronization source: {source}")
        except Exception as exc:
            db.rollback()
            result[source] = {"error": getattr(exc, "code", type(exc).__name__.lower())}
            errors.append(f"{source} failed: {type(exc).__name__}")
    if errors:
        raise SyncSummaryError(result, errors)
    return result
