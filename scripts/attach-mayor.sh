#!/usr/bin/env bash
# Interactive attach to the Gas Town Mayor session inside a Gasclaw container.
# Default: gasclaw-mgmt (gasclaw-management). Override with first argument.
#
# Usage:
#   ./scripts/attach-mayor.sh
#   ./scripts/attach-mayor.sh gasclaw-dev
#
# Detach without killing the session: usual tmux/terminal detach for your setup
# (often Ctrl+B D if the attach runs inside tmux, or exit the attach UI per gt).

set -euo pipefail

CONTAINER="${1:-gasclaw-mgmt}"
GT_DIR="${GT_DIR:-/workspace/gt}"

if ! docker ps --format '{{.Names}}' | grep -qx "$CONTAINER"; then
  echo "Container not running: $CONTAINER" >&2
  echo "Running: docker ps --format '{{.Names}}' | grep gasclaw" >&2
  exit 1
fi

exec docker exec -it "$CONTAINER" bash -lc "cd '$GT_DIR' && exec gt mayor attach"
