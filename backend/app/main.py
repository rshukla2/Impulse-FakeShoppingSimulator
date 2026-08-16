from fastapi import Depends, FastAPI
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager

from backend.app.config import settings
from backend.app.database import SessionLocal, get_db, migrate_database
from backend.app.models import CatalogSyncRunModel, ProductModel
from backend.app.services.seed_service import seed_database_if_empty
from backend.app.services.geo_service import close_geoip_database
from backend.app.routers import bootstrap, shopping, groceries, food, restaurants, categories, search

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup is deliberately offline: migrate and import local seeds only.
    migrate_database()
    db = SessionLocal()
    try:
        seed_database_if_empty(db)
    finally:
        db.close()
    try:
        yield
    finally:
        close_geoip_database()

app = FastAPI(
    title="Impulse API",
    description="Fake Shopping Simulator Backend API",
    version="1.0.0",
    lifespan=lifespan
)

# Enable CORS for Flutter mobile web / local dev clients
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_allowed_origins,
    allow_origin_regex=settings.CORS_ALLOWED_ORIGIN_REGEX,
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/health", tags=["system"])
def health_check(db=Depends(get_db)):
    providers = {}
    for source in ("frankfurter", "icecat", "openfoodfacts", "wikidata"):
        latest = (
            db.query(CatalogSyncRunModel)
            .filter(CatalogSyncRunModel.source == source)
            .order_by(CatalogSyncRunModel.started_at.desc())
            .first()
        )
        last_success = (
            db.query(CatalogSyncRunModel)
            .filter(CatalogSyncRunModel.source == source, CatalogSyncRunModel.status == "success")
            .order_by(CatalogSyncRunModel.finished_at.desc())
            .first()
        )
        providers[source] = {
            "status": latest.status if latest else "never",
            "last_success_at": last_success.finished_at.isoformat() if last_success and last_success.finished_at else None,
            "records_written": latest.records_written if latest else 0,
            "configured": bool(settings.ICECAT_API_ACCESS_TOKEN) if source == "icecat" else True,
        }
    counts = {
        catalog_type: db.query(ProductModel).filter(ProductModel.type == catalog_type, ProductModel.is_active.is_(True)).count()
        for catalog_type in ("shopping", "grocery", "food")
    }
    return {
        "status": "healthy",
        "database": "ok",
        "service": "Impulse Backend",
        "mode": "simulated_shopping_only",
        "payment_integrated": False,
        "privacy": "no_pii_stored",
        "catalog_counts": counts,
        "providers": providers,
    }

# Include all required API routers
app.include_router(bootstrap.router)
app.include_router(shopping.router)
app.include_router(groceries.router)
app.include_router(food.router)
app.include_router(restaurants.router)
app.include_router(categories.router)
app.include_router(search.router)
