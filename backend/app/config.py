from pathlib import Path
from typing import List, Optional

from pydantic import field_validator, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    APP_NAME: str = "Impulse Backend"
    ENVIRONMENT: str = "development"
    # Avoid the generic DEBUG environment variable, which is commonly owned by
    # shells and build runners. Use IMPULSE_DEBUG when this flag is needed.
    IMPULSE_DEBUG: bool = True
    DATABASE_URL: str = "sqlite:///./impulse.db"
    SQLITE_BUSY_TIMEOUT_MS: int = 30000
    
    # External catalog sync configuration. Public read access to Open Food
    # Facts, Wikidata, Wikimedia Commons, and Frankfurter is keyless.
    ICECAT_API_ACCESS_TOKEN: Optional[str] = None
    ICECAT_CONTENT_ACCESS_TOKEN: Optional[str] = None
    ICECAT_INDEX_URL: str = "https://data.icecat.biz/export/freexml/EN/files.index.csv.gz"
    ICECAT_TARGET_PRODUCTS: int = 5000
    ICECAT_CANDIDATE_BUFFER_PERCENT: int = 20
    ICECAT_CONCURRENCY: int = 3
    FRANKFURTER_API_BASE: str = "https://api.frankfurter.dev/v2"
    OPENFOODFACTS_API_BASE: str = "https://world.openfoodfacts.org/api/v2"
    OPENFOODFACTS_COUNTRIES: str = "US,IN,GB,JP,DE,FR,CA,AU,MX,BR,SG,AE,LK,NP,BD"
    OPENFOODFACTS_PRODUCTS_PER_COUNTRY: int = 50
    OPENFOODFACTS_MIN_INTERVAL_SECONDS: float = 6.1
    ENABLE_LAZY_COUNTRY_SYNC: bool = False
    WIKIDATA_SPARQL_ENDPOINT: str = "https://query.wikidata.org/sparql"
    WIKIMEDIA_API_ENDPOINT: str = "https://commons.wikimedia.org/w/api.php"
    EXTERNAL_API_CONTACT: str = "https://github.com/rshukla2/Impulse-FakeShoppingSimulator"
    EXTERNAL_API_TIMEOUT_SECONDS: float = 30.0
    EXTERNAL_API_MAX_RETRIES: int = 3
    CORS_ALLOWED_ORIGINS: str = "http://localhost:3000,http://localhost:5000,http://localhost:8080,http://localhost:8081"
    CORS_ALLOWED_ORIGIN_REGEX: Optional[str] = r"https?://(localhost|127\.0\.0\.1)(:\d+)?"

    # Local, privacy-preserving country detection
    GEOIP_DATABASE_PATH: str = "data/GeoLite2-Country.mmdb"
    MAXMIND_ACCOUNT_ID: Optional[str] = None
    MAXMIND_LICENSE_KEY: Optional[str] = None
    TRUST_PROXY_HEADERS: bool = False
    
    # Default fallbacks
    DEFAULT_COUNTRY_CODE: str = "US"
    DEFAULT_COUNTRY_NAME: str = "United States"
    DEFAULT_CURRENCY: str = "USD"

    @field_validator(
        "ICECAT_API_ACCESS_TOKEN",
        "ICECAT_CONTENT_ACCESS_TOKEN",
        "MAXMIND_ACCOUNT_ID",
        "MAXMIND_LICENSE_KEY",
        "CORS_ALLOWED_ORIGIN_REGEX",
        mode="before",
    )
    @classmethod
    def blank_secret_is_none(cls, value):
        return None if value is None or str(value).strip() == "" else value

    @model_validator(mode="after")
    def validate_production_safety(self):
        if self.ENVIRONMENT.lower() == "production":
            if self.IMPULSE_DEBUG:
                raise ValueError("IMPULSE_DEBUG must be false in production")
            if "*" in self.cors_allowed_origins:
                raise ValueError("Wildcard CORS origins are not allowed in production")
            if self.ENABLE_LAZY_COUNTRY_SYNC:
                raise ValueError("ENABLE_LAZY_COUNTRY_SYNC must be false in production")
        return self

    @property
    def openfoodfacts_country_codes(self) -> List[str]:
        return sorted({part.strip().upper() for part in self.OPENFOODFACTS_COUNTRIES.split(",") if part.strip()})

    @property
    def cors_allowed_origins(self) -> List[str]:
        return [part.strip() for part in self.CORS_ALLOWED_ORIGINS.split(",") if part.strip()]

    @property
    def project_root(self) -> Path:
        return Path(__file__).resolve().parents[2]
    
settings = Settings()
