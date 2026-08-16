from fastapi import APIRouter, Depends, Request, Query, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import or_
from typing import Optional, List

from backend.app.database import get_db
from backend.app.models import ProductModel, RestaurantModel
from backend.app.schemas import ProductListResponse, ProductBase
from backend.app.services.geo_service import detect_country_from_request
from backend.app.services.currency_service import get_exchange_rate, resolve_geo_currency
from backend.app.services.pricing_service import localize_product_pricing
from backend.app.services.product_service import product_payload

router = APIRouter(prefix="/food", tags=["food"])

@router.get("", response_model=ProductListResponse)
def get_food_dishes(
    request: Request,
    country: Optional[str] = Query(None, min_length=2, max_length=2, pattern=r"^[A-Za-z]{2}$"),
    category: Optional[str] = Query(None, max_length=128),
    cuisine: Optional[str] = Query(None, max_length=128),
    restaurant_id: Optional[str] = Query(None, max_length=64),
    search: Optional[str] = Query(None, max_length=100),
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
    db: Session = Depends(get_db)
):
    geo = detect_country_from_request(request, override_country=country)
    geo = resolve_geo_currency(db, geo)
    rate = get_exchange_rate(db, geo["currency"])
    country_code = geo["country_code"]
    
    query = db.query(ProductModel).filter(ProductModel.type == "food", ProductModel.is_active.is_(True))
    
    if restaurant_id:
        query = query.filter(ProductModel.restaurant_id == restaurant_id)
        
    if category and category != "All":
        query = query.filter(ProductModel.category == category)
        
    if cuisine and cuisine != "All":
        query = query.filter(ProductModel.cuisine.ilike(f"%{cuisine}%"))
        
    if search:
        search_fmt = f"%{search.strip()}%"
        query = query.filter(
            or_(
                ProductModel.name.ilike(search_fmt),
                ProductModel.description.ilike(search_fmt),
                ProductModel.brand.ilike(search_fmt),
                ProductModel.cuisine.ilike(search_fmt)
            )
        )

    all_dishes = query.order_by(ProductModel.id.asc()).all()
    relevance_by_restaurant = {
        restaurant.id: {part.strip().upper() for part in (restaurant.country_relevance or "").split(",")}
        for restaurant in db.query(RestaurantModel).all()
    }
    
    def score_dish(dish):
        if dish.country_code == country_code:
            return (0, dish.id)
        relevance = relevance_by_restaurant.get(dish.restaurant_id, set())
        if country_code in relevance:
            return (1, dish.id)
        if "GLOBAL" in relevance:
            return (2, dish.id)
        return (3, dish.id)

    ranked_dishes = sorted(all_dishes, key=score_dish)
    
    total = len(ranked_dishes)
    start = (page - 1) * limit
    end = start + limit
    page_items = ranked_dishes[start:end]
    
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
def get_food_dish_by_id(
    id: str,
    request: Request,
    country: Optional[str] = Query(None, min_length=2, max_length=2, pattern=r"^[A-Za-z]{2}$"),
    db: Session = Depends(get_db)
):
    geo = detect_country_from_request(request, override_country=country)
    geo = resolve_geo_currency(db, geo)
    rate = get_exchange_rate(db, geo["currency"])
    
    p = db.query(ProductModel).filter(ProductModel.id == id, ProductModel.type == "food", ProductModel.is_active.is_(True)).first()
    if not p:
        raise HTTPException(status_code=404, detail="Food dish not found")
        
    return localize_product_pricing(product_payload(p), geo["currency"], rate, geo["symbol"])
