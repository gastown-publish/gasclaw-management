#!/usr/bin/env bash
# Hourly forum health + on failure notify gasclaw-mgmt OpenClaw (infra) for mayor remediation.
# Intended for crontab: 0 * * * * .../run_hourly_forum_health_with_escalation.sh >> /tmp/forum-health.log 2>&1

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MGMT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

export GASCLAW_ESCALATE_ON_FAILURE="${GASCLAW_ESCALATE_ON_FAILURE:-1}"
export GASCLAW_MGMT_CONTAINER="${GASCLAW_MGMT_CONTAINER:-gasclaw-mgmt}"
export GASCLAW_ESCALATE_AGENT="${GASCLAW_ESCALATE_AGENT:-infra}"
export GASTOWN_TELETHON_ROOT="${GASTOWN_TELETHON_ROOT:-$(cd "$MGMT_ROOT/.." && pwd)/telethon}"
export TELETHON_FORUM_HEALTH_CONFIG="${TELETHON_FORUM_HEALTH_CONFIG:-$MGMT_ROOT/config/forum_health.json}"
export GASCLAW_FORUM_HEALTH_LOG="${GASCLAW_FORUM_HEALTH_LOG:-/tmp/forum-health-last-run.log}"

exec "$SCRIPT_DIR/forum_health_escalate.sh"
