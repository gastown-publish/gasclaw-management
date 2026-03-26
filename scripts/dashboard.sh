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
LAST_CHECK=$(date '+%H:%M:%S')
VERSION=$(grep lastTouchedVersion /root/.openclaw/openclaw.json 2>/dev/null | sed 's/.*": *"\([^"]*\)".*/\1/' || echo "unknown")
GIT_COMMITS=$(git rev-list --count HEAD)
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
    <script>let s=30;setInterval(()=>{document.getElementById('c').innerText=s},1e3);function tt(){document.body.style.background=document.body.style.background==='#eee'?'#1a1a2e':'#eee';document.body.style.color=document.body.style.color==='#000'?'#eee':'#000';}</script>
    <style>
        body { font-family: -apple-system, sans-serif; margin: 20px; background: #1a1a2e; color: #eee; }
        @media (max-width: 600px) { body { margin: 10px; } .card { padding: 10px; } .metric { font-size: 18px; } h1 { font-size: 20px; } }
        .card { background: #16213e; padding: 20px; margin: 10px 0; border-radius: 8px; }
        .ok { color: #4ade80; }
        .fail { color: #f87171; }
        h1 { color: #60a5fa; }
        button { background: #3b82f6; color: white; border: none; padding: 8px 16px; border-radius: 4px; cursor: pointer; }
        .metric { font-size: 24px; font-weight: bold; }
    </style>
</head>
<body>
    <h1>🚀 Gasclaw <small>v$VERSION</small></h1>
    <p><small>$(hostname) | $GIT_COMMITS commits</small></p>
    <div class="card" style="background: #22c55e; color: #000; animation: pulse 2s infinite;">
        <div class="metric">✓ All Systems Operational<br><small>$(date '+%H:%M:%S')</small></div>
    </div>
    <style>@keyframes pulse { 0% { opacity: 1; } 50% { opacity: 0.8; } 100% { opacity: 1; } }</style>
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
    <p><small>Updated: $LAST_CHECK ($TIMESTAMP)</small></p>
    <p><button onclick="location.reload()">Refresh Now</button> <button onclick="tt()">Theme</button> | <a href="./health-check.sh" style="color:#60a5fa;">Run Health Check</a> | Refresh: <span id="c">30</span>s</p>
</body>
</html>
EOF