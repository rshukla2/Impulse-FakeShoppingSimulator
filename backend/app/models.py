from sqlalchemy import Column, String, Float, Integer, Boolean, DateTime, Text, ForeignKey, UniqueConstraint
from sqlalchemy.sql import func
from backend.app.database import Base

class ProductModel(Base):
    __tablename__ = "products"

    id = Column(String(64), primary_key=True, index=True)
    type = Column(String(32), index=True, nullable=False) # 'shopping', 'grocery', 'food'
    name = Column(String(255), index=True, nullable=False)
    brand = Column(String(255), nullable=True)
    category = Column(String(128), index=True, nullable=False)
    cuisine = Column(String(128), index=True, nullable=True) # for food
    description = Column(Text, nullable=True)
    image_url = Column(String(512), nullable=True)
    source = Column(String(64), nullable=False) # 'fictional', 'icecat', 'openfoodfacts', 'wikidata'
    source_id = Column(String(128), nullable=True)
    
    base_price_usd = Column(Float, nullable=False)
    original_price_usd = Column(Float, nullable=True)
    
    rating = Column(Float, default=4.5)
    review_count = Column(Integer, default=100)
    is_fictional = Column(Boolean, default=False, index=True)
    
    country_code = Column(String(10), index=True, nullable=True) # ISO country code if region-specific
    restaurant_id = Column(String(64), ForeignKey("restaurants.id"), nullable=True)
    
    image_license = Column(String(128), nullable=True)
    image_attribution = Column(String(512), nullable=True)
    image_license_url = Column(String(512), nullable=True)
    source_url = Column(String(1024), nullable=True)
    image_source_url = Column(String(1024), nullable=True)
    source_updated_at = Column(DateTime(timezone=True), nullable=True)
    is_active = Column(Boolean, nullable=False, default=True, index=True)
    
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())


class RestaurantModel(Base):
    __tablename__ = "restaurants"

    id = Column(String(64), primary_key=True, index=True)
    name = Column(String(255), nullable=False)
    cuisine = Column(String(128), index=True, nullable=False)
    tagline = Column(String(255), nullable=True)
    image_url = Column(String(512), nullable=True)
    rating = Column(Float, default=4.8)
    review_count = Column(Integer, default=1200)
    country_relevance = Column(String(64), nullable=True) # e.g. "IN,GLOBAL" or "JP,GLOBAL"
    price_level = Column(String(10), default="$$")
    
    created_at = Column(DateTime(timezone=True), server_default=func.now())


class ExchangeRateModel(Base):
    __tablename__ = "exchange_rates"

    currency = Column(String(10), primary_key=True)
    rate_to_usd = Column(Float, nullable=False) # 1 USD = rate units of currency
    symbol = Column(String(10), nullable=True)
    name = Column(String(64), nullable=True)
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())


class CatalogSyncRunModel(Base):
    __tablename__ = "catalog_sync_runs"

    id = Column(Integer, primary_key=True, autoincrement=True)
    source = Column(String(64), nullable=False, index=True)
    scope = Column(String(32), nullable=True, index=True)
    status = Column(String(24), nullable=False, index=True)
    records_seen = Column(Integer, nullable=False, default=0)
    records_written = Column(Integer, nullable=False, default=0)
    error_code = Column(String(64), nullable=True)
    error_message = Column(String(512), nullable=True)
    started_at = Column(DateTime(timezone=True), nullable=False, server_default=func.now())
    finished_at = Column(DateTime(timezone=True), nullable=True)


class CatalogCountrySyncModel(Base):
    __tablename__ = "catalog_country_sync"
    __table_args__ = (UniqueConstraint("source", "country_code", name="uq_catalog_country_source"),)

    id = Column(Integer, primary_key=True, autoincrement=True)
    source = Column(String(64), nullable=False, index=True)
    country_code = Column(String(2), nullable=False, index=True)
    status = Column(String(24), nullable=False, default="never")
    product_count = Column(Integer, nullable=False, default=0)
    last_attempt_at = Column(DateTime(timezone=True), nullable=True)
    last_success_at = Column(DateTime(timezone=True), nullable=True)
    error_code = Column(String(64), nullable=True)
