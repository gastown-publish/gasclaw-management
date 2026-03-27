#!/usr/bin/env bash
# Apply fix_openclaw_minimax_local.py inside every Gasclaw stack container (run on host).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FIX="$SCRIPT_DIR/fix_openclaw_minimax_local.py"
CONTAINERS=(
  gasclaw-minimax
  gasclaw-dev
  gasclaw-gasskill
  gasclaw-context
  gasclaw-mgmt
)
for c in "${CONTAINERS[@]}"; do
  if docker exec "$c" true 2>/dev/null; then
    echo "=== apply MiniMax fix: $c ==="
    docker cp "$FIX" "$c:/tmp/fix_openclaw_minimax_local.py"
    docker exec "$c" python3 /tmp/fix_openclaw_minimax_local.py 2>&1 | tail -2
  else
    echo "SKIP (not running): $c"
  fi
done
