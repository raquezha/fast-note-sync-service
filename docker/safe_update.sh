#!/usr/bin/env bash
set -euo pipefail

COMPOSE_FILE="${COMPOSE_FILE:-docker/docker-compose.yaml}"
FNS_DATA_DIR="${FNS_DATA_DIR:-/data/fast-note-sync}"
DB_DIR="$FNS_DATA_DIR/storage/database"
CONFIG_DIR="$FNS_DATA_DIR/config"
BACKUP_ROOT="$FNS_DATA_DIR/backups/database"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="$BACKUP_ROOT/$STAMP"

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

require_data() {
  [ -f "$COMPOSE_FILE" ] || fail "compose file missing: $COMPOSE_FILE"
  [ -d "$DB_DIR" ] || fail "database dir missing: $DB_DIR"
  [ -f "$DB_DIR/db.sqlite3" ] || fail "main sqlite DB missing: $DB_DIR/db.sqlite3; refusing to start fresh DB"
  [ -s "$DB_DIR/db.sqlite3" ] || fail "main sqlite DB empty: $DB_DIR/db.sqlite3; refusing to start fresh DB"
  [ -d "$CONFIG_DIR" ] || fail "config dir missing: $CONFIG_DIR"
  [ -f "$CONFIG_DIR/config.yaml" ] || fail "config missing: $CONFIG_DIR/config.yaml"
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

mkdir -p "$BACKUP_DIR"
cp -a "$DB_DIR"/. "$BACKUP_DIR"/
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
