"""Transactional catalog cache and synchronization status helpers."""

from __future__ import annotations

import re
from datetime import datetime, timezone
from typing import Iterable, Mapping, Optional

from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from backend.app.models import CatalogCountrySyncModel, CatalogSyncRunModel, ProductModel


PRODUCT_FIELDS = {
    "type", "name", "brand", "category", "cuisine", "description", "image_url",
    "source", "source_id", "base_price_usd", "original_price_usd", "rating",
    "review_count", "is_fictional", "country_code", "restaurant_id", "image_license",
    "image_attribution", "image_license_url", "source_url", "image_source_url",
    "source_updated_at", "is_active",
}


def utcnow() -> datetime:
    return datetime.now(timezone.utc)


def sanitized_error(exc: BaseException) -> tuple[str, str]:
    code = getattr(exc, "code", type(exc).__name__.lower())
    message = re.sub(r"(?i)(api[_-]?key|token|password|license[_-]?key)=?[^\s&,]*", r"\1=[redacted]", str(exc))
    return str(code)[:64], message[:500]


def start_sync(db: Session, source: str, scope: Optional[str] = None) -> CatalogSyncRunModel:
    run = CatalogSyncRunModel(source=source, scope=scope, status="running")
    db.add(run)
    db.commit()
    db.refresh(run)
    return run


def finish_sync(db: Session, run: CatalogSyncRunModel, seen: int, written: int) -> None:
    run.status = "success"
    run.records_seen = seen
    run.records_written = written
    run.finished_at = utcnow()
    db.commit()


def fail_sync(db: Session, run: CatalogSyncRunModel, exc: BaseException) -> None:
    run.status = "failed"
    run.error_code, run.error_message = sanitized_error(exc)
    run.finished_at = utcnow()
    db.commit()


def upsert_products(db: Session, products: Iterable[Mapping], *, dry_run: bool = False, commit: bool = True) -> int:
    products = list(products)
    if not products:
        raise ValueError("Provider returned no usable products; existing cache was retained")
    written = 0
    for payload in products:
        product_id = str(payload["id"])
        existing = db.get(ProductModel, product_id)
        values = {key: value for key, value in payload.items() if key in PRODUCT_FIELDS}
        values.setdefault("is_active", True)
        if values.get("source") in {"icecat", "openfoodfacts", "wikidata"}:
            values.setdefault("source_updated_at", utcnow())
        if existing is None:
            db.add(ProductModel(id=product_id, **values))
        else:
            for key, value in values.items():
                setattr(existing, key, value)
        written += 1
    if dry_run:
        db.rollback()
    elif commit:
        db.commit()
    return written


def replace_source_products(
    db: Session,
    products: Iterable[Mapping],
    *,
    source: str,
    product_type: str,
    country_code: Optional[str] = None,
    dry_run: bool = False,
) -> int:
    products = list(products)
    written = upsert_products(db, products, commit=False)
    active_ids = {str(product["id"]) for product in products}
    query = db.query(ProductModel).filter(ProductModel.source == source, ProductModel.type == product_type)
    if country_code:
        query = query.filter(ProductModel.country_code == country_code.upper())
    for stale in query.all():
        stale.is_active = stale.id in active_ids
    if dry_run:
        db.rollback()
    else:
        db.commit()
    return written


def country_sync_record(db: Session, country_code: str) -> CatalogCountrySyncModel:
    code = country_code.upper()
    record = db.query(CatalogCountrySyncModel).filter_by(source="openfoodfacts", country_code=code).one_or_none()
    if record is None:
        record = CatalogCountrySyncModel(source="openfoodfacts", country_code=code, status="never")
        db.add(record)
        try:
            db.commit()
            db.refresh(record)
        except IntegrityError:
            # Another worker created the same country row between SELECT and
            # INSERT. The unique constraint is the cross-worker lock.
            db.rollback()
            record = db.query(CatalogCountrySyncModel).filter_by(source="openfoodfacts", country_code=code).one()
    return record
