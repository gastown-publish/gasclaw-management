#!/bin/bash
# Backup metrics JSON to dated file
# Usage: ./backup-metrics.sh [destination_dir]

DEST_DIR="${1:-/tmp/gasclaw-metrics-backups}"
METRICS_FILE="/tmp/gasclaw-metrics.json"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

mkdir -p "$DEST_DIR"

if [ -f "$METRICS_FILE" ]; then
    BACKUP_FILE="$DEST_DIR/metrics_${TIMESTAMP}.json"
    cp "$METRICS_FILE" "$BACKUP_FILE"
    echo "Backed up to: $BACKUP_FILE"
    
    # Keep only last 24 backups
    cd "$DEST_DIR"
    ls -t metrics_*.json 2>/dev/null | tail -n +25 | xargs -r rm
else
    echo "No metrics file found at $METRICS_FILE"
    exit 1
fi