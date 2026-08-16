# Deployment Status and Target Topology

Flutter web deployment is implemented through
`.github/workflows/deploy-pages.yml`. The workflow builds for the repository
subpath, validates the Flutter project, and deploys through GitHub's official
Pages artifact flow. Set the GitHub Actions repository variable `API_BASE_URL`
to the final HTTPS backend URL when it becomes available.

DigitalOcean, DNS, certificates, nginx, and systemd remain deferred.

## Intended topology

```text
GitHub Pages (Flutter web)
        │
        │ HTTPS API requests
        ▼
nginx on a DigitalOcean droplet
        │ reverse proxy to loopback
        ▼
systemd-managed Uvicorn/FastAPI
        │
        ├── SQLite application database
        └── local GeoLite2 Country MMDB
```

The future deployment phase must provide:

1. A production API hostname and TLS certificate.
2. nginx configuration that replaces `X-Forwarded-For` and `X-Real-IP`, rather
   than trusting values supplied by public clients.
3. Uvicorn bound only to `127.0.0.1`, raw-IP access logging disabled or
   redacted, and `TRUST_PROXY_HEADERS=true` in the systemd environment.
4. A dedicated unprivileged service user and writable SQLite/MMDB directories.
5. A systemd service for FastAPI and timers for GeoLite/catalog maintenance.
6. Restricted CORS containing the final GitHub Pages and native-app origins.
7. Backup, log-retention, health-check, and rollback procedures.

The former Caddy-based instructions have been removed because nginx + systemd
is the selected architecture.

Recommended future refresh cadence is daily for Frankfurter and Icecat, daily
for Open Food Facts countries already present in `catalog_country_sync`, weekly
for Wikidata/Commons, and at least monthly for GeoLite2. This repository does
not install those timers in the current phase.
