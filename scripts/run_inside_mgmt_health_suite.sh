#!/usr/bin/env bash
# Run the full in-mgmt suite from the **host**: copies MiniMax fix into the container, then streams inside_mgmt_health_suite.sh.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONTAINER="${GASCLAW_MGMT_CONTAINER:-gasclaw-mgmt}"

docker cp "$SCRIPT_DIR/fix_openclaw_minimax_local.py" "$CONTAINER:/tmp/fix_openclaw_minimax_local.py"
docker exec -i "$CONTAINER" bash -s < "$SCRIPT_DIR/inside_mgmt_health_suite.sh"
