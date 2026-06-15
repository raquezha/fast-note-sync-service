#!/usr/bin/env bash
# backup.sh: Periodic backup of Obsidian notes and Fast Note Sync data.

set -euo pipefail

# Configuration
BACKUP_ROOT="${HOME}/backups/daily"
OBSIDIAN_VAULT="${HOME}/RQZ/notes"
FNS_DATA_DIR="/data/fast-note-sync"
HOMELAB_DIR="${HOME}/homelab"
RETENTION_DAYS=7
STAMP="$(date +%Y%m%d-%H%M%S)"
DEST="$BACKUP_ROOT/$STAMP"

echo "Starting daily backup: $STAMP"

# Ensure backup directory exists
mkdir -p "$DEST"

# 1. Backup Obsidian Notes
if [ -d "$OBSIDIAN_VAULT" ]; then
    echo "Backing up Obsidian vault: $OBSIDIAN_VAULT"
    tar -czf "$DEST/obsidian_notes.tar.gz" -C "$(dirname "$OBSIDIAN_VAULT")" "$(basename "$OBSIDIAN_VAULT")"
else
    echo "Warning: Obsidian vault not found at $OBSIDIAN_VAULT"
fi

# 2. Backup Fast Note Sync Data
if [ -d "$FNS_DATA_DIR" ]; then
    echo "Backing up Fast Note Sync data: $FNS_DATA_DIR"
    # Note: Requires root permissions to read /data
    tar -czf "$DEST/fast_note_sync_data.tar.gz" -C "$(dirname "$FNS_DATA_DIR")" "$(basename "$FNS_DATA_DIR")"
else
    echo "Warning: Fast Note Sync data not found at $FNS_DATA_DIR"
fi

# 3. Backup Homelab Configs
if [ -d "$HOMELAB_DIR" ]; then
    echo "Backing up homelab configs: $HOMELAB_DIR"
    tar -czf "$DEST/homelab_configs.tar.gz" -C "$(dirname "$HOMELAB_DIR")" "$(basename "$HOMELAB_DIR")"
fi

# 4. Cleanup old backups
echo "Cleaning up backups older than $RETENTION_DAYS days..."
find "$BACKUP_ROOT" -maxdepth 1 -type d -mtime +"$RETENTION_DAYS" -exec rm -rf {} +

echo "Backup complete: $DEST"
