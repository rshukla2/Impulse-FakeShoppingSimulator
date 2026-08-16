#!/usr/bin/env python3
"""Verify the immutable Google AI Studio catalog snapshot."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path


CATALOG_PATH = Path(__file__).resolve().parents[1] / "data" / "google-ai-studio-catalog.json"
EXPECTED_SHA256 = "b651c6c9bebea70212a321ccf7374e296be63d4f82d0893f2a6f1f7129275c47"


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
