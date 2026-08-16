"""Validated, idempotent local seed imports.

The preserved AI Studio snapshot is read-only and supplies realistic fallback
records. Fictional shopping data has one editable source of truth:
``data/fictional-products.json``.
"""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any, Dict, Iterable, List

from sqlalchemy.orm import Session

from backend.app.config import settings
from backend.app.models import ProductModel, RestaurantModel
from backend.app.services.catalog_store import upsert_products
from backend.app.services.currency_service import seed_fallback_rates


FICTIONAL_PATH = settings.project_root / "data" / "fictional-products.json"
PRESERVED_CATALOG_PATH = settings.project_root / "data" / "google-ai-studio-catalog.json"


def _read_json(path: Path):
    with path.open("r", encoding="utf-8") as source:
        return json.load(source)


def _required(item: Dict[str, Any], fields: Iterable[str], label: str) -> None:
    missing = [field for field in fields if item.get(field) in (None, "")]
    if missing:
        raise ValueError(f"{label} {item.get('id', '<unknown>')} missing: {', '.join(missing)}")


def load_fictional_products() -> List[Dict[str, Any]]:
    payload = _read_json(FICTIONAL_PATH)
    if not isinstance(payload, list):
        raise ValueError("fictional-products.json must contain a JSON array")
    ids = set()
    result = []
    for item in payload:
        _required(item, ("id", "name", "category", "base_price_usd", "image"), "Fictional product")
        if item["id"] in ids:
            raise ValueError(f"Duplicate fictional product ID: {item['id']}")
        ids.add(item["id"])
        result.append({
            "id": item["id"], "type": "shopping", "name": item["name"],
            "brand": item.get("brand"), "category": item["category"],
            "description": item.get("description"), "image_url": item["image"],
            "source": "fictional", "source_id": item["id"],
            "base_price_usd": float(item["base_price_usd"]),
            "original_price_usd": item.get("original_price_usd"),
            "rating": item.get("rating", 4.8), "review_count": item.get("review_count", 1000),
            "is_fictional": True, "image_license": item.get("image_license"),
            "image_attribution": item.get("image_attribution"), "image_source_url": item["image"],
        })
    if len(result) != 34:
        raise ValueError(f"Expected 34 preserved fictional products, found {len(result)}")
    return result


def load_preserved_seed_catalog() -> tuple[List[Dict[str, Any]], List[Dict[str, Any]]]:
    catalog = _read_json(PRESERVED_CATALOG_PATH)
    products = []
    for item in catalog.get("products", []):
        if item.get("is_fictional"):
            continue
        _required(item, ("id", "type", "name", "category", "source", "base_price_usd"), "Seed product")
        normalized = dict(item)
        normalized.pop("restaurant_name", None)
        normalized["source"] = f"seed_{item['source']}"
        normalized["image_source_url"] = item.get("image_url")
        products.append(normalized)
    return products, catalog.get("restaurants", [])


def seed_database_if_empty(db: Session) -> Dict[str, int]:
    seed_fallback_rates(db)
    fictional = load_fictional_products()
    realistic, restaurants = load_preserved_seed_catalog()
    restaurant_count = 0
    for item in restaurants:
        _required(item, ("id", "name", "cuisine"), "Restaurant")
        if db.get(RestaurantModel, item["id"]) is None:
            db.add(RestaurantModel(
                id=item["id"], name=item["name"], cuisine=item["cuisine"],
                tagline=item.get("tagline"), image_url=item.get("image_url"),
                rating=item.get("rating", 4.8), review_count=item.get("review_count", 1000),
                country_relevance=item.get("country_relevance") or "GLOBAL",
                price_level=item.get("price_level", "$$"),
            ))
            restaurant_count += 1
    db.commit()
    # Earlier drafts inserted static placeholders under live-provider source
    # names. Reclassify only their stable legacy ID namespaces so a later
    # provider refresh never deactivates them.
    for prefix, source in (("ice_", "icecat"), ("groc_", "openfoodfacts"), ("dish_", "wikidata")):
        for product in db.query(ProductModel).filter(ProductModel.id.like(f"{prefix}%"), ProductModel.source == source).all():
            product.source = f"seed_{source}"
    db.commit()
    product_count = upsert_products(db, [*fictional, *realistic])
    return {"fictional": len(fictional), "realistic": len(realistic), "restaurants_added": restaurant_count, "products_written": product_count}
