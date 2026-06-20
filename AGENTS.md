# AGENTS.md

## Critical data-safety rules

- Read `docs/PRODUCTION_UPDATE_RUNBOOK.md` before any Docker, update, upstream merge, login-failure, or database-related work.
- Never start production Docker in a way that can create a fresh empty SQLite database.
- Never change the mounted data directory unless the user explicitly asks and confirms the old database was copied.
- Default production data directory is `/data/fast-note-sync`.
- Main SQLite database must exist before startup: `/data/fast-note-sync/storage/database/db.sqlite3`.
- If the DB file is missing or empty, stop and ask. Do not run `docker compose up` directly.

## Safe update flow

Project update command: `/update`. It is defined in `.pi/prompts/update.md` and should use the repo-local skill `.pi/skills/fns-update/SKILL.md`. Use this workflow whenever the user mentions update, upstream pull/merge, Docker restart, or login failure after update.

Use the safe update script for Docker image updates:

```bash
bash docker/safe_update.sh
```

Use this only when a git pull from `origin` is also intended:

```bash
GIT_PULL=1 bash docker/safe_update.sh
```

Use this only when merging from the original upstream project is intended:

```bash
UPSTREAM=1 bash docker/safe_update.sh
```

If the upstream merge conflicts, stop after resolving conflicts and rerun `bash docker/safe_update.sh`; do not manually run Docker down/up.

The script must:

1. Verify the DB directory exists.
2. Verify `db.sqlite3` exists and is non-empty.
3. Create a timestamped DB backup under `/data/fast-note-sync/backups/database/`.
4. Preserve local safety patches after any git pull or upstream merge.
5. Pull the configured image.
6. Restart via Docker Compose.

## Docker Compose

Compose file: `docker/docker-compose.yaml`.

Current host ports:

- App HTTP: `9002 -> 9000`
- Extra/WebSocket: `9003 -> 9001`

Port `9000` may be used by Portainer, so do not move the app back to host `9000` without checking conflicts.

## Known recurring incident

This deployment has repeatedly lost login/account visibility after updates because Docker was restarted against the wrong or empty SQLite path, or upstream changes overwrote local production safety behavior. Treat every update as data-risky. If login fails after update, inspect `/data/fast-note-sync` mounts and DB files before doing anything else.

## SQLite hard-fail behavior

`internal/dao/dao.go` is intentionally changed so SQLite does not auto-create a missing database file. This protects production from silently booting with an empty DB after path drift or mount mistakes.

Do not revert this behavior unless the user explicitly asks.

## Password reset

- Never reset any password during update, git pull, Docker pull, or restart.
- Never run `reset-password` unless the user explicitly asks for a password reset in that turn.
- Safe update scripts must not call `reset-password` or modify `user.password`.
- Before any password reset, confirm the exact username and new password source.
- Updates must preserve auth DB files and tokens; if login fails after an update, inspect DB path/mount first, do not reset automatically.

Because the database path in config is relative, run reset commands with working directory `/fast-note-sync` only when explicitly requested:

```bash
docker exec -w /fast-note-sync fast-note-sync-service ./fast-note-sync-service reset-password -u <username> -p '<new-password>' -c /fast-note-sync/config/config.yaml
```

## Current recovered user

Known restored account in DB:

- username: `raquezha`
- email: `raquezha@gmail.com`

## Daily Backup Protocol
Automated daily backups are configured via systemd timer to ensure they run even after power outages (via `Persistent=true`).

**Backup Script**: `~/RQZ/personal/fast-note-sync-service/scripts/backup.sh`
**Backs up**:
1. Obsidian Notes (`~/RQZ/notes`)
2. Fast Note Sync Data (`/data/fast-note-sync`)
3. Homelab Configs (`~/homelab`)

**Retention**: 7 days of historical tarballs in `~/backups/daily/`.

To install:
```bash
sudo cp ~/RQZ/personal/fast-note-sync-service/scripts/fns-backup.service /etc/systemd/system/
sudo cp ~/RQZ/personal/fast-note-sync-service/scripts/fns-backup.timer /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now fns-backup.timer
```


