#!/usr/bin/env bash
# Full stack: (0) MiniMax fix on every Gasclaw container, (1) in-mgmt gateway sweep + mgmt MiniMax,
# (2) host-side MiniMax audit (or in-mgmt peer audit if Docker socket is mounted in mgmt).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"$SCRIPT_DIR/apply_minimax_fix_all_gasclaw.sh"
"$SCRIPT_DIR/run_inside_mgmt_health_suite.sh"
# Gateway probes + openclaw CLI can rewrite agent models.json — re-apply MiniMax before final audit.
"$SCRIPT_DIR/apply_minimax_fix_all_gasclaw.sh"
"$SCRIPT_DIR/check_all_containers_minimax.sh"
