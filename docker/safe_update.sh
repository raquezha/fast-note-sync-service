#!/usr/bin/env bash
set -euo pipefail

COMPOSE_FILE="${COMPOSE_FILE:-docker/docker-compose.yaml}"
FNS_DATA_DIR="${FNS_DATA_DIR:-/data/fast-note-sync}"
DB_DIR="$FNS_DATA_DIR/storage/database"
CONFIG_DIR="$FNS_DATA_DIR/config"
BACKUP_ROOT="$FNS_DATA_DIR/backups/database"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="$BACKUP_ROOT/$STAMP"
HELPER_IMAGE="${HELPER_IMAGE:-haierkeys/fast-note-sync-service:latest}"

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

data_sh() {
  docker run --rm --entrypoint sh -v "$FNS_DATA_DIR:/fns-data" "$HELPER_IMAGE" -c "$1"
}

require_data() {
  [ -f "$COMPOSE_FILE" ] || fail "compose file missing: $COMPOSE_FILE"
  data_sh "
    [ -d /fns-data/storage/database ] || { echo 'ERROR: database dir missing: $DB_DIR' >&2; exit 1; }
    [ -f /fns-data/storage/database/db.sqlite3 ] || { echo 'ERROR: main sqlite DB missing: $DB_DIR/db.sqlite3; refusing to start fresh DB' >&2; exit 1; }
    [ -s /fns-data/storage/database/db.sqlite3 ] || { echo 'ERROR: main sqlite DB empty: $DB_DIR/db.sqlite3; refusing to start fresh DB' >&2; exit 1; }
    [ -d /fns-data/config ] || { echo 'ERROR: config dir missing: $CONFIG_DIR' >&2; exit 1; }
    [ -f /fns-data/config/config.yaml ] || { echo 'ERROR: config missing: $CONFIG_DIR/config.yaml' >&2; exit 1; }
  "
}

require_repo_safety() {
  grep -Fq 'restart: unless-stopped' "$COMPOSE_FILE" || fail "compose restart policy changed; inspect before restart"
  grep -Fq '"${HOST_BIND:-0.0.0.0}:9002:9000"' "$COMPOSE_FILE" || fail "compose app port/bind changed; inspect before restart"
  grep -Fq '"${HOST_BIND:-0.0.0.0}:9003:9001"' "$COMPOSE_FILE" || fail "compose websocket port/bind changed; inspect before restart"
  grep -Fq '${FNS_DATA_DIR:-/data/fast-note-sync}/storage/:/fast-note-sync/storage/' "$COMPOSE_FILE" || fail "compose storage mount changed; inspect before restart"
  grep -Fq '${FNS_DATA_DIR:-/data/fast-note-sync}/config/:/fast-note-sync/config/' "$COMPOSE_FILE" || fail "compose config mount changed; inspect before restart"
  grep -Fq 'sqlite database file missing' internal/dao/dao.go || fail "sqlite hard-fail guard missing from internal/dao/dao.go"
}

require_data
require_repo_safety

data_sh "mkdir -p '/fns-data/backups/database/$STAMP' && cp -a /fns-data/storage/database/. '/fns-data/backups/database/$STAMP/'"
echo "DB backup created: $BACKUP_DIR"

if [ "${UPSTREAM:-0}" = "1" ]; then
  git fetch upstream
  git merge --no-edit upstream/master
elif [ "${GIT_PULL:-0}" = "1" ]; then
  git pull --ff-only
fi

require_data
require_repo_safety

export FNS_DATA_DIR

docker compose -f "$COMPOSE_FILE" pull
docker compose -f "$COMPOSE_FILE" down
docker compose -f "$COMPOSE_FILE" up -d

require_data

echo "Safe update done. Data dir: $FNS_DATA_DIR"
