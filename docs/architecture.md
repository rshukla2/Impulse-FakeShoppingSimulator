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

There is no React, Vite, Node, Express, or Gemini application runtime. Flutter
is the only client and FastAPI is the only server.

## Client responsibilities

Flutter owns all user-specific state:

- name-only Login completion
- display name
- combined cart
- simulated order history
- lifetime savings and item counts

SharedPreferences persists this state on each device. The display name is not
part of backend requests. The same Dart UI and state model serve iOS, Android,
and Flutter web.

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

Forwarding headers are ignored unless `TRUST_PROXY_HEADERS=true`. The future
nginx configuration must overwrite forwarded headers and Uvicorn must remain
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
refreshes retain the last usable cache. Open Food Facts also has a persistent,
deduplicated lazy refresh for newly detected countries. Provider requests use
bounded retries, throttling, timeouts, and identifiable User-Agent headers.

## Catalog preservation

The original Google AI Studio catalog is preserved verbatim in
`data/google-ai-studio-catalog.json`: 21 products and five restaurants. Its
realistic products and restaurant templates are imported as stable seed
fallbacks. Fictional products are maintained separately. The two conflicting
archived fictional records use `fake_ai_004` and `fake_ai_005`, preserving the
32 existing IDs and both original variants.

## Target deployment (not implemented yet)

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

iOS and Android use the same HTTPS FastAPI endpoint. Live deployment, DNS,
certificates, GitHub Actions, nginx configuration, and systemd units are
explicitly deferred.
