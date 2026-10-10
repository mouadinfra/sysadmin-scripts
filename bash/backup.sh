#!/usr/bin/env bash
# backup.sh - create a dated .tar.gz backup of a directory and keep the last N copies.
# Usage: ./backup.sh <source_dir> <dest_dir> [keep=7]
# Cron example (daily at 02:00):
#   0 2 * * * /opt/scripts/backup.sh /etc /var/backups/etc 7 >> /var/log/backup.log 2>&1
set -euo pipefail

SRC="${1:?Usage: $0 <source_dir> <dest_dir> [keep]}"
DEST="${2:?Usage: $0 <source_dir> <dest_dir> [keep]}"
KEEP="${3:-7}"

[ -d "$SRC" ] || { echo "Source '$SRC' does not exist" >&2; exit 1; }
mkdir -p "$DEST"

NAME="$(basename "$SRC")"
ARCHIVE="$DEST/${NAME}_$(date +%Y-%m-%d_%H%M%S).tar.gz"

echo "[$(date '+%F %T')] Backing up $SRC -> $ARCHIVE"
tar -czf "$ARCHIVE" -C "$(dirname "$SRC")" "$NAME"
sha256sum "$ARCHIVE" > "$ARCHIVE.sha256"
echo "[$(date '+%F %T')] Done: $(du -h "$ARCHIVE" | cut -f1)"

# Rotation: keep only the newest $KEEP archives
ls -1t "$DEST/${NAME}"_*.tar.gz 2>/dev/null | tail -n +"$((KEEP + 1))" | while read -r old; do
    echo "[$(date '+%F %T')] Removing old backup $old"
    rm -f -- "$old" "$old.sha256"
done
