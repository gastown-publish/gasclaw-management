#!/bin/bash
# Log rotation for Gasclaw platform
# Run daily via cron: 0 2 * * * /workspace/gt/scripts/log-rotate.sh
set -e

LOG_DIRS=(
    "/root/.openclaw/logs"
    "/workspace/gt/.beads"
)

MAX_SIZE_MB=10
MAX_DAYS=7

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') LOG_ROTATE: $1"
}

rotate_log() {
    local file="$1"
    if [ -f "$file" ]; then
        local size_mb=$(du -m "$file" 2>/dev/null | cut -f1)
        if [ "$size_mb" -gt "$MAX_SIZE_MB" ]; then
            log "Rotating $file (${size_mb}MB)"
            mv "$file" "${file}.$(date +%Y%m%d-%H%M%S)"
            gzip "${file}.$(date +%Y%m%d-%H%M%S)" &
        fi
    fi
}

# Rotate specific log files
rotate_log "/workspace/gt/.beads/dolt-server.log"
rotate_log "/workspace/gt/.beads/interactions.jsonl"

# Clean old rotated logs
find /workspace/gt/.beads -name "*.gz" -mtime +$MAX_DAYS -delete 2>/dev/null || true

log "Log rotation complete"