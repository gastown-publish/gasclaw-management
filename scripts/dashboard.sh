#!/bin/bash
# Dashboard - serves simple HTML metrics dashboard
# Usage: ./dashboard.sh [--serve]
# Or just generate: ./dashboard.sh > /tmp/dashboard.html

. "$(dirname "$0")/resource-metrics.sh" >/dev/null 2>&1

METRICS=$(cat /tmp/gasclaw-metrics.json 2>/dev/null || echo '{}')

# Generate HTML
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
    <h1>🚀 Gasclaw Platform Dashboard</h1>
    <div class="card">
        <h2>Disk</h2>
        <div class="metric">$(echo "$METRICS" | jq -r '.disk.avail_gb // "N/A"') GB available</div>
    </div>
    <div class="card">
        <h2>Services</h2>
        <div class="metric $(echo "$METRICS" | jq -r '.services.gateway == "healthy" | if . then "ok" else "fail" end')">
            Gateway: $(echo "$METRICS" | jq -r '.services.gateway // "unknown"')
        </div>
    </div>
    <div class="card">
        <h2>Git</h2>
        <div class="metric">$(echo "$METRICS" | jq -r '.git.status // "unknown"')</div>
    </div>
    <p><small>Updated: $(echo "$METRICS" | jq -r '.timestamp // "never"')</small></p>
</body>
</html>
EOF