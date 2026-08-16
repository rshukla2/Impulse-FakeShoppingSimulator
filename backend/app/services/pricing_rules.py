"""Stable simulated catalog values derived from source identities."""

from __future__ import annotations

import hashlib


PRICE_RANGES = {
    "Electronics": (24.0, 1800.0),
    "Computers": (49.0, 2400.0),
    "Gaming": (19.0, 800.0),
    "Appliances": (39.0, 1500.0),
    "Home": (9.0, 500.0),
    "Accessories": (7.0, 240.0),
    "Toys": (8.0, 220.0),
    "Office": (6.0, 600.0),
    "Fashion": (12.0, 450.0),
    "Groceries": (1.0, 32.0),
    "Food": (5.0, 28.0),
}


def stable_fraction(identity: str, salt: str) -> float:
    digest = hashlib.sha256(f"{salt}:{identity}".encode("utf-8")).digest()
    return int.from_bytes(digest[:8], "big") / float(2**64 - 1)


def stable_catalog_values(identity: str, category: str, kind: str) -> dict:
    bucket = "Groceries" if kind == "grocery" else "Food" if kind == "food" else category
    minimum, maximum = PRICE_RANGES.get(bucket, (10.0, 500.0))
    base = round(minimum + stable_fraction(identity, "price") * (maximum - minimum), 2)
    markup = 1.08 + stable_fraction(identity, "markup") * 0.24
    return {
        "base_price_usd": base,
        "original_price_usd": round(base * markup, 2),
        "rating": round(4.1 + stable_fraction(identity, "rating") * 0.8, 1),
        "review_count": 50 + int(stable_fraction(identity, "reviews") * 19950),
    }

