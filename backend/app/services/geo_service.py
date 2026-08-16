"""Privacy-preserving country detection backed by local GeoLite2 Country."""

from __future__ import annotations

from datetime import date
from ipaddress import ip_address
from pathlib import Path
from threading import Lock
from typing import Any, Dict, Mapping, Optional, Tuple

import geoip2.database
import pycountry
from babel.numbers import get_currency_symbol, get_territory_currencies
from fastapi import Request
from geoip2.errors import AddressNotFoundError
from maxminddb.errors import InvalidDatabaseError

from backend.app.config import settings


def country_metadata(code: str, detected_name: Optional[str] = None) -> Dict[str, str]:
    code = code.upper()
    country = pycountry.countries.get(alpha_2=code)
    name = getattr(country, "name", None) or detected_name or code
    today = date.today()
    try:
        currencies = get_territory_currencies(code, start_date=today, end_date=today, tender=True, non_tender=False)
    except (KeyError, ValueError):
        currencies = []
    currency = currencies[0] if currencies else settings.DEFAULT_CURRENCY
    try:
        symbol = get_currency_symbol(currency, locale="en_US")
    except (KeyError, ValueError):
        symbol = currency
    return {"country_code": code, "country_name": name, "currency": currency, "symbol": symbol}


FALLBACK_COUNTRY = country_metadata(settings.DEFAULT_COUNTRY_CODE, settings.DEFAULT_COUNTRY_NAME)


def extract_client_ip(request_headers: Mapping[str, str], client_host: Optional[str], trust_proxy_headers: bool) -> Optional[str]:
    candidate = client_host or ""
    if trust_proxy_headers:
        forwarded_for = request_headers.get("x-forwarded-for", "")
        real_ip = request_headers.get("x-real-ip", "")
        if forwarded_for:
            candidate = forwarded_for.split(",", 1)[0].strip()
        elif real_ip:
            candidate = real_ip.strip()
    try:
        parsed = ip_address(candidate)
    except ValueError:
        return None
    if not parsed.is_global or parsed.is_private or parsed.is_loopback or parsed.is_link_local or parsed.is_multicast or parsed.is_reserved or parsed.is_unspecified:
        return None
    return parsed.compressed


class GeoIPCountryDatabase:
    def __init__(self, database_path: str):
        self._database_path = Path(database_path)
        self._reader: Optional[geoip2.database.Reader] = None
        self._mtime_ns: Optional[int] = None
        self._lock = Lock()

    def lookup(self, client_ip: str) -> Optional[Tuple[str, str]]:
        reader = self._get_reader()
        if reader is None:
            return None
        try:
            result = reader.country(client_ip)
        except (AddressNotFoundError, ValueError, OSError):
            return None
        code = (result.country.iso_code or "").upper()
        return (code, result.country.name or code) if len(code) == 2 else None

    def _get_reader(self) -> Optional[geoip2.database.Reader]:
        try:
            mtime_ns = self._database_path.stat().st_mtime_ns
        except OSError:
            return None
        with self._lock:
            if self._reader is not None and self._mtime_ns == mtime_ns:
                return self._reader
            self.close()
            try:
                reader = geoip2.database.Reader(str(self._database_path))
                if "Country" not in reader.metadata().database_type:
                    reader.close()
                    return None
                self._reader = reader
            except (InvalidDatabaseError, OSError, ValueError):
                self._reader = None
                self._mtime_ns = None
                return None
            self._mtime_ns = mtime_ns
            return self._reader

    def close(self) -> None:
        if self._reader is not None:
            self._reader.close()
        self._reader = None
        self._mtime_ns = None


geoip_country_database = GeoIPCountryDatabase(settings.GEOIP_DATABASE_PATH)


def detect_country_from_request(request: Request, override_country: Optional[str] = None) -> Dict[str, Any]:
    if override_country:
        code = override_country.strip().upper()
        if pycountry.countries.get(alpha_2=code):
            return country_metadata(code)
    client_ip = extract_client_ip(request.headers, request.client.host if request.client else None, settings.TRUST_PROXY_HEADERS)
    if client_ip is None:
        return dict(FALLBACK_COUNTRY)
    detected = geoip_country_database.lookup(client_ip)
    return country_metadata(*detected) if detected else dict(FALLBACK_COUNTRY)


def close_geoip_database() -> None:
    geoip_country_database.close()


def get_supported_countries():
    result = []
    for country in sorted(pycountry.countries, key=lambda item: item.name):
        metadata = country_metadata(country.alpha_2)
        result.append({"code": country.alpha_2, "name": country.name, "currency": metadata["currency"], "symbol": metadata["symbol"]})
    return result
