#!/usr/bin/env bash
# Run forum_health.sh; on failure optionally notify gasclaw-mgmt OpenClaw agent (default: infra)
# so it can watch Gastown mayor, fix issues, and retest. See docs/mayor-escalation.md
#
# Usage:
#   GASCLAW_ESCALATE_ON_FAILURE=1 ./scripts/forum_health_escalate.sh
#
# Optional env:
#   GASCLAW_ESCALATE_ON_FAILURE=1     # required to trigger docker exec + openclaw agent
#   GASCLAW_MGMT_CONTAINER=gasclaw-mgmt
#   GASCLAW_ESCALATE_AGENT=infra      # or main
#   GASCLAW_FORUM_HEALTH_LOG=/tmp/forum-health-last-run.log   # captured output

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG="${GASCLAW_FORUM_HEALTH_LOG:-/tmp/forum-health-last-run.log}"

set +e
"$SCRIPT_DIR/forum_health.sh" 2>&1 | tee "$LOG"
RC=${PIPESTATUS[0]}
set -e

if [[ "$RC" -eq 0 ]]; then
  exit 0
fi

if [[ "${GASCLAW_ESCALATE_ON_FAILURE:-0}" != "1" ]]; then
  exit "$RC"
fi

CONTAINER="${GASCLAW_MGMT_CONTAINER:-gasclaw-mgmt}"
AGENT="${GASCLAW_ESCALATE_AGENT:-infra}"

if ! command -v docker >/dev/null 2>&1; then
  echo "escalation: docker not found; leaving log at $LOG" >&2
  exit "$RC"
fi

if ! docker ps --format '{{.Names}}' 2>/dev/null | grep -qx "$CONTAINER"; then
  echo "escalation: container $CONTAINER not running; leaving log at $LOG" >&2
  exit "$RC"
fi

MSG=$(printf '%s\n\n%s\n' \
  "FORUM_HEALTH_FAILURE exit=$RC at $(date -Is)

You must: (1) watch Gastown mayor — cd /workspace/gt && gt mayor status; (2) fix Telegram/OpenClaw gateway per gasclaw-management HANDOFF.md and docs/forum-health.md; (3) re-run forum_health.sh until exit 0; (4) report in forum topic 921.

--- log tail ---" \
  "$(tail -c 5000 "$LOG" 2>/dev/null || echo "(no log)")")

printf '%s' "$MSG" | docker exec -i "$CONTAINER" env AGENT="$AGENT" bash -lc \
  'openclaw agent --local --agent "$AGENT" --message "$(cat)"'

echo "escalation: notified agent=$AGENT in container=$CONTAINER" >&2
exit "$RC"
