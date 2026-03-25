#!/usr/bin/env bash
# Periodic forum health: ping each Gasclaw bot in its Telegram topic (human Telethon session).
# Requires: gastown-publish/telethon clone + .env with TELEGRAM_API_ID, TELEGRAM_API_HASH, TELEGRAM_PHONE, TELEGRAM_GROUP_ID, TELETHON_SESSION_PATH
#
# Cron example (every 15 minutes):
#   */15 * * * * /home/nic/gasclaw-workspace/gasclaw-management/scripts/forum_health.sh >> /tmp/forum-health.log 2>&1

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MGMT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Default: sibling directory ../telethon (same parent as gasclaw-management)
TELETHON_ROOT="${GASTOWN_TELETHON_ROOT:-$(cd "$MGMT_ROOT/.." && pwd)/telethon}"
export TELETHON_FORUM_HEALTH_CONFIG="${TELETHON_FORUM_HEALTH_CONFIG:-$MGMT_ROOT/config/forum_health.json}"

if [[ ! -d "$TELETHON_ROOT" ]]; then
  echo "error: telethon repo not found at $TELETHON_ROOT" >&2
  echo "  Clone: git clone https://github.com/gastown-publish/telethon.git \"$TELETHON_ROOT\"" >&2
  echo "  Or set GASTOWN_TELETHON_ROOT to your clone path." >&2
  exit 1
fi

if [[ -x "$TELETHON_ROOT/.venv/bin/gastown-telethon-forum-health" ]]; then
  exec "$TELETHON_ROOT/.venv/bin/gastown-telethon-forum-health"
fi

if [[ -x "$TELETHON_ROOT/.venv/bin/python" ]]; then
  exec "$TELETHON_ROOT/.venv/bin/python" -m gastown_telethon.scripts.forum_health
fi

echo "error: install telethon repo: cd \"$TELETHON_ROOT\" && python3 -m venv .venv && .venv/bin/pip install -e ." >&2
exit 1
