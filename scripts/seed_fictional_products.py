#!/usr/bin/env python3
"""
Seed fictional humorous products from data/fictional-products.json into SQLite.
Usage:
    python scripts/seed_fictional_products.py
"""
import json
import os
import sys

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from backend.app.database import SessionLocal, migrate_database
from backend.app.services.seed_service import seed_database_if_empty

def main():
    print("[Seed] Loading fictional products JSON...")
    json_path = os.path.join(os.path.dirname(os.path.dirname(__file__)), "data", "fictional-products.json")
    if not os.path.exists(json_path):
        print(f"[Error] File not found: {json_path}")
        return

    migrate_database()
    db = SessionLocal()
    try:
        result = seed_database_if_empty(db)
        print(f"[Seed] Validated and upserted {result['fictional']} fictional products.")
    finally:
        db.close()

if __name__ == "__main__":
    main()
