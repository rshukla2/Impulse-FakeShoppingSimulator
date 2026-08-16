#!/usr/bin/env bash
set -euo pipefail

app_dir="${IMPULSE_APP_DIR:-/opt/impulse}"
venv_dir="${app_dir}/.venv"

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Run this script with sudo." >&2
  exit 1
fi
if [[ ! -f "${app_dir}/.env" ]]; then
  echo "Missing ${app_dir}/.env; create it from .env.example without committing it." >&2
  exit 1
fi
chown root:impulse "${app_dir}/.env"
chmod 0640 "${app_dir}/.env"
if [[ ! -x "${venv_dir}/bin/python" ]]; then
  python3 -m venv "$venv_dir"
fi

"${venv_dir}/bin/python" -m pip install --upgrade pip
"${venv_dir}/bin/python" -m pip install -r "${app_dir}/backend/requirements.txt"

cd "$app_dir"
"${venv_dir}/bin/python" scripts/validate_production_env.py
if [[ -f "${app_dir}/storage/impulse.db" ]]; then
  sudo -u impulse "${app_dir}/scripts/backup_database.sh"
fi
sudo -u impulse "${venv_dir}/bin/python" scripts/migrate_database.py

chown -R impulse:impulse "${app_dir}/storage" "${app_dir}/backups"
systemctl daemon-reload
systemctl enable --now impulse.service
systemctl restart impulse.service
systemctl is-active --quiet impulse.service
systemctl enable --now impulse-{backup,frankfurter,icecat,openfoodfacts,wikidata,geoip}.timer
nginx -t
systemctl reload nginx
curl --fail --silent --show-error http://127.0.0.1:8000/health >/dev/null
echo "Impulse backend deployment verified."
