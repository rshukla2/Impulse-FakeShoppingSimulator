"""Currency metadata and cached Frankfurter exchange rates."""

from __future__ import annotations

from typing import Dict, Optional

from babel.numbers import get_currency_name, get_currency_symbol
from sqlalchemy.orm import Session

from backend.app.config import settings
from backend.app.models import ExchangeRateModel
from backend.app.services.external_http import ExternalHTTPClient


FALLBACK_RATES = {
    "USD": 1.0, "INR": 83.25, "GBP": 0.79, "EUR": 0.92, "JPY": 155.40,
    "CAD": 1.36, "AUD": 1.52, "MXN": 16.90, "BRL": 5.15, "SGD": 1.35,
    "AED": 3.67, "LKR": 300.0, "NPR": 133.0, "BDT": 117.0,
}


def currency_symbol(currency: str) -> str:
    try:
        return get_currency_symbol(currency.upper(), locale="en_US")
    except (KeyError, ValueError):
        return currency.upper()


CURRENCY_SYMBOLS = {code: currency_symbol(code) for code in FALLBACK_RATES}


def get_exchange_rate(db: Session, target_currency: str) -> float:
    code = target_currency.upper()
    if code == "USD":
        return 1.0
    record = db.get(ExchangeRateModel, code)
    if record and record.rate_to_usd > 0:
        return record.rate_to_usd
    return FALLBACK_RATES.get(code, 1.0)


def resolve_geo_currency(db: Session, geo: dict) -> dict:
    """Use USD coherently when no cached/fallback rate supports a currency."""
    code = str(geo.get("currency") or "USD").upper()
    if code == "USD" or code in FALLBACK_RATES or db.get(ExchangeRateModel, code) is not None:
        return geo
    resolved = dict(geo)
    resolved["currency"] = "USD"
    resolved["symbol"] = currency_symbol("USD")
    return resolved


def seed_fallback_rates(db: Session) -> None:
    changed = False
    for code, rate in FALLBACK_RATES.items():
        if db.get(ExchangeRateModel, code) is None:
            try:
                name = get_currency_name(code, locale="en_US")
            except (KeyError, ValueError):
                name = code
            db.add(ExchangeRateModel(currency=code, rate_to_usd=rate, symbol=currency_symbol(code), name=name))
            changed = True
    if changed:
        db.commit()


def normalize_frankfurter_rates(payload) -> Dict[str, float]:
    rates: Dict[str, float] = {"USD": 1.0}
    if isinstance(payload, list):
        for item in payload:
            if not isinstance(item, dict) or str(item.get("base", "USD")).upper() != "USD":
                continue
            code = str(item.get("quote", "")).upper()
            try:
                rate = float(item["rate"])
            except (KeyError, TypeError, ValueError):
                continue
            if len(code) == 3 and rate > 0:
                rates[code] = rate
    elif isinstance(payload, dict):
        for code, value in payload.get("rates", {}).items():
            try:
                rate = float(value)
            except (TypeError, ValueError):
                continue
            if len(code) == 3 and rate > 0:
                rates[code.upper()] = rate
    return rates


async def sync_frankfurter_rates(db: Session, *, client=None, dry_run: bool = False) -> int:
    async with ExternalHTTPClient("currency-sync", client) as http:
        payload = await http.get_json(f"{settings.FRANKFURTER_API_BASE.rstrip('/')}/rates", params={"base": "USD"})
    rates = normalize_frankfurter_rates(payload)
    if len(rates) <= 1:
        raise ValueError("Frankfurter returned no usable non-USD rates")
    for code, rate in rates.items():
        record: Optional[ExchangeRateModel] = db.get(ExchangeRateModel, code)
        values = {"rate_to_usd": rate, "symbol": currency_symbol(code), "name": get_currency_name(code, locale="en_US")}
        if record is None:
            db.add(ExchangeRateModel(currency=code, **values))
        else:
            for key, value in values.items():
                setattr(record, key, value)
    if dry_run:
        db.rollback()
    else:
        db.commit()
    return len(rates)
