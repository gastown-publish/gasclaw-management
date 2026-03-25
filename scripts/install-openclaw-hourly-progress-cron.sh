#!/usr/bin/env bash
# Register hourly OpenClaw cron jobs so each gateway nudges its primary agent to report progress.
# This runs INSIDE each container (docker exec). It complements Telethon forum_health.sh on the host.
#
# Usage:
#   ./scripts/install-openclaw-hourly-progress-cron.sh           # print commands (dry run)
#   ./scripts/install-openclaw-hourly-progress-cron.sh --apply   # run openclaw cron add on each container
#
# Prerequisites: docker CLI; containers running; openclaw cron available in image.
# If a job with the same --name already exists, remove it first: openclaw cron list && openclaw cron remove <id>

set -euo pipefail

CRON_EXPR="${OPENCLAW_PROGRESS_CRON:-0 * * * *}"
JOB_NAME="${OPENCLAW_PROGRESS_JOB_NAME:-hourly-progress}"
AGENT="${OPENCLAW_PROGRESS_AGENT:-main}"
MSG="${OPENCLAW_PROGRESS_MESSAGE:-[Scheduled hourly] Brief progress report: current work, blockers, and next steps. Reply in this forum topic.}"

CONTAINERS=(
  gasclaw-dev
  gasclaw-minimax
  gasclaw-gasskill
  gasclaw-mgmt
)

run_one() {
  local c=$1
  if ! docker ps --format '{{.Names}}' 2>/dev/null | grep -qx "$c"; then
    echo "skip (container not running): $c" >&2
    return 0
  fi
  docker exec "$c" bash -lc "openclaw cron add --name '$JOB_NAME' --cron '$CRON_EXPR' --agent '$AGENT' --message $(printf '%q' "$MSG") --no-deliver"
}

print_cmd() {
  local c=$1
  echo "docker exec $c bash -lc \"openclaw cron add --name '$JOB_NAME' --cron '$CRON_EXPR' --agent '$AGENT' --message $(printf '%q' "$MSG") --no-deliver\""
}

main() {
  if [[ "${1:-}" == "--apply" ]]; then
    for c in "${CONTAINERS[@]}"; do
      echo "=== $c ===" >&2
      run_one "$c" || echo "warning: failed for $c" >&2
    done
    echo "Done. Verify: docker exec <container> openclaw cron list" >&2
    return 0
  fi

  echo "Dry run — hourly OpenClaw cron (UTC: $CRON_EXPR). Set OPENCLAW_PROGRESS_* env vars to override."
  echo "Add --apply to execute on running containers."
  echo ""
  for c in "${CONTAINERS[@]}"; do
    print_cmd "$c"
  done
}

main "$@"
