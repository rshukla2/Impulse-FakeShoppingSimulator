#!/usr/bin/env bash
set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Run this script with sudo." >&2
  exit 1
fi
if [[ $# -ne 2 ]]; then
  echo "Usage: sudo $0 PUBLIC_IP CONTACT_EMAIL" >&2
  exit 2
fi

public_ip="$1"
contact_email="$2"
app_dir="${IMPULSE_APP_DIR:-/opt/impulse}"
certbot="/snap/bin/certbot"

python3 - "$public_ip" <<'PY'
import ipaddress
import sys
address = ipaddress.ip_address(sys.argv[1])
if not address.is_global:
    raise SystemExit("PUBLIC_IP must be a globally routable IPv4 or IPv6 address")
PY

public_url_host="$(python3 - "$public_ip" <<'PY'
import ipaddress
import sys
address = ipaddress.ip_address(sys.argv[1])
print(f"[{address}]" if address.version == 6 else str(address))
PY
)"

if [[ ! -x "$certbot" ]]; then
  echo "Current snap Certbot is required; run setup_server.sh first." >&2
  exit 1
fi
certbot_version="$($certbot --version | sed -E 's/[^0-9]*([0-9]+\.[0-9]+).*/\1/')"
certbot_major="${certbot_version%%.*}"
certbot_minor="${certbot_version#*.}"
if (( certbot_major < 5 || (certbot_major == 5 && certbot_minor < 4) )); then
  echo "Certbot 5.4 or newer is required for IP certificates." >&2
  exit 1
fi

certbot_args=(certonly --non-interactive --agree-tos --email "$contact_email" --preferred-profile shortlived --webroot --webroot-path /var/www/certbot --ip-address "$public_ip")
if [[ "${IMPULSE_CERTBOT_STAGING:-false}" == "true" ]]; then
  certbot_args+=(--staging)
fi
"$certbot" "${certbot_args[@]}"

install -d -m 0755 /etc/letsencrypt/renewal-hooks/deploy
install -m 0755 "${app_dir}/deploy/reload-nginx-after-renewal.sh" \
  /etc/letsencrypt/renewal-hooks/deploy/impulse-reload-nginx
sed \
  -e "s|__PUBLIC_IP__|${public_ip}|g" \
  -e "s|__PUBLIC_URL_HOST__|${public_url_host}|g" \
  "${app_dir}/deploy/nginx.conf" > /etc/nginx/sites-available/impulse
ln -sfn /etc/nginx/sites-available/impulse /etc/nginx/sites-enabled/impulse
nginx -t
systemctl reload nginx
install -m 0644 "${app_dir}/deploy/impulse-certbot-renew.service" /etc/systemd/system/
install -m 0644 "${app_dir}/deploy/impulse-certbot-renew.timer" /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now impulse-certbot-renew.timer
echo "HTTPS enabled at https://${public_url_host}."
