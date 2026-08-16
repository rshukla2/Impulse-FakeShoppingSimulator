"""Country-scoped Open Food Facts synchronization."""

from __future__ import annotations

import asyncio
import re
from datetime import timedelta
from typing import Any, Dict, List, Optional

import pycountry
from sqlalchemy import or_
from sqlalchemy.orm import Session

from backend.app.config import settings
from backend.app.database import SessionLocal
from backend.app.models import CatalogCountrySyncModel
from backend.app.services.catalog_store import country_sync_record, fail_sync, finish_sync, replace_source_products, start_sync, utcnow
from backend.app.services.external_http import ExternalHTTPClient
from backend.app.services.pricing_rules import stable_catalog_values


OFF_FIELDS = ",".join((
    "code", "product_name", "brands", "categories", "categories_tags_en", "quantity",
    "image_front_url", "image_url", "countries_tags_en", "completeness",
    "obsolete",
))


def _clean(value: Any, limit: int = 255) -> Optional[str]:
    if not value:
        return None
    return re.sub(r"\s+", " ", str(value)).strip()[:limit] or None


def _category(product: Dict[str, Any]) -> str:
    tags = product.get("categories_tags_en") or []
    if tags:
        return str(tags[0]).replace("en:", "").replace("-", " ").title()[:128]
    raw = _clean(product.get("categories"), 128)
    return raw.split(",", 1)[0] if raw else "Groceries"


def normalize_openfoodfacts_product(product: Dict[str, Any], country_code: str) -> Optional[Dict[str, Any]]:
    barcode = re.sub(r"\D", "", str(product.get("code") or ""))
    name = _clean(product.get("product_name"))
    image = _clean(product.get("image_front_url") or product.get("image_url"), 1024)
    has_category = bool(product.get("categories_tags_en") or product.get("categories"))
    try:
        too_incomplete = product.get("completeness") is not None and float(product["completeness"]) < 0.3
    except (TypeError, ValueError):
        too_incomplete = False
    if len(barcode) < 6 or not name or not image or not has_category or product.get("obsolete") or too_incomplete:
        return None
    category = _category(product)
    identity = f"{country_code}:{barcode}"
    quantity = _clean(product.get("quantity"), 80)
    return {
        "id": f"off_{country_code.lower()}_{barcode}", "type": "grocery", "name": name,
        "brand": _clean(product.get("brands")), "category": category,
        "description": f"{name}{f' ({quantity})' if quantity else ''} from the Open Food Facts community catalog.",
        "image_url": image, "source": "openfoodfacts", "source_id": barcode,
        "country_code": country_code, "is_fictional": False,
        "image_license": "CC BY-SA 3.0", "image_license_url": "https://creativecommons.org/licenses/by-sa/3.0/",
        "image_attribution": "Open Food Facts contributors", "image_source_url": image,
        "source_url": f"https://world.openfoodfacts.org/product/{barcode}",
        **stable_catalog_values(identity, category, "grocery"),
    }


async def fetch_openfoodfacts_country_products(country_code: str, *, client=None, page_size: Optional[int] = None) -> List[Dict[str, Any]]:
    code = country_code.strip().upper()
    if not pycountry.countries.get(alpha_2=code):
        raise ValueError(f"Invalid ISO country code: {code}")
    country = pycountry.countries.get(alpha_2=code)
    country_tag = re.sub(r"[^a-z0-9]+", "-", country.name.lower()).strip("-")
    params = {
        "countries_tags_en": country_tag, "fields": OFF_FIELDS, "page": 1,
        "page_size": min(page_size or settings.OPENFOODFACTS_PRODUCTS_PER_COUNTRY, 100),
        "sort_by": "popularity_key",
    }
    async with ExternalHTTPClient("openfoodfacts-sync", client) as http:
        payload = await http.get_json(f"{settings.OPENFOODFACTS_API_BASE.rstrip('/')}/search", params=params)
    products = [normalize_openfoodfacts_product(item, code) for item in payload.get("products", []) if isinstance(item, dict)]
    unique = {item["id"]: item for item in products if item}
    if not unique:
        raise ValueError(f"Open Food Facts returned no usable products for {code}")
    return list(unique.values())


async def sync_openfoodfacts_country(db: Session, country_code: str, *, client=None, dry_run: bool = False) -> int:
    code = country_code.upper()
    if dry_run:
        products = await fetch_openfoodfacts_country_products(code, client=client)
        return replace_source_products(
            db, products, source="openfoodfacts", product_type="grocery",
            country_code=code, dry_run=True,
        )
    record = country_sync_record(db, code)
    record.status = "running"
    record.last_attempt_at = utcnow()
    record.error_code = None
    db.commit()
    run = start_sync(db, "openfoodfacts", code)
    try:
        products = await fetch_openfoodfacts_country_products(code, client=client)
        written = replace_source_products(
            db, products, source="openfoodfacts", product_type="grocery",
            country_code=code, dry_run=dry_run,
        )
        record = country_sync_record(db, code)
        record.status = "success"
        record.product_count = written
        record.last_success_at = utcnow()
        record.error_code = None
        db.commit()
        finish_sync(db, run, len(products), written)
        return written
    except Exception as exc:
        db.rollback()
        record = country_sync_record(db, code)
        record.status = "failed"
        record.error_code = getattr(exc, "code", type(exc).__name__.lower())[:64]
        db.commit()
        fail_sync(db, run, exc)
        raise


def should_queue_country_sync(db: Session, country_code: str) -> bool:
    record = country_sync_record(db, country_code)
    now = utcnow()
    updated = (
        db.query(CatalogCountrySyncModel)
        .filter(
            CatalogCountrySyncModel.id == record.id,
            or_(
                CatalogCountrySyncModel.status != "running",
                CatalogCountrySyncModel.last_attempt_at.is_(None),
                CatalogCountrySyncModel.last_attempt_at < now - timedelta(minutes=15),
            ),
            or_(
                CatalogCountrySyncModel.last_success_at.is_(None),
                CatalogCountrySyncModel.last_success_at < now - timedelta(days=1),
            ),
        )
        .update({"status": "running", "last_attempt_at": now}, synchronize_session=False)
    )
    db.commit()
    return updated == 1


async def background_sync_country(country_code: str) -> None:
    db = SessionLocal()
    try:
        await sync_openfoodfacts_country(db, country_code)
    except Exception:
        # Failure is recorded in sanitized synchronization status. Never fail
        # the client request that caused the lazy refresh.
        return
    finally:
        db.close()


async def sync_seed_countries(db: Session, countries: List[str], *, dry_run: bool = False) -> Dict[str, Any]:
    results: Dict[str, Any] = {}
    for index, code in enumerate(countries):
        if index:
            await asyncio.sleep(settings.OPENFOODFACTS_MIN_INTERVAL_SECONDS)
        try:
            results[code] = await sync_openfoodfacts_country(db, code, dry_run=dry_run)
        except Exception as exc:
            results[code] = {"error": getattr(exc, "code", type(exc).__name__.lower())}
    return results
