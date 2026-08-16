#!/usr/bin/env python3
"""Apply safe additive migrations and converge tracked seed data."""

from __future__ import annotations

import os
import sys

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from backend.app.database import SessionLocal, migrate_database
from backend.app.services.seed_service import seed_database_if_empty


def main() -> None:
    migrate_database()
    db = SessionLocal()
    try:
        summary = seed_database_if_empty(db)
    finally:
        db.close()
    print(
        "Database ready: "
        f"{summary['fictional']} fictional seeds, "
        f"{summary['realistic']} realistic seeds, "
        f"{summary['products_written']} seed records converged."
    )


if __name__ == "__main__":
    main()
