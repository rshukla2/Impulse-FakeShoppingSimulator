# Impulse - Fake Shopping Simulator

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

The production topology is Flutter web on GitHub Pages calling a FastAPI
service on a DigitalOcean Droplet over HTTPS. The repository now includes the
nginx, systemd, short-lived IP-certificate, scheduled-sync, firewall, and
SQLite-backup assets needed to provision it; cloud resources are still created
manually by the operator.

The public privacy policy is available at
<https://rshukla2.github.io/Impulse-FakeShoppingSimulator/privacy-policy/>.

## Repository layout

```text
mobile/   Flutter application for iOS, Android, and web
backend/  FastAPI application and SQLite models
data/     Catalog seed data and the checksum-protected reference catalog
scripts/  Catalog, exchange-rate, and GeoLite maintenance commands
deploy/   nginx and systemd production configuration
docs/     Architecture, API, licenses, deployment, and operating notes
```

`data/reference-catalog.json` is a checksum-protected reference dataset. Its
non-fictional records provide permanent realistic seed fallbacks. The editable fictional catalog lives only in
`data/fictional-products.json` and currently contains 34 unique products.

## Run the backend locally

From the repository root:

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r backend/requirements-dev.txt
cp .env.example .env
python scripts/migrate_database.py
uvicorn backend.app.main:app --reload --no-access-log --host 127.0.0.1 --port 8000
```

A clean clone deterministically seeds 45 shopping items (34 fictional and 11
realistic), 20 groceries, 10 dishes, and six fictional restaurant templates.

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
by Git. Production installs the database under `/opt/impulse/storage` and uses
the included monthly updater timer.

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
records. Open Food Facts starts with 15 configured countries. Production keeps
`ENABLE_LAZY_COUNTRY_SYNC=false`, so users never trigger provider work; new
countries are added through a maintenance sync.

`ICECAT_TARGET_PRODUCTS` is the number of usable, unique Icecat records retained
in SQLite, not merely the number inspected from the provider index. The sync
uses `ICECAT_CANDIDATE_BUFFER_PERCENT` to compensate for incomplete index rows
and retains the previous cache if the usable target cannot be met. Public image
URLs are checked with bounded `ICECAT_IMAGE_VALIDATION_CONCURRENCY`; records
whose images are missing, non-HTTPS, or no longer return image content remain
available but rank after every product with a usable image.

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
2. Create the repository Actions variable `API_BASE_URL` with the final HTTPS
   FastAPI URL. For IPv6 this must use URL brackets, for example
   `https://[2604:a880:400:d1::1234:1]`.
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

## Deploy the backend to DigitalOcean

On a brand-new Ubuntu Droplet, set the raw public address without brackets.
Password-based SSH works; the setup installs Fail2ban for basic brute-force
protection. For IPv6, URL brackets are added only where a URL is required:

```bash
apt-get update
apt-get install -y git
git clone https://github.com/rshukla2/Impulse-FakeShoppingSimulator.git /opt/impulse
cd /opt/impulse
PUBLIC_IP='YOUR_RAW_IPV4_OR_IPV6'
PUBLIC_URL="https://[${PUBLIC_IP}]" # IPv6; use "https://${PUBLIC_IP}" for IPv4
sudo ./scripts/setup_server.sh "$PUBLIC_IP"
sudo cp deploy/production.env.example .env
sudo chmod 640 .env
sudo editor .env
sudo chown root:impulse .env
sudo ./scripts/deploy_backend.sh
sudo ./scripts/enable_https.sh "$PUBLIC_IP" CONTACT_EMAIL
curl --globoff --fail "$PUBLIC_URL/health"
```

Then run the initial cache jobs:

```bash
sudo systemctl start impulse-sync@frankfurter
sudo systemctl start impulse-sync@openfoodfacts
sudo systemctl start impulse-sync@wikidata
sudo systemctl start impulse-sync@icecat
```

The system uses one Uvicorn worker bound to `127.0.0.1:8000`, nginx on ports
80/443, WAL-mode SQLite at `/opt/impulse/storage/impulse.db`, seven rotating
verified backups, and systemd timers for provider data and GeoLite. See
[deployment operations](docs/deployment.md), [IP-address HTTPS](docs/HTTPS_WITHOUT_DOMAIN.md),
and the [deployment checklist](docs/DEPLOYMENT_CHECKLIST.md).

Future updates are explicit and preserve `.env` and SQLite:

```bash
cd /opt/impulse
git fetch origin
git status
git pull --ff-only origin main
sudo ./scripts/deploy_backend.sh
```

## Mobile release preparation

The iOS bundle ID and Android application ID are both
`com.rshukla2.impulse`. Build iOS after selecting the owner-controlled Apple
team and signing profile in Xcode:

```bash
cd mobile
flutter build ipa --release --dart-define=API_BASE_URL='https://[YOUR_IPV6]'
```

For Android, create an upload keystore outside Git and copy
`mobile/android/key.properties.example` to the ignored
`mobile/android/key.properties`. Release builds are never signed with the debug
key. Then build the Play Store artifact:

```bash
cd mobile
flutter build appbundle --release --dart-define=API_BASE_URL='https://[YOUR_IPV6]'
```

No location, camera, contacts, tracking, account, address, or payment
permissions are requested. App Store/Play metadata, signing credentials,
screenshots, review declarations, and store submission remain owner steps.

## Production troubleshooting

```bash
systemctl status impulse
journalctl -u impulse
nginx -t
systemctl status nginx
systemctl list-timers 'impulse-*'
curl --globoff 'https://[YOUR_IPV6]/health'
```

## Privacy boundary

The entered display name, Login completion, cart, orders, and savings remain in
Flutter local storage. The display name is not sent to FastAPI. The backend may
process a public request IP in memory solely to perform a local country lookup;
the application does not persist or log that IP. Run Uvicorn with access
logging disabled as shown above so the server does not independently emit raw
connection addresses.
