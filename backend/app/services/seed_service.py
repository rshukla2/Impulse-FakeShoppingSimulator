"""Validated, idempotent local seed imports.

The checksum-protected reference catalog supplies realistic fallback records.
Fictional shopping data has one editable source of truth:
``data/fictional-products.json``.
"""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any, Dict, Iterable, List

from sqlalchemy.orm import Session

from backend.app.config import settings
from backend.app.models import RestaurantModel
from backend.app.services.catalog_store import replace_source_products
from backend.app.services.currency_service import seed_fallback_rates
from backend.app.services.grocery_categories import normalize_cached_grocery_categories


FICTIONAL_PATH = settings.project_root / "data" / "fictional-products.json"
REFERENCE_CATALOG_PATH = settings.project_root / "data" / "reference-catalog.json"
REALISTIC_SEED_PATH = settings.project_root / "data" / "realistic-seed-products.json"
RESTAURANT_PATH = settings.project_root / "data" / "restaurants.json"


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
        _required(item, ("id", "name", "category", "base_price_usd"), "Fictional product")
        if item["id"] in ids:
            raise ValueError(f"Duplicate fictional product ID: {item['id']}")
        ids.add(item["id"])
        result.append({
            "id": item["id"], "type": "shopping", "name": item["name"],
            "brand": item.get("brand"), "category": item["category"],
            "description": item.get("description"), "image_url": item.get("image"),
            "source": "fictional", "source_id": item["id"],
            "base_price_usd": float(item["base_price_usd"]),
            "original_price_usd": item.get("original_price_usd"),
            "rating": item.get("rating", 4.8), "review_count": item.get("review_count", 1000),
            "is_fictional": True, "image_license": item.get("image_license"),
            "image_attribution": item.get("image_attribution"), "image_source_url": item.get("image"),
        })
    if len(result) != 34:
        raise ValueError(f"Expected 34 preserved fictional products, found {len(result)}")
    return result


def load_reference_seed_catalog() -> tuple[List[Dict[str, Any]], List[Dict[str, Any]]]:
    """Read the checksum-protected reference catalog."""
    catalog = _read_json(REFERENCE_CATALOG_PATH)
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


def load_realistic_seed_products() -> List[Dict[str, Any]]:
    payload = _read_json(REALISTIC_SEED_PATH)
    if not isinstance(payload, list):
        raise ValueError("realistic-seed-products.json must contain a JSON array")
    ids = set()
    result = []
    for item in payload:
        _required(
            item,
            ("id", "type", "name", "category", "source", "base_price_usd"),
            "Realistic seed product",
        )
        if item["id"] in ids:
            raise ValueError(f"Duplicate realistic seed product ID: {item['id']}")
        if item["type"] not in {"shopping", "grocery", "food"}:
            raise ValueError(f"Unsupported seed product type: {item['type']}")
        if not str(item["source"]).startswith("seed_"):
            raise ValueError(f"Realistic seed source must start with seed_: {item['id']}")
        if item.get("is_fictional"):
            raise ValueError(f"Realistic seed cannot be fictional: {item['id']}")
        ids.add(item["id"])
        result.append(dict(item))
    if len(result) != 41:
        raise ValueError(f"Expected 41 realistic seed products, found {len(result)}")
    return result


def load_restaurants() -> List[Dict[str, Any]]:
    payload = _read_json(RESTAURANT_PATH)
    if not isinstance(payload, list):
        raise ValueError("restaurants.json must contain a JSON array")
    ids = set()
    for item in payload:
        _required(item, ("id", "name", "cuisine"), "Restaurant")
        if item["id"] in ids:
            raise ValueError(f"Duplicate restaurant ID: {item['id']}")
        ids.add(item["id"])
    if len(payload) != 6:
        raise ValueError(f"Expected 6 restaurant templates, found {len(payload)}")
    return payload


def seed_database_if_empty(db: Session) -> Dict[str, int]:
    """Converge every database on the tracked, validated local seed catalog."""
    seed_fallback_rates(db)
    fictional = load_fictional_products()
    realistic = load_realistic_seed_products()
    restaurants = load_restaurants()
    restaurant_count = 0
    for item in restaurants:
        restaurant = db.get(RestaurantModel, item["id"])
        values = {
            "name": item["name"],
            "cuisine": item["cuisine"],
            "tagline": item.get("tagline"),
            "image_url": item.get("image_url"),
            "rating": item.get("rating", 4.8),
            "review_count": item.get("review_count", 1000),
            "country_relevance": item.get("country_relevance") or "GLOBAL",
            "price_level": item.get("price_level", "$$"),
        }
        if restaurant is None:
            db.add(RestaurantModel(
                id=item["id"], name=item["name"], cuisine=item["cuisine"],
                tagline=values["tagline"], image_url=values["image_url"],
                rating=values["rating"], review_count=values["review_count"],
                country_relevance=values["country_relevance"],
                price_level=values["price_level"],
            ))
            restaurant_count += 1
        else:
            for key, value in values.items():
                setattr(restaurant, key, value)
    db.commit()

    product_count = replace_source_products(
        db,
        fictional,
        source="fictional",
        product_type="shopping",
    )
    for source, product_type in (
        ("seed_icecat", "shopping"),
        ("seed_openfoodfacts", "grocery"),
        ("seed_wikidata", "food"),
    ):
        products = [
            item
            for item in realistic
            if item["source"] == source and item["type"] == product_type
        ]
        product_count += replace_source_products(
            db,
            products,
            source=source,
            product_type=product_type,
        )
    normalize_cached_grocery_categories(db)
    return {"fictional": len(fictional), "realistic": len(realistic), "restaurants_added": restaurant_count, "products_written": product_count}
