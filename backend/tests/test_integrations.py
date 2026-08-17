import io
import sqlite3
import tarfile
from pathlib import Path
from unittest.mock import AsyncMock, patch

import httpx
import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from backend.app.database import Base, configure_sqlite_connection
from backend.app.config import settings
from backend.app.models import ProductModel
from backend.app.services.catalog_store import replace_source_products, sanitized_error
from backend.app.services.currency_service import normalize_frankfurter_rates, resolve_geo_currency
from backend.app.services.external_http import ExternalHTTPClient
from backend.app.services.geo_service import GeoIPCountryDatabase
from backend.app.services.icecat_service import (
    candidate_target_for,
    icecat_auth_headers,
    infer_category,
    normalize_icecat_xml,
    public_image_is_usable,
    sanitize_icecat_url,
    select_balanced_index_rows,
    sync_icecat_products,
)
from backend.app.services.openfoodfacts_service import fetch_openfoodfacts_country_products, normalize_openfoodfacts_product, should_queue_country_sync
from backend.app.services.pricing_rules import stable_catalog_values
from backend.app.services.wikidata_food_service import normalize_commons_page, parse_wikidata_bindings
from scripts.update_geoip_database import install_archive


@pytest.fixture()
def db():
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)
    session = sessionmaker(bind=engine)()
    try:
        yield session
    finally:
        session.close()


def _product(product_id, source="icecat"):
    return {
        "id": product_id, "type": "shopping", "name": product_id, "category": "Electronics",
        "source": source, "source_id": product_id, "base_price_usd": 10.0,
        "original_price_usd": 12.0, "rating": 4.5, "review_count": 100,
        "is_fictional": False,
    }


def test_failed_empty_replacement_keeps_existing_cache(db):
    db.add(ProductModel(**_product("existing")))
    db.commit()
    with pytest.raises(ValueError):
        replace_source_products(db, [], source="icecat", product_type="shopping")
    assert db.get(ProductModel, "existing").is_active is True


def test_successful_replacement_is_idempotent_and_marks_stale(db):
    db.add(ProductModel(**_product("old")))
    db.commit()
    assert replace_source_products(db, [_product("new")], source="icecat", product_type="shopping") == 1
    assert db.get(ProductModel, "old").is_active is False
    assert db.get(ProductModel, "new").is_active is True
    assert replace_source_products(db, [_product("new")], source="icecat", product_type="shopping") == 1
    assert db.query(ProductModel).count() == 2


def test_stable_simulated_values_are_repeatable():
    assert stable_catalog_values("Q123", "Food", "food") == stable_catalog_values("Q123", "Food", "food")
    assert stable_catalog_values("Q123", "Food", "food") != stable_catalog_values("Q124", "Food", "food")


def test_frankfurter_v2_normalization():
    payload = [{"date": "2026-08-14", "base": "USD", "quote": "EUR", "rate": 0.9}, {"base": "EUR", "quote": "GBP", "rate": 0.8}]
    assert normalize_frankfurter_rates(payload) == {"USD": 1.0, "EUR": 0.9}


def test_unsupported_currency_falls_back_coherently_to_usd(db):
    geo = {"country_code": "AQ", "country_name": "Antarctica", "currency": "XXX", "symbol": "¤"}
    resolved = resolve_geo_currency(db, geo)
    assert resolved["country_code"] == "AQ"
    assert resolved["currency"] == "USD" and resolved["symbol"] == "$"


def test_openfoodfacts_normalization_is_country_scoped():
    product = {"code": "1234567890123", "product_name": "Oat Drink", "brands": "Example", "categories_tags_en": ["en:beverages"], "image_front_url": "https://images.example/item.jpg"}
    us = normalize_openfoodfacts_product(product, "US")
    gb = normalize_openfoodfacts_product(product, "GB")
    assert us["id"] == "off_us_1234567890123"
    assert gb["id"] == "off_gb_1234567890123"
    assert normalize_openfoodfacts_product({**product, "image_front_url": None}, "US") is None
    assert normalize_openfoodfacts_product({**product, "categories_tags_en": []}, "US") is None


def test_country_refresh_is_deduplicated(db):
    assert should_queue_country_sync(db, "NZ") is True
    assert should_queue_country_sync(db, "NZ") is False


@pytest.mark.asyncio
async def test_openfoodfacts_uses_country_name_filter_and_required_fields():
    def handler(request):
        assert request.url.params["countries_tags_en"] == "united-kingdom"
        assert "image_front_url" in request.url.params["fields"]
        return httpx.Response(200, json={"products": [{
            "code": "1234567890123", "product_name": "Tea", "brands": "Example",
            "categories_tags_en": ["en:beverages"], "image_front_url": "https://images.example/tea.jpg",
        }]})
    client = httpx.AsyncClient(transport=httpx.MockTransport(handler))
    try:
        products = await fetch_openfoodfacts_country_products("GB", client=client)
    finally:
        await client.aclose()
    assert len(products) == 1 and products[0]["country_code"] == "GB"


@pytest.mark.asyncio
async def test_external_http_retries_throttling():
    calls = 0
    def handler(_request):
        nonlocal calls
        calls += 1
        return httpx.Response(429, headers={"Retry-After": "0"}) if calls == 1 else httpx.Response(200, json={"ok": True})
    client = httpx.AsyncClient(transport=httpx.MockTransport(handler))
    try:
        with patch("backend.app.services.external_http.asyncio.sleep", new=AsyncMock()):
            async with ExternalHTTPClient("test", client) as external:
                assert await external.get_json("https://example.test") == {"ok": True}
    finally:
        await client.aclose()
    assert calls == 2


def test_commons_license_allowlist_and_attribution_cleanup():
    page = {"imageinfo": [{"thumburl": "https://images.example/dish.jpg", "descriptionurl": "https://commons.example/file", "extmetadata": {
        "LicenseShortName": {"value": "CC BY-SA 4.0"}, "LicenseUrl": {"value": "https://creativecommons.org/licenses/by-sa/4.0/"},
        "Artist": {"value": "<a>User</a> &amp; photographer"},
    }}]}
    normalized = normalize_commons_page(page)
    assert normalized["image_license"] == "CC BY-SA 4.0"
    assert normalized["image_attribution"] == "User & photographer"
    page["imageinfo"][0]["extmetadata"]["LicenseShortName"]["value"] = "All Rights Reserved"
    assert normalize_commons_page(page) is None


def test_wikidata_binding_normalization():
    payload = {"results": {"bindings": [{
        "dish": {"value": "http://www.wikidata.org/entity/Q123"}, "dishLabel": {"value": "Example Dish"},
        "cuisineLabel": {"value": "Indian cuisine"}, "countryCode": {"value": "IN"},
        "image": {"value": "https://commons.wikimedia.org/wiki/Special:FilePath/Example_Dish.jpg"},
    }]}}
    result = parse_wikidata_bindings(payload)[0]
    assert result["qid"] == "Q123"
    assert result["country_code"] == "IN"
    assert result["commons_title"] == "File:Example Dish.jpg"


def test_icecat_xml_normalization_and_category():
    xml = b'<ICECAT-interface><Product ID="42" Name="Gaming Console" HighPic="https://images.example/42.jpg?content_token=secret&amp;width=900"><Supplier Name="Example"/><Category Name="Game consoles"/><ProductDescription LongDesc="A console"/></Product></ICECAT-interface>'
    result = normalize_icecat_xml(xml, {"product_id": "42", "model_name": "Gaming Console"})
    assert result["id"] == "icecat_42"
    assert result["category"] == "Gaming"
    assert result["image_url"] == "https://images.example/42.jpg?width=900"
    assert infer_category("Vacuum cleaner") == "Appliances"


def test_icecat_uses_access_token_headers_and_never_basic_auth():
    with patch(
        "backend.app.services.icecat_service.settings.ICECAT_API_ACCESS_TOKEN",
        "api-secret",
    ), patch(
        "backend.app.services.icecat_service.settings.ICECAT_CONTENT_ACCESS_TOKEN",
        "content-secret",
    ):
        assert icecat_auth_headers() == {"Api-Token": "api-secret"}
        assert icecat_auth_headers(include_content=True) == {
            "Api-Token": "api-secret",
            "Content-Token": "content-secret",
        }
    assert "Authorization" not in icecat_auth_headers.__doc__


def test_icecat_url_sanitizer_removes_all_token_parameter_spellings():
    url = "https://images.example/item.jpg?Content-Token=one&api_token=two&app_key=three&w=800"
    assert sanitize_icecat_url(url) == "https://images.example/item.jpg?w=800"


def test_icecat_selection_fills_target_when_categories_are_sparse():
    rows = ({"product_id": str(index), "model_name": f"Generic device {index}"} for index in range(20))
    selected = select_balanced_index_rows(rows, 10)
    assert len(selected) == 10
    assert len({row["product_id"] for row in selected}) == 10


def test_icecat_candidate_buffer_preserves_usable_target_semantics():
    assert candidate_target_for(5000, 20) == 6000
    assert candidate_target_for(10, 0) == 10
    with pytest.raises(ValueError, match="at least one"):
        candidate_target_for(0, 20)


@pytest.mark.asyncio
async def test_icecat_public_image_validation_requires_https_image_response():
    def handler(request):
        if request.url.path.endswith("/good.jpg"):
            return httpx.Response(200, headers={"Content-Type": "image/jpeg"})
        if request.url.path.endswith("/not-image.jpg"):
            return httpx.Response(200, headers={"Content-Type": "text/html"})
        return httpx.Response(404)

    client = httpx.AsyncClient(transport=httpx.MockTransport(handler))
    try:
        async with ExternalHTTPClient("icecat-image-test", client) as external:
            assert await public_image_is_usable(external, "https://images.test/good.jpg")
            assert not await public_image_is_usable(external, "https://images.test/not-image.jpg")
            assert not await public_image_is_usable(external, "https://images.test/missing.jpg")
            assert not await public_image_is_usable(external, "http://images.test/good.jpg")
    finally:
        await client.aclose()


@pytest.mark.asyncio
async def test_icecat_requires_credentials_without_exposing_values():
    with patch(
        "backend.app.services.icecat_service.settings.ICECAT_API_ACCESS_TOKEN",
        None,
    ), patch(
        "backend.app.services.icecat_service.settings.ICECAT_CONTENT_ACCESS_TOKEN",
        None,
    ):
        with pytest.raises(Exception, match="API access token is not configured") as caught:
            await sync_icecat_products()
    assert "api_key" not in str(caught.value).lower()


def test_geoip_archive_rejects_unsafe_members(tmp_path):
    archive = tmp_path / "unsafe.tar.gz"
    with tarfile.open(archive, "w:gz") as bundle:
        member = tarfile.TarInfo("../GeoLite2-Country.mmdb")
        member.size = 4
        bundle.addfile(member, io.BytesIO(b"nope"))
    with pytest.raises(RuntimeError, match="Unsafe archive member"):
        install_archive(archive, tmp_path / "installed.mmdb")


def test_installed_geolite_database_known_ip():
    database_path = Path(settings.GEOIP_DATABASE_PATH)
    if not database_path.is_file():
        pytest.skip("GeoLite2 Country is an operator-installed, Git-ignored runtime file")
    database = GeoIPCountryDatabase(str(database_path))
    assert database.lookup("8.8.8.8")[0] == "US"
    database.close()


def test_secret_redaction():
    code, message = sanitized_error(RuntimeError("api_key=secret123 token=abc"))
    assert code == "runtimeerror"
    assert "secret123" not in message and "abc" not in message


def test_sqlite_connections_enable_production_pragmas():
    connection = sqlite3.connect(":memory:")
    try:
        configure_sqlite_connection(connection)
        assert connection.execute("PRAGMA foreign_keys").fetchone()[0] == 1
        assert connection.execute("PRAGMA busy_timeout").fetchone()[0] == 30000
        assert connection.execute("PRAGMA synchronous").fetchone()[0] == 1
    finally:
        connection.close()
