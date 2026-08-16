from pydantic import BaseModel, ConfigDict, Field
from typing import Optional, List

class ProductBase(BaseModel):
    id: str
    type: str # shopping, grocery, food
    name: str
    brand: Optional[str] = None
    category: str
    cuisine: Optional[str] = None
    description: Optional[str] = None
    image_url: Optional[str] = None
    source: str
    source_id: Optional[str] = None
    
    base_price_usd: float
    original_price_usd: Optional[float] = None
    
    # Calculated / localized fields
    display_price: float
    original_display_price: Optional[float] = None
    formatted_price: str
    formatted_original_price: Optional[str] = None
    currency: str
    currency_symbol: str
    
    rating: float = 4.5
    review_count: int = 100
    is_fictional: bool = False
    
    restaurant_id: Optional[str] = None
    restaurant_name: Optional[str] = None
    
    image_license: Optional[str] = None
    image_attribution: Optional[str] = None
    image_license_url: Optional[str] = None
    source_url: Optional[str] = None
    image_source_url: Optional[str] = None

    model_config = ConfigDict(from_attributes=True)


class ProductListResponse(BaseModel):
    items: List[ProductBase]
    total: int
    page: int
    limit: int
    has_more: bool
    detected_country: str
    currency: str


class RestaurantBase(BaseModel):
    id: str
    name: str
    cuisine: str
    tagline: Optional[str] = None
    image_url: Optional[str] = None
    rating: float
    review_count: int
    price_level: str
    dishes_count: int = 0
    menu: Optional[List[ProductBase]] = None

    model_config = ConfigDict(from_attributes=True)


class RestaurantListResponse(BaseModel):
    items: List[RestaurantBase]
    total: int
    detected_country: str


class BootstrapResponse(BaseModel):
    country_code: str
    country_name: str
    currency: str
    currency_symbol: str
    exchange_rate: float
    supported_countries: List[dict]


class CategoriesResponse(BaseModel):
    shopping_categories: List[str]
    grocery_categories: List[str]
    food_cuisines: List[str]


class SearchResponse(BaseModel):
    query: str
    shopping: List[ProductBase]
    groceries: List[ProductBase]
    food: List[ProductBase]
    restaurants: List[RestaurantBase]
