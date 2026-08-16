from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from backend.app.database import get_db
from backend.app.models import ProductModel
from backend.app.schemas import CategoriesResponse

router = APIRouter(prefix="/categories", tags=["categories"])

@router.get("", response_model=CategoriesResponse)
def get_all_categories(db: Session = Depends(get_db)):
    shopping_cats = (
        db.query(ProductModel.category)
        .filter(ProductModel.type == "shopping", ProductModel.is_active.is_(True))
        .distinct()
        .all()
    )
    
    grocery_cats = (
        db.query(ProductModel.category)
        .filter(ProductModel.type == "grocery", ProductModel.is_active.is_(True))
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
        grocery_categories=["All"] + sorted([c[0] for c in grocery_cats if c[0]]),
        food_cuisines=["All"] + sorted([c[0] for c in food_cuisines if c[0]])
    )
