from typing import Optional

from fastapi import APIRouter, Depends, Query, Request
from sqlalchemy import or_
from sqlalchemy.orm import Session

from backend.app.config import settings
from backend.app.database import get_db
from backend.app.models import ProductModel
from backend.app.schemas import CategoriesResponse
from backend.app.services.geo_service import detect_country_from_request
from backend.app.services.grocery_categories import GROCERY_CATEGORIES

router = APIRouter(prefix="/categories", tags=["categories"])


def grocery_categories_for_country(db: Session, country_code: str) -> list[str]:
    code = country_code.upper()
    has_country_cache = (
        db.query(ProductModel.id)
        .filter(
            ProductModel.type == "grocery",
            ProductModel.is_active.is_(True),
            ProductModel.country_code == code,
        )
        .first()
        is not None
    )
    scope = code if has_country_cache else settings.DEFAULT_COUNTRY_CODE
    rows = (
        db.query(ProductModel.category)
        .filter(
            ProductModel.type == "grocery",
            ProductModel.is_active.is_(True),
            or_(
                ProductModel.country_code == scope,
                ProductModel.country_code.is_(None),
            ),
        )
        .distinct()
        .all()
    )
    available = {row[0] for row in rows if row[0]}
    return ["All", *(category for category in GROCERY_CATEGORIES if category in available)]


@router.get("", response_model=CategoriesResponse)
def get_all_categories(
    request: Request,
    country: Optional[str] = Query(
        None,
        min_length=2,
        max_length=2,
        pattern=r"^[A-Za-z]{2}$",
    ),
    db: Session = Depends(get_db),
):
    geo = detect_country_from_request(request, override_country=country)
    shopping_cats = (
        db.query(ProductModel.category)
        .filter(ProductModel.type == "shopping", ProductModel.is_active.is_(True))
        .distinct()
        .all()
    )

    food_cuisines = (
        db.query(ProductModel.cuisine)
        .filter(ProductModel.type == "food", ProductModel.is_active.is_(True))
        .distinct()
        .all()
    )

    return CategoriesResponse(
        shopping_categories=["All"] + sorted([c[0] for c in shopping_cats if c[0]]),
        grocery_categories=grocery_categories_for_country(db, geo["country_code"]),
        food_cuisines=["All"] + sorted([c[0] for c in food_cuisines if c[0]]),
    )
