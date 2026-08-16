#!/usr/bin/env python3
"""Validate production configuration without printing secret values."""

from __future__ import annotations

import os
import sys
from pathlib import Path

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from backend.app.config import settings


def main() -> None:
    errors: list[str] = []
    if settings.ENVIRONMENT.lower() != "production":
        errors.append("ENVIRONMENT must be production")
    if settings.IMPULSE_DEBUG:
        errors.append("IMPULSE_DEBUG must be false")
    if not settings.DATABASE_URL.startswith("sqlite:////"):
        errors.append("DATABASE_URL must use an absolute SQLite path")
    if not Path(settings.GEOIP_DATABASE_PATH).is_absolute():
        errors.append("GEOIP_DATABASE_PATH must be absolute")
    if not settings.TRUST_PROXY_HEADERS:
        errors.append("TRUST_PROXY_HEADERS must be true behind local nginx")
    if settings.ENABLE_LAZY_COUNTRY_SYNC:
        errors.append("ENABLE_LAZY_COUNTRY_SYNC must be false in production")
    if not settings.ICECAT_API_ACCESS_TOKEN:
        errors.append("ICECAT_API_ACCESS_TOKEN is required")
    if not settings.ICECAT_CONTENT_ACCESS_TOKEN:
        errors.append("ICECAT_CONTENT_ACCESS_TOKEN is required")
    if not settings.MAXMIND_ACCOUNT_ID or not settings.MAXMIND_LICENSE_KEY:
        errors.append("MaxMind account ID and license key are required for updates")
    origins = settings.cors_allowed_origins
    if "*" in origins:
        errors.append("wildcard CORS is forbidden")
    if not any(origin.startswith("https://") and origin.endswith("github.io") for origin in origins):
        errors.append("CORS must include the GitHub Pages HTTPS origin")
    if settings.CORS_ALLOWED_ORIGIN_REGEX:
        errors.append("CORS_ALLOWED_ORIGIN_REGEX should be blank in production")

    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        raise SystemExit(1)
    print("Production environment validation passed (secret values not displayed).")


if __name__ == "__main__":
    main()
