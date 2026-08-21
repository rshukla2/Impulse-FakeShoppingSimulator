# Impulse Architecture

## Canonical system

```text
GitHub repository
├── Flutter app
│   ├── iOS
│   ├── Android
│   └── Flutter web
└── FastAPI backend
    ├── SQLite
    ├── local GeoLite2 Country database
    └── synchronized external catalog/data sources
```

Flutter is the only client and FastAPI is the only server.

## Client responsibilities

Flutter owns all user-specific state:

- name-only Login completion
- display name
- combined cart
- simulated order history
- lifetime savings and item counts
- optional masked card profiles and shipping/billing addresses
- encrypted checkout snapshots for completed simulated orders

SharedPreferences persists non-sensitive application state on each device.
Checkout profiles and snapshots use platform secure storage: Keychain on iOS,
Keystore-backed encryption on Android, and WebCrypto on HTTPS Flutter web. Full
card numbers are never persisted, and checkout information is not part of
backend requests. The same Dart UI and state model serve iOS, Android, and
Flutter web.

The backend URL is supplied at compile time through `API_BASE_URL`. Safe local
defaults exist for browser and emulator development; production must inject an
HTTPS URL.

## Backend responsibilities

FastAPI provides the normalized, read-only catalog API and stores catalog data,
exchange-rate cache data, provider status, country cache state, provenance, and
image attribution in SQLite. It stores no user, cart, order, or raw-IP records.

Country detection follows this flow:

```text
Request
  → direct client address, or trusted nginx forwarding header
  → public IPv4/IPv6 validation
  → local GeoLite2 Country MMDB lookup
  → ISO country code/name
  → CLDR country/currency metadata plus cached Frankfurter rate
  → /bootstrap response
```

Forwarding headers are ignored unless `TRUST_PROXY_HEADERS=true`. The production
nginx configuration overwrites forwarded headers and Uvicorn remains
bound to loopback with raw-IP access logging disabled or suitably redacted. Raw
IP addresses are neither stored nor included in application log messages.

The automatic detector and compatibility override support ISO countries beyond
the original 12-country list. A currency unsupported by the cached rate source
uses USD as the final fallback.

## Catalog synchronization

```text
Icecat ───────────────┐
Open Food Facts ──────┤
Wikidata + Commons ───┼─→ normalize → transactional SQLite cache → REST API
Frankfurter ──────────┘
```

API startup performs additive schema migration and local seed import only. The
external providers are refreshed through `scripts/sync_all.py`; failed or empty
refreshes retain the last usable cache. Production refreshes are scheduled
maintenance jobs rather than user-triggered work. Provider requests use bounded
retries, throttling, timeouts, and identifiable User-Agent headers.

## Catalog reference data

`data/reference-catalog.json` contains 21 checksum-protected product records
and five restaurant records. Realistic products and restaurant templates are
imported as stable seed fallbacks. Fictional products are maintained separately
in `data/fictional-products.json`.

## Production deployment assets

```text
Flutter web
  → GitHub Pages
  → HTTPS
  → DigitalOcean droplet
  → nginx reverse proxy
  → systemd
  → FastAPI + Uvicorn on 127.0.0.1
  → SQLite and external catalog/data sources
```

iOS and Android use the same HTTPS FastAPI endpoint. GitHub Actions, nginx,
systemd services/timers, SQLite backup, and short-lived Let's Encrypt IP
certificate automation are implemented as repository configuration. They take
effect only after an operator provisions GitHub Pages and the DigitalOcean
Droplet; no cloud resource is created from a developer machine.
