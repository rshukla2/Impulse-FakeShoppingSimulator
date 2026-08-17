"""Stable English category taxonomy for grocery products."""

from __future__ import annotations

import re
from typing import Iterable, Optional

from sqlalchemy.orm import Session

from backend.app.models import ProductModel


GROCERY_CATEGORIES = (
    "Beverages",
    "Breakfast & Cereal",
    "Dairy",
    "Bakery",
    "Snacks",
    "Pantry",
    "Condiments & Sauces",
    "Prepared Foods",
    "Frozen Foods",
    "Produce",
    "Meat & Seafood",
    "Sweets & Desserts",
    "Dietary Supplements",
)


_CATEGORY_RULES = (
    (
        "Dietary Supplements",
        ("supplement", "vitamin", "mineral", "protein powder"),
    ),
    (
        "Dairy",
        (
            "dairy",
            "dairies",
            "milk",
            "yogurt",
            "yoghurt",
            "cheese",
            "butter",
            "cream",
            "oat drink",
            "soy drink",
            "almond drink",
        ),
    ),
    (
        "Meat & Seafood",
        (
            "meat",
            "beef",
            "pork",
            "chicken",
            "poultry",
            "fish",
            "seafood",
            "tuna",
            "salmon",
            "sausage",
        ),
    ),
    (
        "Produce",
        (
            "fruit",
            "vegetable",
            "produce",
            "apple",
            "banana",
            "avocado",
            "potato",
            "tomato",
        ),
    ),
    ("Frozen Foods", ("frozen", "ice pop")),
    (
        "Breakfast & Cereal",
        ("breakfast", "cereal", "granola", "muesli", "oatmeal", "porridge"),
    ),
    ("Bakery", ("bakery", "bread", "bagel", "bun", "tortilla", "pastry")),
    (
        "Condiments & Sauces",
        (
            "condiment",
            "sauce",
            "ketchup",
            "mustard",
            "mayonnaise",
            "dressing",
            "spread",
            "jam",
            "syrup",
        ),
    ),
    (
        "Beverages",
        (
            "beverage",
            "drink",
            "water",
            "juice",
            "coffee",
            "tea",
            "soda",
            "cola",
            "lemonade",
        ),
    ),
    (
        "Sweets & Desserts",
        ("dessert", "candy", "chocolate", "sweet", "ice cream"),
    ),
    (
        "Snacks",
        (
            "snack",
            "biscuit",
            "cookie",
            "cracker",
            "chip",
            "crisp",
            "popcorn",
            "nut",
            "bar",
        ),
    ),
    (
        "Prepared Foods",
        ("prepared", "instant", "ready meal", "noodle", "soup", "pizza"),
    ),
    (
        "Pantry",
        (
            "pantry",
            "flour",
            "rice",
            "pasta",
            "grain",
            "oil",
            "spice",
            "seasoning",
            "canned",
        ),
    ),
)


def _searchable_text(values: Iterable[object]) -> str:
    combined = " ".join(str(value) for value in values if value).lower()
    return re.sub(r"[^a-z0-9]+", " ", combined).strip()


def english_category_tags(tags: Iterable[object]) -> list[str]:
    """Return readable values only from explicit Open Food Facts English tags."""
    result = []
    for value in tags:
        tag = str(value).strip()
        if tag.lower().startswith("en:"):
            result.append(tag[3:].replace("-", " "))
    return result


def canonical_grocery_category(
    *,
    name: Optional[str] = None,
    category: Optional[str] = None,
    brand: Optional[str] = None,
    description: Optional[str] = None,
    tags: Iterable[object] = (),
) -> str:
    """Map provider labels and product text into a compact English taxonomy."""
    english_tags = english_category_tags(tags)
    text = _searchable_text((category, *english_tags, name, brand, description))
    for canonical, keywords in _CATEGORY_RULES:
        if any(
            re.search(rf"\b{re.escape(keyword)}s?\b", text)
            for keyword in keywords
        ):
            return canonical
    return "Pantry"


def normalize_cached_grocery_categories(db: Session) -> int:
    """Converge existing cached and seed groceries without refetching providers."""
    changed = 0
    products = db.query(ProductModel).filter(ProductModel.type == "grocery").all()
    for product in products:
        category = canonical_grocery_category(
            name=product.name,
            category=product.category,
            brand=product.brand,
            description=product.description,
        )
        if product.category != category:
            product.category = category
            changed += 1
    if changed:
        db.commit()
    return changed
