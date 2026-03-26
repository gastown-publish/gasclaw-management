#!/bin/bash
# Resource metrics collection
# Output JSON for dashboards/monitoring
# Usage: ./resource-metrics.sh

METRICS_FILE="/tmp/gasclaw-metrics.json"

# Disk usage
DISK_TOTAL=$(df -BG / | awk 'NR==2 {print $2}' | sed 's/G//')
DISK_USED=$(df -BG / | awk 'NR==2 {print $3}' | sed 's/G//')
DISK_AVAIL=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')

# Memory (if available)
if [ -f /proc/meminfo ]; then
    MEM_TOTAL=$(free -m | awk 'NR==2 {print $2}')
    MEM_USED=$(free -m | awk 'NR==2 {print $3}')
    MEM_AVAIL=$(free -m | awk 'NR==2 {print $7}')
else
    MEM_TOTAL="N/A"
    MEM_USED="N/A"
    MEM_AVAIL="N/A"
fi

# Gateway health
GATEWAY_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:18798/health 2>/dev/null || echo "000")
if [ "$GATEWAY_STATUS" = "200" ]; then
    GATEWAY_HEALTH="healthy"
else
    GATEWAY_HEALTH="unhealthy"
fi

# Git status
if git -C /workspace/gt rev-parse --git-dir >/dev/null 2>&1; then
    GIT_STATUS="ready"
    GIT_AHEAD=$(git -C /workspace/gt rev-list --count @{u}..HEAD 2>/dev/null || echo "0")
else
    GIT_STATUS="not-ready"
    GIT_AHEAD="0"
fi

# Output JSON
cat > "$METRICS_FILE" <<EOF
{
  "timestamp": "$(date -Iseconds)",
  "container": "$(hostname)",
  "disk": {
    "total_gb": $DISK_TOTAL,
    "used_gb": $DISK_USED,
    "avail_gb": $DISK_AVAIL
  },
  "memory": {
    "total_mb": $MEM_TOTAL,
    "used_mb": $MEM_USED,
    "avail_mb": $MEM_AVAIL
  },
  "services": {
    "gateway": "$GATEWAY_HEALTH"
  },
  "git": {
    "status": "$GIT_STATUS",
    "commits_ahead": $GIT_AHEAD
  }
}
EOF

cat "$METRICS_FILE"