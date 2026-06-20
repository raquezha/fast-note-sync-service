---
name: fns-update
description: Safe production update workflow for this repo's Fast Note Sync Service deployment. Use for /update, /skill:fns-update, Docker image updates, origin pulls, upstream merges, Docker restarts, or login failures after update. Protects SQLite data by enforcing preflight checks, backups, safe_update.sh, preserved mounts, and no password reset.
---

# FNS Safe Update

This skill is repo-local. It exists only for this Fast Note Sync Service deployment.

Normal user entrypoint: `/update`.

Mission: update safely without losing the SQLite database, user account, auth tokens, notes, or login state.

## Golden rule

Never improvise a Docker update. Use `docker/safe_update.sh` or stop and ask.

The bad pattern that caused past incidents is:

```bash
docker compose -f docker/docker-compose.yaml down
git pull
docker compose -f docker/docker-compose.yaml up -d
```

Do not do that.

## Required context load

Before changing anything, read these files from repo root:

1. `AGENTS.md`
2. `docs/PRODUCTION_UPDATE_RUNBOOK.md`
3. `docker/safe_update.sh`
4. `docker/docker-compose.yaml`

If any file is missing, stop and report it.

## Understand the production shape

Expected production data root:

```text
/data/fast-note-sync
```

Critical files:

```text
/data/fast-note-sync/storage/database/db.sqlite3
/data/fast-note-sync/config/config.yaml
```

Expected Docker mounts:

```text
${FNS_DATA_DIR:-/data/fast-note-sync}/storage/ -> /fast-note-sync/storage/
${FNS_DATA_DIR:-/data/fast-note-sync}/config/  -> /fast-note-sync/config/
```

Expected host ports:

```text
9002 -> container 9000
9003 -> container 9001
```

Port `9000` on host may conflict with Portainer. Do not move the app back to host `9000` unless explicitly requested after checking conflicts.

## Absolute no-go actions

Never do these during update:

- Do not manually run Docker down/up.
- Do not run `reset-password`.
- Do not delete Docker volumes.
- Do not change `FNS_DATA_DIR`.
- Do not change mounted host data paths.
- Do not start the app if `db.sqlite3` is missing or empty.
- Do not treat login failure as a password problem before checking DB/mounts.

Password reset is allowed only if the user explicitly asks for a password reset in the current turn and confirms username plus password source.

## Choose update mode

Default: if the user says only `/update` or just asks to update, do the full safe production update:

```bash
UPSTREAM=1 bash docker/safe_update.sh
```

This merges from original upstream, then pulls/restarts Docker through the guarded script.

Use this mapping:

| User intent | Command |
| --- | --- |
| `/update`, update, full update, repo update, upstream update | `UPSTREAM=1 bash docker/safe_update.sh` |
| update Docker image/tag only | `bash docker/safe_update.sh` |
| pull my fork / origin | `GIT_PULL=1 bash docker/safe_update.sh` |
| check only | inspect files and safety state; do not restart Docker |

Only ask a clarifying question if the requested action is destructive, conflicts happen, or a safety guard fails.

## Preflight before running update

The script is responsible for hard checks, but the agent must verify the script still contains guards for:

- DB directory exists.
- `db.sqlite3` exists.
- `db.sqlite3` is non-empty.
- config directory exists.
- `config.yaml` exists.
- timestamped backup under `/data/fast-note-sync/backups/database/`.
- compose mount checks.
- SQLite hard-fail guard check in `internal/dao/dao.go`.

If the script no longer checks these, repair it before updating.

## Run commands

### Docker image update only

Say what will happen, then run:

```bash
bash docker/safe_update.sh
```

### Origin pull update

Say what will happen, then run:

```bash
GIT_PULL=1 bash docker/safe_update.sh
```

### Upstream merge update

Say what will happen, then run:

```bash
UPSTREAM=1 bash docker/safe_update.sh
```

If merge conflicts happen, stop normal update flow. Resolve conflicts while preserving local safety patches, then run:

```bash
bash docker/safe_update.sh
```

## Preserve these local safety patches

After any upstream merge, ensure these remain true:

- `docker/docker-compose.yaml` uses image/tag intentionally selected by the repo/user.
- `docker/docker-compose.yaml` has `restart: unless-stopped`.
- Host ports remain `9002:9000` and `9003:9001` unless user explicitly changes them.
- Storage mount uses `${FNS_DATA_DIR:-/data/fast-note-sync}/storage/`.
- Config mount uses `${FNS_DATA_DIR:-/data/fast-note-sync}/config/`.
- `docker/safe_update.sh` verifies DB/config and creates backup before Docker restart.
- `internal/dao/dao.go` refuses missing SQLite files instead of auto-creating them.
- `AGENTS.md` points agents to the production runbook.
- `docs/PRODUCTION_UPDATE_RUNBOOK.md` remains present.

## If update fails

Do not try random fixes. Classify the failure:

1. Missing or empty DB: stop. Do not start Docker. Ask user how to restore from backup.
2. Missing config: stop. Do not start Docker. Ask user to locate old config.
3. Git conflict: resolve preserving safety patches, then rerun safe script.
4. Docker pull failure: leave existing container/data alone; report failure.
5. Docker start failure: inspect logs and mounts; do not reset password.

## If login fails after update

Assume wrong DB or wrong mount first.

Safe investigation order:

1. Check compose mounts point to `/data/fast-note-sync`.
2. Check `db.sqlite3` and user DB files still exist under `/data/fast-note-sync/storage/database/`.
3. Check container is using `/fast-note-sync/config/config.yaml`.
4. Check Docker logs for SQLite path errors.
5. Only if user explicitly asks, consider password reset.

Never create a new DB to fix login.

## Final response format

When done, report briefly:

```text
Update type: <docker image | origin pull | upstream merge>
Backup: <path from script output>
Docker: <running or failed>
Data root: /data/fast-note-sync
Notes: <any warnings>
```

If stopped for safety, say exactly which guard failed and what must be confirmed before continuing.
