#!/usr/bin/env bash
set -euo pipefail

# === Config ===
REMOTE_USER="root"
REMOTE_HOST="91.107.208.207"

# Inside the container (mounted volume)
CONTAINER_DB_PATH="/rails/storage/production_rubyvideo.sqlite3"
CONTAINER_TMP_DIR="/rails/storage"
CONTAINER_TMP_BACKUP="/rails/storage/production_rubyvideo-backup.sqlite3"
# CONTAINER_TMP_BACKUP="${CONTAINER_TMP_DIR}/production_rubyvideo-backup.sqlite3"

# Host path for the same Docker volume (what scp will read)
HOST_VOLUME_DIR="/var/lib/docker/volumes/storage/_data"
HOST_TMP_BACKUP="${HOST_VOLUME_DIR}/production_rubyvideo-backup.sqlite3"

# Local target + local safety backup dir
LOCAL_DEST="storage/development_rubyvideo.sqlite3"
LOCAL_BACKUP_DIR="storage/backups"

# === Step 0: Local safety copy (timestamped) ===
if [ -f "${LOCAL_DEST}" ]; then
  mkdir -p "${LOCAL_BACKUP_DIR}"
  TS=$(date +"%Y%m%d-%H%M%S")
  LOCAL_SNAPSHOT="${LOCAL_BACKUP_DIR}/development_rubyvideo-${TS}.sqlite3"
  echo "→ Creating local pre-download snapshot: ${LOCAL_SNAPSHOT}"
  cp "${LOCAL_DEST}" "${LOCAL_SNAPSHOT}"
fi

# === Step 1: Create backup inside container via Kamal ===
echo "→ Creating SQLite backup in container (via Kamal)..."
dotenv kamal app exec "sqlite3 '${CONTAINER_DB_PATH}' \".backup '${CONTAINER_TMP_BACKUP}'\""
dotenv kamal app exec "ls -la '${CONTAINER_TMP_DIR}'"

# === Step 2: Download the backup from the host volume ===
echo "→ Downloading backup from host to local: ${LOCAL_DEST}"
scp "${REMOTE_USER}@${REMOTE_HOST}:${HOST_TMP_BACKUP}" "${LOCAL_DEST}"

# Optional: verify integrity locally (uncomment to enforce)
echo '→ Running local PRAGMA integrity_check...'
sqlite3 "${LOCAL_DEST}" "PRAGMA integrity_check;" | grep -q '^ok$' || {
  echo "Integrity check failed!" >&2
  exit 1
}

# === Step 3: Clean up the temp backup inside container ===
echo "→ Cleaning up temp backup in container..."
dotenv kamal app exec "rm -f '${CONTAINER_TMP_BACKUP}'"

echo "✅ Done. Local DB refreshed at: ${LOCAL_DEST}"
