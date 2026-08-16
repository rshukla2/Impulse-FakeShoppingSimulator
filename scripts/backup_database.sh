#!/usr/bin/env bash
set -euo pipefail

app_dir="${IMPULSE_APP_DIR:-/opt/impulse}"
database_path="${IMPULSE_DATABASE_PATH:-${app_dir}/storage/impulse.db}"
backup_dir="${IMPULSE_BACKUP_DIR:-${app_dir}/backups}"
retention="${IMPULSE_BACKUP_RETENTION:-7}"

if [[ ! -f "$database_path" ]]; then
  echo "Database not found: $database_path" >&2
  exit 1
fi
if ! [[ "$retention" =~ ^[1-9][0-9]*$ ]]; then
  echo "IMPULSE_BACKUP_RETENTION must be a positive integer" >&2
  exit 1
fi

mkdir -p "$backup_dir"
umask 0077
timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
staged="${backup_dir}/.impulse-${timestamp}.sqlite"
archive="${backup_dir}/impulse-${timestamp}.sqlite.gz"
trap 'rm -f "$staged"' EXIT

sqlite3 "$database_path" ".timeout 30000" ".backup '$staged'"
integrity="$(sqlite3 "$staged" 'PRAGMA integrity_check;')"
if [[ "$integrity" != "ok" ]]; then
  echo "Backup integrity check failed" >&2
  exit 1
fi
gzip -9 "$staged"
mv "${staged}.gz" "$archive"
trap - EXIT

shopt -s nullglob
backups=("$backup_dir"/impulse-*.sqlite.gz)
excess=$((${#backups[@]} - retention))
for ((index = 0; index < excess; index++)); do
  # UTC timestamps make lexical glob order the same as oldest-to-newest order.
  rm -f -- "${backups[$index]}"
done

echo "Created verified backup: $archive"
