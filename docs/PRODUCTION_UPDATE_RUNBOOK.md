# Production update runbook

This repo is a fork used to run Fast Note Sync Service in production.

## What this service does

Fast Note Sync Service is a Go + WebSocket + REST API server for syncing Obsidian notes, folders, attachments, shares, history, and user/auth data. This deployment uses Docker and SQLite.

Important production paths:

- Compose file: `docker/docker-compose.yaml`
- Host data root: `/data/fast-note-sync`
- Main SQLite DB: `/data/fast-note-sync/storage/database/db.sqlite3`
- User SQLite DBs: `/data/fast-note-sync/storage/database/db_user_*.sqlite3`
- Runtime config: `/data/fast-note-sync/config/config.yaml`
- Container paths: `/fast-note-sync/storage/` and `/fast-note-sync/config/`

Git remotes:

- `origin`: `https://github.com/raquezha/fast-note-sync-service.git` - personal fork with production safety patches.
- `upstream`: `https://github.com/haierkeys/fast-note-sync-service.git` - original project.

## Previous recurring production issues

Based on repo history, these are the incidents this runbook must prevent:

1. Docker update started the app against a missing or wrong SQLite path, causing a fresh empty DB to be created.
2. Account/login disappeared after update because the app was using the wrong DB or an empty DB.
3. Upstream compose defaults conflicted with local production needs: `latest` image, host ports `9000/9001`, and hard-coded mounts.
4. Port `9000` can conflict with Portainer, so production uses host `9002 -> 9000` and `9003 -> 9001`.
5. Login failures after update were treated like password problems. They are usually data-path/mount problems. Do not reset passwords unless explicitly requested.
6. Upstream merges can overwrite local safety patches, especially Docker mounts and SQLite missing-file behavior.
7. This has happened multiple times, so every update must be treated as data-risky until DB, config, mounts, and backup are verified.

## Non-negotiable rules

Never run this during production update:

```bash
docker compose -f docker/docker-compose.yaml down
docker compose -f docker/docker-compose.yaml up -d
```

Never run `docker compose up` unless all of these are true:

1. `/data/fast-note-sync/storage/database/db.sqlite3` exists.
2. `/data/fast-note-sync/storage/database/db.sqlite3` is non-empty.
3. `/data/fast-note-sync/config/config.yaml` exists.
4. A timestamped DB backup was created first.
5. `docker/docker-compose.yaml` still mounts `${FNS_DATA_DIR:-/data/fast-note-sync}/storage/` to `/fast-note-sync/storage/`.
6. `docker/docker-compose.yaml` still mounts `${FNS_DATA_DIR:-/data/fast-note-sync}/config/` to `/fast-note-sync/config/`.
7. `internal/dao/dao.go` still hard-fails when a SQLite file is missing.

Never reset passwords as part of update. If login fails, inspect DB path and mounts first.

## Standard Docker image update

Use this only when updating the Docker image/tag and not merging upstream source:

```bash
bash docker/safe_update.sh
```

The script verifies DB/config, backs up DB files, pulls the image, then restarts.

## Pull changes from origin fork

Use this when pulling from `origin/master` is intended:

```bash
GIT_PULL=1 bash docker/safe_update.sh
```

## Merge changes from upstream project

Use this when pulling from the original project:

```bash
UPSTREAM=1 bash docker/safe_update.sh
```

If there is a merge conflict, stop. Do not manually run Docker down/up. Resolve conflicts while preserving these local safety patches:

- `docker/docker-compose.yaml` production ports, restart policy, and `FNS_DATA_DIR` mounts.
- `docker/safe_update.sh` preflight checks and backup.
- `internal/dao/dao.go` SQLite missing-file hard fail.
- `AGENTS.md` and this runbook.

After resolving conflicts, run:

```bash
bash docker/safe_update.sh
```

## Manual preflight checklist

If you must inspect manually before update:

```bash
ls -lah /data/fast-note-sync/config
ls -lah /data/fast-note-sync/storage/database
```

Expected:

- `config.yaml` exists in `/data/fast-note-sync/config`.
- `db.sqlite3` exists and is not empty.
- User DB files like `db_user_1.sqlite3` may exist.

If any file is missing or permissions show unreadable entries, stop and ask before restart.

## Recovery principle

A login failure after update means: suspect wrong mount or wrong DB first.

Do not create a new database. Do not reset password. Do not change data directory. Restore or point Docker back to the previous `/data/fast-note-sync` data root.
