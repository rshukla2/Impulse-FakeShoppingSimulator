import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from backend.app.database import Base, get_db
from backend.app.main import app
from backend.app.models import ProductModel
from backend.app.services.seed_service import seed_database_if_empty


@pytest.fixture(scope="module")
def client():
    # Route tests must prove a clean checkout works without relying on the
    # developer's ignored impulse.db cache.
    engine = create_engine(
        "sqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    test_session = sessionmaker(bind=engine)
    db = test_session()
    try:
        seed_database_if_empty(db)
    finally:
        db.close()

    def override_get_db():
        session = test_session()
        try:
            yield session
        finally:
            session.close()

    app.dependency_overrides[get_db] = override_get_db
    test_client = TestClient(app)
    try:
        yield test_client
    finally:
        test_client.close()
        app.dependency_overrides.clear()
        engine.dispose()


def test_health_endpoint(client):
    response = client.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "healthy"
    assert data["database"] == "ok"
    assert data["payment_integrated"] is False
    assert set(data["providers"]) == {"frankfurter", "icecat", "openfoodfacts", "wikidata"}
    assert "api_key" not in response.text.lower()


def test_clean_checkout_has_complete_tracked_seed_catalog(client):
    response = client.get("/health")
    assert response.json()["catalog_counts"] == {
        "shopping": 45,
        "grocery": 20,
        "food": 10,
    }

def test_cors_allows_flutter_web_localhost_random_port(client):
    response = client.options(
        "/bootstrap",
        headers={"Origin": "http://localhost:54321", "Access-Control-Request-Method": "GET"},
    )
    assert response.status_code == 200
    assert response.headers["access-control-allow-origin"] == "http://localhost:54321"


def test_catalog_query_validation_bounds_public_inputs(client):
    assert client.get("/shopping?limit=101").status_code == 422
    assert client.get("/shopping?country=INVALID").status_code == 422
    assert client.get(f"/search?q={'x' * 101}").status_code == 422

def test_bootstrap_endpoint_default(client):
    response = client.get("/bootstrap")
    assert response.status_code == 200
    data = response.json()
    assert "country_code" in data
    assert "currency" in data
    assert "exchange_rate" in data

def test_bootstrap_endpoint_country_override(client):
    response = client.get("/bootstrap?country=IN")
    assert response.status_code == 200
    data = response.json()
    assert data["country_code"] == "IN"
    assert data["currency"] == "INR"
    assert data["currency_symbol"] == "₹"

def test_bootstrap_supports_all_iso_countries(client):
    response = client.get("/bootstrap?country=LK")
    data = response.json()
    assert data["currency"] == "LKR"
    assert len(data["supported_countries"]) > 200

def test_shopping_endpoint_has_fictional_items(client):
    response = client.get("/shopping")
    assert response.status_code == 200
    data = response.json()
    assert "items" in data
    assert len(data["items"]) > 0
    # Verify at least one item is fictional
    fictional_count = sum(1 for item in data["items"] if item["is_fictional"])
    assert fictional_count > 0

def test_shopping_first_ten_use_nine_to_one_pattern(client):
    data = client.get("/shopping?limit=10").json()
    assert sum(1 for item in data["items"] if item["is_fictional"]) == 1

def test_groceries_country_prioritization(client):
    response_in = client.get("/groceries?country=IN")
    assert response_in.status_code == 200
    data_in = response_in.json()
    assert len(data_in["items"]) > 0
    assert data_in["currency"] == "INR"
    assert all("_us_" not in item["id"] for item in data_in["items"])

def test_restaurants_and_food(client):
    response = client.get("/restaurants")
    assert response.status_code == 200
    data = response.json()
    assert len(data["items"]) > 0
    
    first_rest_id = data["items"][0]["id"]
    rest_detail = client.get(f"/restaurants/{first_rest_id}")
    assert rest_detail.status_code == 200
    assert "menu" in rest_detail.json()

def test_search_all_catalogs(client):
    response = client.get("/search?q=ghee")
    assert response.status_code == 200
    data = response.json()
    assert "groceries" in data
