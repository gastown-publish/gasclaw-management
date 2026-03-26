#!/bin/bash
# Dashboard - serves simple HTML metrics dashboard

METRICS_FILE="/tmp/gasclaw-metrics.json"
if [ -f "$METRICS_FILE" ]; then
    DISK_AVAIL=$(grep 'avail_gb' "$METRICS_FILE" | head -1 | sed 's/.*: *\([0-9]*\).*/\1/')
    DISK_USED=$(grep used_gb "$METRICS_FILE" | head -1 | sed 's/.*: *\([0-9]*\).*/\1/')
    DISK_TOTAL=$(grep total_gb "$METRICS_FILE" | head -1 | sed 's/.*: *\([0-9]*\).*/\1/')
    DISK_PERC=$((DISK_USED * 100 / DISK_TOTAL))
    GATEWAY=$(grep '"gateway"' "$METRICS_FILE" | sed 's/.*gateway.*: *"\([^"]*\)".*/\1/')
    GIT_STATUS=$(grep '"status"' "$METRICS_FILE" | head -1 | sed 's/.*status.*: *"\([^"]*\)".*/\1/')
    TIMESTAMP=$(grep 'timestamp' "$METRICS_FILE" | sed 's/.*timestamp.*: *"\([^"]*\)".*/\1/')
    MEM_USED=$(grep used_mb "$METRICS_FILE" | head -1 | sed 's/.*: *\([0-9]*\).*/\1/')
    MEM_TOTAL=$(grep total_mb "$METRICS_FILE" | head -1 | sed 's/.*: *\([0-9]*\).*/\1/')
    MEM_PERC=$((MEM_USED * 100 / MEM_TOTAL))
    COMMITS_AHEAD=$(grep commits_ahead "$METRICS_FILE" | sed 's/.*: *\([0-9]*\).*/\1/')
else
    DISK_AVAIL="N/A"
    GATEWAY="unknown"
    GIT_STATUS="unknown"
    TIMESTAMP="never"
fi

# Get beads status
BEADS_STATUS=$(bd list 2>&1 | head -1)
if echo "$BEADS_STATUS" | grep -q "No issues"; then
    BEADS_COUNT="0 issues"
    BEADS_CLASS="ok"
else
    BEADS_COUNT="$BEADS_STATUS"
    BEADS_CLASS="fail"
fi

# Get uptime
UPTIME=$(cat /proc/uptime | awk '{printf "%.1f days", $1/86400}')
[ -z "$UPTIME" ] && UPTIME="unknown"

[ -z "$DISK_AVAIL" ] && DISK_AVAIL="N/A"
[ -z "$GATEWAY" ] && GATEWAY="unknown"
[ -z "$GIT_STATUS" ] && GIT_STATUS="unknown"

GATEWAY_CLASS="ok"
[ "$GATEWAY" != "healthy" ] && GATEWAY_CLASS="fail"

cat <<EOF
<!DOCTYPE html>
<html>
<head>
    <title>Gasclaw Dashboard</title>
    <meta http-equiv="refresh" content="30">
    <style>
        body { font-family: -apple-system, sans-serif; margin: 40px; background: #1a1a2e; color: #eee; }
        .card { background: #16213e; padding: 20px; margin: 10px 0; border-radius: 8px; }
        .ok { color: #4ade80; }
        .fail { color: #f87171; }
        h1 { color: #60a5fa; }
        .metric { font-size: 24px; font-weight: bold; }
    </style>
</head>
<body>
    <h1>🚀 Gasclaw Platform Dashboard <small>$(hostname)</small></h1>
    <div class="card">
        <h2>Disk</h2>
        <div class="metric">${DISK_PERC}% used (${DISK_USED}GB / ${DISK_TOTAL}GB)</div>
    </div>
    <div class="card">
        <h2>Services</h2>
        <div class="metric $GATEWAY_CLASS">
            Gateway: $GATEWAY
        </div>
    </div>
    <div class="card">
        <h2>Beads</h2>
        <div class="metric $BEADS_CLASS">$BEADS_COUNT</div>
    </div>
    <div class="card">
        <h2>Uptime</h2>
        <div class="metric">$UPTIME</div>
    </div>
    <div class="card">
        <h2>Memory</h2>
        <div class="metric">${MEM_PERC}% used (${MEM_USED}MB / ${MEM_TOTAL}MB)</div>
    </div>
    <div class="card">
        <h2>Git</h2>
        <div class="metric">${COMMITS_AHEAD} commits ahead</div>
    </div>
    <p><small>Updated: $TIMESTAMP</small></p>
</body>
</html>
EOF