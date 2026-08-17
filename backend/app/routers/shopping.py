from fastapi import APIRouter, Depends, Request, Query, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import or_
from typing import Optional
import random

from backend.app.database import get_db
from backend.app.models import ProductModel
from backend.app.schemas import ProductListResponse, ProductBase
from backend.app.services.geo_service import detect_country_from_request
from backend.app.services.currency_service import get_exchange_rate, resolve_geo_currency
from backend.app.services.pricing_service import localize_product_pricing
from backend.app.services.product_service import product_payload

router = APIRouter(prefix="/shopping", tags=["shopping"])

@router.get("", response_model=ProductListResponse)
def get_shopping_products(
    request: Request,
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
    
    query = db.query(ProductModel).filter(ProductModel.type == "shopping", ProductModel.is_active.is_(True))
    
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

    # Every usable image ranks ahead of every missing image. Within each
    # partition, retain the stable standard/fictional interleaving so adding
    # images later does not make pagination random.
    with_images = [p for p in all_items if p.image_url and p.image_url.strip()]
    without_images = [p for p in all_items if not p.image_url or not p.image_url.strip()]
    mixed_list = _mix_standard_and_fictional(with_images)
    mixed_list.extend(_mix_standard_and_fictional(without_images))

    total = len(mixed_list)
    start = (page - 1) * limit
    end = start + limit
    page_items = mixed_list[start:end]
    
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
        detected_country=geo["country_code"],
        currency=geo["currency"]
    )


def _mix_standard_and_fictional(items):
    """Return a deterministic nine-standard/one-fictional feed partition."""
    fictional = [product for product in items if product.is_fictional]
    standard = [product for product in items if not product.is_fictional]
    mixed = []
    fictional_index = standard_index = 0
    while standard_index < len(standard) or fictional_index < len(fictional):
        for _ in range(9):
            if standard_index < len(standard):
                mixed.append(standard[standard_index])
                standard_index += 1
        if fictional_index < len(fictional):
            mixed.append(fictional[fictional_index])
            fictional_index += 1
        if standard_index >= len(standard) and fictional_index < len(fictional):
            mixed.extend(fictional[fictional_index:])
            break
    return mixed


@router.get("/{id}", response_model=ProductBase)
def get_shopping_product_by_id(
    id: str,
    request: Request,
    country: Optional[str] = Query(None, min_length=2, max_length=2, pattern=r"^[A-Za-z]{2}$"),
    db: Session = Depends(get_db)
):
    geo = detect_country_from_request(request, override_country=country)
    geo = resolve_geo_currency(db, geo)
    rate = get_exchange_rate(db, geo["currency"])
    
    p = db.query(ProductModel).filter(ProductModel.id == id, ProductModel.type == "shopping", ProductModel.is_active.is_(True)).first()
    if not p:
        raise HTTPException(status_code=404, detail="Product not found")
        
    return localize_product_pricing(product_payload(p), geo["currency"], rate, geo["symbol"])
