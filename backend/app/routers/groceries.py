from fastapi import APIRouter, BackgroundTasks, Depends, Request, Query, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import or_
from typing import Optional

from backend.app.database import get_db
from backend.app.models import ProductModel
from backend.app.schemas import ProductListResponse, ProductBase
from backend.app.services.geo_service import detect_country_from_request
from backend.app.services.currency_service import get_exchange_rate, resolve_geo_currency
from backend.app.services.pricing_service import localize_product_pricing
from backend.app.services.product_service import product_payload
from backend.app.services.openfoodfacts_service import background_sync_country, should_queue_country_sync
from backend.app.config import settings

router = APIRouter(prefix="/groceries", tags=["groceries"])

@router.get("", response_model=ProductListResponse)
def get_grocery_products(
    request: Request,
    background_tasks: BackgroundTasks,
    country: Optional[str] = Query(None, min_length=2, max_length=2, pattern=r"^[A-Za-z]{2}$"),
    category: Optional[str] = Query(None, max_length=128),
    search: Optional[str] = Query(None, max_length=100),
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
    db: Session = Depends(get_db)
):
    geo = detect_country_from_request(request, override_country=country)
    geo = resolve_geo_currency(db, geo)
    rate = get_exchange_rate(db, geo["currency"])
    country_code = geo["country_code"]
    
    query = db.query(ProductModel).filter(ProductModel.type == "grocery", ProductModel.is_active.is_(True))
    
    if category and category != "All":
        query = query.filter(ProductModel.category == category)
        
    if search:
        search_fmt = f"%{search.strip()}%"
        query = query.filter(
            or_(
                ProductModel.name.ilike(search_fmt),
                ProductModel.description.ilike(search_fmt),
                ProductModel.brand.ilike(search_fmt),
                ProductModel.category.ilike(search_fmt)
            )
        )

    all_items = query.order_by(ProductModel.id.asc()).all()
    
    # Never leak unrelated countries into a country-scoped grocery catalog.
    country_matches = [p for p in all_items if p.country_code == country_code]
    global_items = [p for p in all_items if p.country_code is None]
    if country_matches:
        ordered_items = country_matches + global_items
    else:
        # First-request fallback while an unseen country is populated.
        ordered_items = [p for p in all_items if p.country_code == settings.DEFAULT_COUNTRY_CODE] + global_items

    has_live_country_cache = any(p.source == "openfoodfacts" for p in country_matches)
    if (
        settings.ENABLE_LAZY_COUNTRY_SYNC
        and country_code not in settings.openfoodfacts_country_codes
        and not has_live_country_cache
        and should_queue_country_sync(db, country_code)
    ):
        background_tasks.add_task(background_sync_country, country_code)
    
    total = len(ordered_items)
    start = (page - 1) * limit
    end = start + limit
    page_items = ordered_items[start:end]
    
    localized_items = [
        localize_product_pricing(product_payload(p), geo["currency"], rate, geo["symbol"])
        for p in page_items
    ]
    
    return ProductListResponse(
        items=localized_items,
        total=total,
        page=page,
        limit=limit,
        has_more=end < total,
        detected_country=country_code,
        currency=geo["currency"]
    )


@router.get("/{id}", response_model=ProductBase)
def get_grocery_by_id(
    id: str,
    request: Request,
    country: Optional[str] = Query(None, min_length=2, max_length=2, pattern=r"^[A-Za-z]{2}$"),
    db: Session = Depends(get_db)
):
    geo = detect_country_from_request(request, override_country=country)
    geo = resolve_geo_currency(db, geo)
    rate = get_exchange_rate(db, geo["currency"])
    
    p = db.query(ProductModel).filter(ProductModel.id == id, ProductModel.type == "grocery", ProductModel.is_active.is_(True)).first()
    if not p:
        raise HTTPException(status_code=404, detail="Grocery item not found")
        
    return localize_product_pricing(product_payload(p), geo["currency"], rate, geo["symbol"])
