# Production deployment

The deployment assets in this repository implement this single-server design:

```text
Flutter web on GitHub Pages
        │ HTTPS REST
        ▼
DigitalOcean public IP :443
        │
      nginx
        │ loopback only
        ▼
systemd → Uvicorn/FastAPI 127.0.0.1:8000
        │
        ├── /opt/impulse/storage/impulse.db
        └── /opt/impulse/storage/GeoLite2-Country.mmdb
```

No Docker, Kubernetes, managed database, Firebase, or separate worker service
is required. The recommended starting Droplet is Ubuntu with 1 GiB RAM. Uvicorn
uses one worker because the application is small and SQLite-backed.

## First deployment on a new Ubuntu Droplet

Create an Ubuntu Droplet and record its globally routable IPv4 or IPv6 address.
For the current password-based setup, use a long unique root password and
connect with `ssh -6 root@PUBLIC_IPV6`. The setup installs and enables Fail2ban.
Set `PUBLIC_IP` to the raw IPv6 address without brackets; brackets belong only
in URLs:

```bash
# From your computer; enter the Droplet password when prompted:
ssh -6 root@YOUR_RAW_IPV6

# On the Droplet:
apt-get update
apt-get install -y git
git clone https://github.com/rshukla2/Impulse-FakeShoppingSimulator.git /opt/impulse
cd /opt/impulse
PUBLIC_IP='YOUR_RAW_IPV6'
PUBLIC_URL="https://[${PUBLIC_IP}]"
sudo ./scripts/setup_server.sh "$PUBLIC_IP"
sudo cp deploy/production.env.example .env
sudo chmod 640 .env
sudo editor .env
sudo chown root:impulse .env
sudo ./scripts/deploy_backend.sh
sudo ./scripts/enable_https.sh "$PUBLIC_IP" CONTACT_EMAIL
curl --globoff --fail "$PUBLIC_URL/health"
```

The setup script preserves any existing `.env`. The deploy script preserves
the SQLite database, makes a verified backup when one exists, applies additive
migrations and seed convergence, restarts the service, and checks `/health`.
It deliberately does not perform `git pull` so reviewing fetched code remains
an explicit operator step.

Copy an initial GeoLite database to
`/opt/impulse/storage/GeoLite2-Country.mmdb`, or run:

```bash
sudo -u impulse /opt/impulse/.venv/bin/python \
  /opt/impulse/scripts/update_geoip_database.py
sudo systemctl restart impulse
```

Run the initial cache synchronization after the service is healthy:

```bash
sudo systemctl start impulse-sync@frankfurter
sudo systemctl start impulse-sync@openfoodfacts
sudo systemctl start impulse-sync@wikidata
sudo systemctl start impulse-sync@icecat
```

The Icecat import targets 5,000 usable products and can take substantially
longer than the other jobs. A failed provider sync leaves the last successful
SQLite cache active.

## Production environment

Use [production.env.example](../deploy/production.env.example) as the template.
The required operator-entered secrets are:

- `ICECAT_CONTENT_ACCESS_TOKEN`
- `ICECAT_API_ACCESS_TOKEN`
- `MAXMIND_ACCOUNT_ID`
- `MAXMIND_LICENSE_KEY`

Open Food Facts, Wikidata, Wikimedia Commons, and Frankfurter use keyless public
read APIs. `CORS_ALLOWED_ORIGINS` must be the exact Pages origin
`https://rshukla2.github.io` (an Origin never contains the repository path).
Keep `ENABLE_LAZY_COUNTRY_SYNC=false`: users read the cache and never trigger
provider jobs. Set `DATABASE_URL=sqlite:////opt/impulse/storage/impulse.db`,
`GEOIP_DATABASE_PATH=/opt/impulse/storage/GeoLite2-Country.mmdb`, and
`TRUST_PROXY_HEADERS=true` only because the backend is reachable solely through
local nginx.

## Services and schedules

The installed systemd timers are:

| Work | Schedule (server time) |
|---|---|
| SQLite backup | daily 02:15 |
| Frankfurter | daily 02:45 |
| Icecat | Monday and Thursday 03:15 |
| Open Food Facts | daily 04:15 |
| Wikidata + Commons | Sunday 05:15 |
| GeoLite2 | monthly |
| TLS renewal check | twice daily after HTTPS setup |

Timers use persistent catch-up and randomized delays. Inspect them with:

```bash
systemctl list-timers 'impulse-*'
journalctl -u impulse-sync@icecat
journalctl -u impulse-backup
```

## Updating production

```bash
cd /opt/impulse
git fetch origin
git status
git pull --ff-only origin main
sudo ./scripts/deploy_backend.sh
curl --globoff --fail 'https://[PUBLIC_IPV6]/health'
```

Never replace `.env`, `storage/`, or `backups/` from a checkout. Those
paths are ignored and deployments do not delete them.

## SQLite backup and restore

The backup service uses SQLite's online `.backup`, runs `integrity_check`,
compresses the result, and retains the newest seven archives. Run it manually:

```bash
sudo systemctl start impulse-backup
ls -l /opt/impulse/backups
```

Restore during a maintenance window:

```bash
sudo systemctl stop impulse
sudo -u impulse gunzip -c /opt/impulse/backups/impulse-TIMESTAMP.sqlite.gz \
  > /opt/impulse/storage/impulse.restore.db
sudo -u impulse sqlite3 /opt/impulse/storage/impulse.restore.db 'PRAGMA integrity_check;'
sudo mv /opt/impulse/storage/impulse.db /opt/impulse/backups/pre-restore.sqlite
sudo mv /opt/impulse/storage/impulse.restore.db /opt/impulse/storage/impulse.db
sudo chown impulse:impulse /opt/impulse/storage/impulse.db
sudo systemctl start impulse
```

Proceed only if the integrity result is `ok`. The pre-restore database remains
recoverable in `backups/`.

## Firewall and server security

`setup_server.sh` enables UFW for the SSH port reported by sshd plus TCP 80 and
443. Ubuntu's default UFW configuration applies those rules to IPv6; confirm
the `(v6)` entries with `ufw status verbose`. Port 8000 is not opened and
Uvicorn binds only to loopback. Also enable a DigitalOcean Cloud Firewall with
the same IPv6 inbound rules (`::/0` for HTTP/HTTPS and preferably a narrower
source for SSH). Fail2ban blocks an address for an hour after five
failed SSH attempts in ten minutes. Password SSH remains supported; restrict
SSH source ranges when practical and migrate to a key later for stronger
protection. Do not disable password/root login until another sudo-capable login
has been tested.

An IPv6-only API is unreachable from genuinely IPv4-only client networks. If
the app must work from every network, retain or add public IPv4 as well; the
same scripts support either address, but GitHub's `API_BASE_URL` selects one.

nginx does not write access logs, and Uvicorn access logging is disabled, to
avoid retaining client IP addresses. nginx overwrites forwarded IP headers;
Uvicorn accepts proxy headers only from `127.0.0.1`. A lightweight in-memory
nginx limit allows 20 requests/second per address with a burst of 40 and returns
HTTP 429 for excess traffic; it does not persist address data.

## Troubleshooting

```bash
systemctl status impulse
journalctl -u impulse --since today
nginx -t
systemctl status nginx
curl --fail http://127.0.0.1:8000/health
curl --globoff --fail 'https://[PUBLIC_IPV6]/health'
fail2ban-client status sshd
systemctl list-timers 'impulse-*'
```

See [HTTPS_WITHOUT_DOMAIN.md](HTTPS_WITHOUT_DOMAIN.md) for certificate details
and [DEPLOYMENT_CHECKLIST.md](DEPLOYMENT_CHECKLIST.md) before launch.
