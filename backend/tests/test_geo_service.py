from unittest.mock import patch

from starlette.requests import Request

from backend.app.services import geo_service


def _request(client_host="8.8.8.8", headers=None):
    raw_headers = [
        (key.lower().encode("latin-1"), value.encode("latin-1"))
        for key, value in (headers or {}).items()
    ]
    return Request(
        {
            "type": "http",
            "method": "GET",
            "scheme": "http",
            "path": "/bootstrap",
            "raw_path": b"/bootstrap",
            "query_string": b"",
            "headers": raw_headers,
            "client": (client_host, 12345),
            "server": ("testserver", 80),
        }
    )


def test_extract_client_ip_uses_direct_public_address():
    assert geo_service.extract_client_ip({}, "8.8.8.8", False) == "8.8.8.8"


def test_extract_client_ip_accepts_public_ipv6_address():
    address = "2606:4700:4700::1111"
    assert geo_service.extract_client_ip({}, address, False) == address


def test_extract_client_ip_accepts_trusted_forwarded_ipv6_address():
    address = "2606:4700:4700::1111"
    headers = {"x-forwarded-for": f"{address}, ::1"}
    assert geo_service.extract_client_ip(headers, "127.0.0.1", True) == address


def test_extract_client_ip_rejects_non_public_and_invalid_addresses():
    for candidate in (
        "127.0.0.1",
        "10.0.0.2",
        "192.0.2.1",
        "224.0.0.1",
        "::1",
        "2001:db8::1",
        "not-an-ip",
        "",
    ):
        assert geo_service.extract_client_ip({}, candidate, False) is None


def test_extract_client_ip_uses_leftmost_forwarded_address_when_trusted():
    headers = {"x-forwarded-for": "1.1.1.1, 10.0.0.2"}
    assert geo_service.extract_client_ip(headers, "192.168.1.2", True) == "1.1.1.1"


def test_extract_client_ip_ignores_forwarded_address_when_untrusted():
    headers = {"x-forwarded-for": "1.1.1.1"}
    assert geo_service.extract_client_ip(headers, "8.8.8.8", False) == "8.8.8.8"


def test_detect_country_supports_country_outside_manual_override_list():
    request = _request()
    with patch.object(geo_service.geoip_country_database, "lookup", return_value=("LK", "Sri Lanka")):
        detected = geo_service.detect_country_from_request(request)

    assert detected == {
        "country_code": "LK",
        "country_name": "Sri Lanka",
        "currency": "LKR",
        "symbol": "LKR",
    }


def test_detect_country_preserves_existing_currency_mapping():
    request = _request()
    with patch.object(geo_service.geoip_country_database, "lookup", return_value=("IN", "India")):
        detected = geo_service.detect_country_from_request(request)

    assert detected["country_code"] == "IN"
    assert detected["currency"] == "INR"
    assert detected["symbol"] == "₹"


def test_detect_country_falls_back_to_united_states_when_database_is_missing():
    request = _request()
    with patch.object(geo_service.geoip_country_database, "lookup", return_value=None):
        detected = geo_service.detect_country_from_request(request)

    assert detected == geo_service.FALLBACK_COUNTRY


def test_private_client_ip_does_not_reach_database():
    request = _request(client_host="127.0.0.1")
    with patch.object(geo_service.geoip_country_database, "lookup") as lookup:
        detected = geo_service.detect_country_from_request(request)

    lookup.assert_not_called()
    assert detected == geo_service.FALLBACK_COUNTRY


def test_missing_and_corrupt_database_fail_closed(tmp_path):
    missing = geo_service.GeoIPCountryDatabase(str(tmp_path / "missing.mmdb"))
    assert missing.lookup("8.8.8.8") is None

    corrupt_path = tmp_path / "corrupt.mmdb"
    corrupt_path.write_bytes(b"not a MaxMind database")
    corrupt = geo_service.GeoIPCountryDatabase(str(corrupt_path))
    assert corrupt.lookup("8.8.8.8") is None
