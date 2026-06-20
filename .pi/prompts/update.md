---
description: Safely update this Fast Note Sync Service deployment without losing SQLite data
argument-hint: "[docker|repo|origin|upstream|check]"
---
Use the repo-local `fns-update` skill for this request.

User update intent: `${1:-full}`
All user arguments: `$ARGUMENTS`

Default behavior when no argument is provided:
- Treat `/update` as the full safe production update.
- Full safe update means merge from original `upstream` and then pull/restart Docker through the safe script.
- Use: `UPSTREAM=1 bash docker/safe_update.sh`
- Do not ask the user to choose unless a safety check fails or git conflicts occur.

Argument behavior:
- `/update` or `/update full`: run the full safe update with `UPSTREAM=1 bash docker/safe_update.sh`.
- `/update upstream` or `/update repo`: same as full safe update.
- `/update origin`: pull from origin with `GIT_PULL=1 bash docker/safe_update.sh`.
- `/update docker`: Docker image/tag update only with `bash docker/safe_update.sh`.
- `/update check`: only inspect safety state; do not restart Docker.

Before doing anything, read:
1. `.pi/skills/fns-update/SKILL.md`
2. `AGENTS.md`
3. `docs/PRODUCTION_UPDATE_RUNBOOK.md`
4. `docker/safe_update.sh`
5. `docker/docker-compose.yaml`

Hard rules:
- Never manually run Docker down/up.
- Never reset password during update.
- Never start if `/data/fast-note-sync/storage/database/db.sqlite3` is missing or empty.
- Always rely on `docker/safe_update.sh` for update execution.

Proceed with the mapped safe command unless a guard fails.
