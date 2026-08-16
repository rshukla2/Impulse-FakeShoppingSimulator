# Impulse — Fake Shopping Simulator

Impulse is a Flutter application for simulated shopping. Users browse food,
groceries, general products, and fictional products, place local fake orders,
and see how much they avoided spending. There are no accounts, payments,
addresses, or deliveries.

## Supported architecture

This repository has one frontend and one backend:

```text
Flutter app (mobile/)
├── iOS
├── Android
└── Flutter web
        │
        │ REST
        ▼
FastAPI backend (backend/)
        │
        ├── SQLite
        ├── local GeoLite2 Country lookup
        └── cached Icecat, Open Food Facts, Wikidata/Commons, and Frankfurter data
```

The intended production topology is Flutter web on GitHub Pages calling a
FastAPI service on a DigitalOcean droplet over HTTPS. nginx and systemd will be
configured in a later deployment phase; they are not active in this phase.

## Repository layout

```text
mobile/   Flutter application for iOS, Android, and web
backend/  FastAPI application and SQLite models
data/     Catalog seed data and the preserved AI Studio catalog
scripts/  Catalog, exchange-rate, and GeoLite maintenance commands
docs/     Architecture, API, licenses, and future deployment notes
```

`data/google-ai-studio-catalog.json` remains an immutable snapshot of the
original prototype. Its non-fictional records provide permanent realistic seed
fallbacks. The editable fictional catalog lives only in
`data/fictional-products.json` and currently contains 34 unique products.

## Run the backend locally

From the repository root:

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r backend/requirements.txt
cp .env.example .env
uvicorn backend.app.main:app --reload --no-access-log --host 127.0.0.1 --port 8000
```

The backend falls back to United States/USD when the GeoLite database is
missing or the request comes from a private/local IP.

### Install or update GeoLite2 Country

The already-downloaded archive can be installed without credentials:

```bash
python scripts/update_geoip_database.py \
  --archive /Users/rishi/Downloads/GeoLite2-Country_20260814.tar.gz
```

For later downloads, set MaxMind credentials in `.env` and run:

```bash
python scripts/update_geoip_database.py
```

The installer rejects unsafe archives, validates the MMDB, and atomically installs it at
`data/GeoLite2-Country.mmdb` by default. MMDB files and credentials are ignored
by Git. Automatic production updates are deferred to the deployment phase.

## Populate or refresh the backend cache

Open `.env`, paste `ICECAT_API_ACCESS_TOKEN` and the recommended
`ICECAT_CONTENT_ACCESS_TOKEN`, then run the complete maintenance workflow:

```bash
python scripts/sync_all.py
```

The API never waits for this command. It remains available from SQLite if a
provider is unavailable. Useful targeted checks include:

```bash
python scripts/sync_all.py --source frankfurter
python scripts/sync_all.py --source openfoodfacts --country IN
python scripts/sync_all.py --source wikidata --dry-run
python scripts/sync_all.py --source icecat --dry-run
```

`--dry-run` fetches and validates provider results without changing live cache
records. Open Food Facts starts with 15 configured countries; an unconfigured
country detected later is queued once and cached without storing its user's IP.

## Run Flutter locally

```bash
cd mobile
flutter pub get
flutter run -d chrome
```

Default development backend URLs are:

- Flutter web: `http://localhost:8000`
- iOS Simulator: `http://127.0.0.1:8000`
- Android Emulator: `http://10.0.2.2:8000`

For a physical device or another backend, provide a reachable URL:

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8000
```

Production builds must use an HTTPS API URL.

## Publish Flutter web to GitHub Pages

The repository includes `.github/workflows/deploy-pages.yml`. After the files
are committed and pushed to `main`:

1. In GitHub, open **Settings → Pages** and select **GitHub Actions** as the
   source.
2. Optionally create the repository Actions variable `API_BASE_URL` with the
   final HTTPS FastAPI URL, for example `https://api.example.com`.
3. Push to `main`, or run **Deploy Flutter web to GitHub Pages** manually from
   the Actions tab.

Until `API_BASE_URL` is configured, the workflow intentionally publishes a
deployment-preview build. Login, Home, and navigation can be tested, while the
app clearly explains that live catalogs will become available after the
DigitalOcean API is deployed. Setting the variable and rerunning the workflow
turns preview mode off; no source-code edit is required.

The workflow builds with the repository subpath automatically, so the project
Pages URL is expected to be:

```text
https://rshukla2.github.io/Impulse-FakeShoppingSimulator/
```

## Checks

```bash
python scripts/verify_preserved_catalog.py
python -m pytest backend/tests

cd mobile
flutter analyze
flutter test
flutter build web
```

Android builds require the Android SDK. iOS builds require full Xcode and
CocoaPods.

## Privacy boundary

The entered display name, Login completion, cart, orders, and savings remain in
Flutter local storage. The display name is not sent to FastAPI. The backend may
process a public request IP in memory solely to perform a local country lookup;
the application does not persist or log that IP. Run Uvicorn with access
logging disabled as shown above so the server does not independently emit raw
connection addresses.
