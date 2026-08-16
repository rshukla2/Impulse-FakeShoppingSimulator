from fastapi import APIRouter, Depends, Request, Query, HTTPException
from sqlalchemy.orm import Session
from typing import Optional, List

from backend.app.database import get_db
from backend.app.models import RestaurantModel, ProductModel
from backend.app.schemas import RestaurantListResponse, RestaurantBase, ProductBase
from backend.app.services.geo_service import detect_country_from_request
from backend.app.services.currency_service import get_exchange_rate, resolve_geo_currency
from backend.app.services.pricing_service import localize_product_pricing
from backend.app.services.product_service import product_payload

router = APIRouter(prefix="/restaurants", tags=["restaurants"])

@router.get("", response_model=RestaurantListResponse)
def get_restaurants(
    request: Request,
    country: Optional[str] = Query(None, min_length=2, max_length=2, pattern=r"^[A-Za-z]{2}$"),
    cuisine: Optional[str] = Query(None, max_length=128),
    db: Session = Depends(get_db)
):
    geo = detect_country_from_request(request, override_country=country)
    geo = resolve_geo_currency(db, geo)
    country_code = geo["country_code"]
    
    query = db.query(RestaurantModel)
    if cuisine and cuisine != "All":
        query = query.filter(RestaurantModel.cuisine.ilike(f"%{cuisine}%"))
        
    restaurants = query.all()
    
    # Sort restaurants: prioritize restaurants matching detected country relevance
    def score_restaurant(r):
        relevance = r.country_relevance or ""
        if country_code in relevance:
            return 0
        elif "GLOBAL" in relevance:
            return 1
        return 2
        
    sorted_restaurants = sorted(restaurants, key=score_restaurant)
    
    result = []
    for r in sorted_restaurants:
        dish_count = db.query(ProductModel).filter(ProductModel.restaurant_id == r.id, ProductModel.is_active.is_(True)).count()
        result.append(RestaurantBase(
            id=r.id,
            name=r.name,
            cuisine=r.cuisine,
            tagline=r.tagline,
            image_url=r.image_url,
            rating=r.rating,
            review_count=r.review_count,
            price_level=r.price_level,
            dishes_count=dish_count
        ))
        
    return RestaurantListResponse(
        items=result,
        total=len(result),
        detected_country=country_code
    )


@router.get("/{id}", response_model=RestaurantBase)
def get_restaurant_by_id(
    id: str,
    request: Request,
    country: Optional[str] = Query(None, min_length=2, max_length=2, pattern=r"^[A-Za-z]{2}$"),
    db: Session = Depends(get_db)
):
    geo = detect_country_from_request(request, override_country=country)
    geo = resolve_geo_currency(db, geo)
    rate = get_exchange_rate(db, geo["currency"])
    
    r = db.query(RestaurantModel).filter(RestaurantModel.id == id).first()
    if not r:
        raise HTTPException(status_code=404, detail="Restaurant not found")
        
    dishes = db.query(ProductModel).filter(ProductModel.restaurant_id == r.id, ProductModel.is_active.is_(True)).order_by(ProductModel.id.asc()).all()
    
    localized_menu = [
        localize_product_pricing(product_payload(p), geo["currency"], rate, geo["symbol"])
        for p in dishes
    ]
    
    return RestaurantBase(
        id=r.id,
        name=r.name,
        cuisine=r.cuisine,
        tagline=r.tagline,
        image_url=r.image_url,
        rating=r.rating,
        review_count=r.review_count,
        price_level=r.price_level,
        dishes_count=len(dishes),
        menu=localized_menu
    )
