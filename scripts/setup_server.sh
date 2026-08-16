#!/usr/bin/env bash
set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Run this script with sudo." >&2
  exit 1
fi
if [[ $# -ne 1 ]]; then
  echo "Usage: sudo $0 PUBLIC_IP" >&2
  exit 2
fi

public_ip="$1"
app_dir="${IMPULSE_APP_DIR:-/opt/impulse}"
source_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

python3 - "$public_ip" <<'PY'
import ipaddress
import sys
address = ipaddress.ip_address(sys.argv[1])
if not address.is_global:
    raise SystemExit("PUBLIC_IP must be a globally routable IPv4 or IPv6 address")
PY

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y python3 python3-venv python3-pip git nginx sqlite3 curl ufw snapd sudo ca-certificates fail2ban
snap install core >/dev/null 2>&1 || snap refresh core
if snap list certbot >/dev/null 2>&1; then
  snap refresh certbot
else
  snap install --classic certbot
fi

if ! id impulse >/dev/null 2>&1; then
  useradd --system --home-dir "$app_dir" --shell /usr/sbin/nologin impulse
fi
mkdir -p "$app_dir" "$app_dir/storage" "$app_dir/backups" /var/www/certbot/.well-known/acme-challenge

if [[ "$source_dir" != "$app_dir" ]]; then
  echo "Repository must be cloned at $app_dir before setup (current: $source_dir)." >&2
  exit 1
fi

python3 -m venv "${app_dir}/.venv"
"${app_dir}/.venv/bin/python" -m pip install --upgrade pip
"${app_dir}/.venv/bin/python" -m pip install -r "${app_dir}/backend/requirements.txt"
chown -R impulse:impulse "${app_dir}/storage" "${app_dir}/backups"
chmod 0750 "${app_dir}/storage" "${app_dir}/backups"

install -m 0644 "${app_dir}/deploy/impulse.service" /etc/systemd/system/
install -m 0644 "${app_dir}/deploy/impulse-sync@.service" /etc/systemd/system/
install -m 0644 "${app_dir}/deploy/impulse-backup.service" /etc/systemd/system/
install -m 0644 "${app_dir}/deploy/impulse-geoip.service" /etc/systemd/system/
for timer in "${app_dir}"/deploy/impulse-{backup,frankfurter,icecat,openfoodfacts,wikidata,geoip}.timer; do
  install -m 0644 "$timer" /etc/systemd/system/
done

install -m 0644 "${app_dir}/deploy/nginx-bootstrap.conf" /etc/nginx/sites-available/impulse
ln -sfn /etc/nginx/sites-available/impulse /etc/nginx/sites-enabled/impulse
rm -f /etc/nginx/sites-enabled/default
nginx -t
systemctl enable --now nginx
systemctl reload nginx

install -m 0644 "${app_dir}/deploy/fail2ban-sshd.local" /etc/fail2ban/jail.d/impulse-sshd.local
systemctl enable --now fail2ban
systemctl restart fail2ban

ssh_port="$(sshd -T 2>/dev/null | awk '$1 == "port" {print $2; exit}')"
ssh_port="${ssh_port:-22}"
if [[ "$public_ip" == *:* ]]; then
  sed -i 's/^IPV6=.*/IPV6=yes/' /etc/default/ufw
fi
ufw allow "${ssh_port}/tcp"
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable

systemctl daemon-reload
systemctl enable impulse-{backup,frankfurter,icecat,openfoodfacts,wikidata,geoip}.timer

if [[ ! -f "${app_dir}/.env" ]]; then
  echo "Create ${app_dir}/.env from .env.example, set production paths/secrets, then run deploy_backend.sh." >&2
else
  echo "Existing .env preserved. Run deploy_backend.sh after validating its production values."
fi
echo "Next: sudo ${app_dir}/scripts/enable_https.sh ${public_ip} YOUR_EMAIL"
