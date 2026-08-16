from fastapi import APIRouter, Depends, Request, Query
from sqlalchemy.orm import Session
from backend.app.database import get_db
from backend.app.schemas import BootstrapResponse
from backend.app.services.geo_service import detect_country_from_request, get_supported_countries
from backend.app.services.currency_service import get_exchange_rate, resolve_geo_currency

router = APIRouter(tags=["bootstrap"])

@router.get("/bootstrap", response_model=BootstrapResponse)
def get_bootstrap_data(
    request: Request,
    country: str = Query(None, description="Optional manual country code override"),
    db: Session = Depends(get_db)
):
    geo = detect_country_from_request(request, override_country=country)
    geo = resolve_geo_currency(db, geo)
    rate = get_exchange_rate(db, geo["currency"])
    
    return BootstrapResponse(
        country_code=geo["country_code"],
        country_name=geo["country_name"],
        currency=geo["currency"],
        currency_symbol=geo["symbol"],
        exchange_rate=rate,
        supported_countries=get_supported_countries()
    )
