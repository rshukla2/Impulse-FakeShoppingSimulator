import pytest
from pydantic import ValidationError

from backend.app.config import Settings


def test_production_configuration_rejects_debug_mode():
    with pytest.raises(ValidationError, match="IMPULSE_DEBUG must be false"):
        Settings(_env_file=None, ENVIRONMENT="production", IMPULSE_DEBUG=True)


def test_production_configuration_rejects_wildcard_cors():
    with pytest.raises(ValidationError, match="Wildcard CORS"):
        Settings(
            _env_file=None,
            ENVIRONMENT="production",
            IMPULSE_DEBUG=False,
            CORS_ALLOWED_ORIGINS="*",
        )


def test_production_configuration_accepts_exact_pages_origin():
    configured = Settings(
        _env_file=None,
        ENVIRONMENT="production",
        IMPULSE_DEBUG=False,
        CORS_ALLOWED_ORIGINS="https://rshukla2.github.io",
        CORS_ALLOWED_ORIGIN_REGEX="",
    )
    assert configured.cors_allowed_origins == ["https://rshukla2.github.io"]
    assert configured.CORS_ALLOWED_ORIGIN_REGEX is None


def test_production_configuration_rejects_user_triggered_provider_sync():
    with pytest.raises(ValidationError, match="ENABLE_LAZY_COUNTRY_SYNC"):
        Settings(
            _env_file=None,
            ENVIRONMENT="production",
            IMPULSE_DEBUG=False,
            ENABLE_LAZY_COUNTRY_SYNC=True,
        )
