from fastapi import APIRouter, Depends, Request, Query
from sqlalchemy.orm import Session
from sqlalchemy import or_
from typing import Optional

from backend.app.database import get_db
from backend.app.models import ProductModel, RestaurantModel
from backend.app.schemas import SearchResponse, RestaurantBase
from backend.app.services.geo_service import detect_country_from_request
from backend.app.services.currency_service import get_exchange_rate, resolve_geo_currency
from backend.app.services.pricing_service import localize_product_pricing
from backend.app.services.product_service import product_payload

router = APIRouter(prefix="/search", tags=["search"])

@router.get("", response_model=SearchResponse)
def search_all_catalogs(
    request: Request,
    q: str = Query(..., min_length=1, max_length=100),
    country: Optional[str] = Query(None, min_length=2, max_length=2, pattern=r"^[A-Za-z]{2}$"),
    db: Session = Depends(get_db)
):
    geo = detect_country_from_request(request, override_country=country)
    geo = resolve_geo_currency(db, geo)
    rate = get_exchange_rate(db, geo["currency"])
    
    search_fmt = f"%{q.strip()}%"
    
    # 1. Search shopping
    shopping_items = db.query(ProductModel).filter(
        ProductModel.type == "shopping",
        ProductModel.is_active.is_(True),
        or_(
            ProductModel.name.ilike(search_fmt),
            ProductModel.description.ilike(search_fmt),
            ProductModel.brand.ilike(search_fmt),
            ProductModel.category.ilike(search_fmt)
        )
    ).limit(10).all()
    
    # 2. Search groceries
    grocery_items = db.query(ProductModel).filter(
        ProductModel.type == "grocery",
        ProductModel.is_active.is_(True),
        or_(ProductModel.country_code == geo["country_code"], ProductModel.country_code.is_(None)),
        or_(
            ProductModel.name.ilike(search_fmt),
            ProductModel.description.ilike(search_fmt),
            ProductModel.brand.ilike(search_fmt),
            ProductModel.category.ilike(search_fmt)
        )
    ).limit(10).all()
    
    # 3. Search food dishes
    food_items = db.query(ProductModel).filter(
        ProductModel.type == "food",
        ProductModel.is_active.is_(True),
        or_(
            ProductModel.name.ilike(search_fmt),
            ProductModel.description.ilike(search_fmt),
            ProductModel.brand.ilike(search_fmt),
            ProductModel.cuisine.ilike(search_fmt)
        )
    ).limit(10).all()
    
    # 4. Search restaurants
    restaurants = db.query(RestaurantModel).filter(
        or_(
            RestaurantModel.name.ilike(search_fmt),
            RestaurantModel.cuisine.ilike(search_fmt),
            RestaurantModel.tagline.ilike(search_fmt)
        )
    ).limit(5).all()
    
    def localize(p):
        return localize_product_pricing(product_payload(p), geo["currency"], rate, geo["symbol"])

    restaurant_bases = [
        RestaurantBase(
            id=r.id,
            name=r.name,
            cuisine=r.cuisine,
            tagline=r.tagline,
            image_url=r.image_url,
            rating=r.rating,
            review_count=r.review_count,
            price_level=r.price_level,
            dishes_count=db.query(ProductModel).filter(ProductModel.restaurant_id == r.id, ProductModel.is_active.is_(True)).count()
        )
        for r in restaurants
    ]

    return SearchResponse(
        query=q,
        shopping=[localize(p) for p in shopping_items],
        groceries=[localize(p) for p in grocery_items],
        food=[localize(p) for p in food_items],
        restaurants=restaurant_bases
    )
