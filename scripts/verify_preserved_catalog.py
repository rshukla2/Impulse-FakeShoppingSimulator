#!/usr/bin/env python3
"""Verify the checksum-protected reference catalog."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path


CATALOG_PATH = Path(__file__).resolve().parents[1] / "data" / "reference-catalog.json"
EXPECTED_SHA256 = "a22fd71ef4e2070038e3d3eb1d5d8a1fb982d1ad80173c522b7a758c4a34c440"


def main() -> None:
    payload = CATALOG_PATH.read_bytes()
    digest = hashlib.sha256(payload).hexdigest()
    if digest != EXPECTED_SHA256:
        raise SystemExit(f"Catalog checksum mismatch: expected {EXPECTED_SHA256}, found {digest}")

    catalog = json.loads(payload)
    products = catalog.get("products", [])
    restaurants = catalog.get("restaurants", [])
    if len(products) != 21 or len(restaurants) != 5:
        raise SystemExit(
            f"Catalog count mismatch: expected 21 products/5 restaurants, found {len(products)}/{len(restaurants)}"
        )
    if len({item["id"] for item in products}) != len(products):
        raise SystemExit("Duplicate product IDs found in preserved catalog")
    if len({item["id"] for item in restaurants}) != len(restaurants):
        raise SystemExit("Duplicate restaurant IDs found in preserved catalog")

    print(f"Verified {len(products)} products and {len(restaurants)} restaurants ({digest})")


if __name__ == "__main__":
    main()
