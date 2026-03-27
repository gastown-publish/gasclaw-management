#!/usr/bin/env bash
# Check (1) gasclaw-mgmt OpenClaw Telegram (bot API) and (2) optional Telethon Docker ping (human MTProto).
# No credentials are printed. Telethon uses bind mounts only — see gastown-publish/telethon docker-compose.yml.
set -euo pipefail

CONTAINER="${GASCLAW_MGMT_CONTAINER:-gasclaw-mgmt}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MGMT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TELETHON_REPO="${GASTOWN_TELETHON_ROOT:-$(cd "$MGMT_ROOT/.." && pwd)/telethon}"

echo "=== 1) ${CONTAINER}: OpenClaw Telegram (bot API, @gasclaw_mgmt_bot path) ==="
if docker exec "$CONTAINER" sh -c 'command -v openclaw >/dev/null 2>&1'; then
  docker exec "$CONTAINER" openclaw channels status --probe 2>&1 || true
else
  echo "openclaw not found in container"
fi

echo ""
echo "=== 2) Telethon in Docker (human session — bind-mounted env + session dir) ==="
if [[ -d "$TELETHON_REPO" && -f "$TELETHON_REPO/docker-compose.yml" ]]; then
  ENV_FILE="${TELETHON_ENV_FILE:-$TELETHON_REPO/.env}"
  if [[ ! -f "$ENV_FILE" ]]; then
    echo "Skip: no env file at $ENV_FILE (set TELETHON_ENV_FILE)"
  else
    SP=$(grep -m1 '^TELETHON_SESSION_PATH=' "$ENV_FILE" | cut -d= -f2- | tr -d '\r' | sed 's/^"//;s/"$//')
    HOST_DATA=$(dirname "$SP")
    BASE=$(basename "$SP")
    export TELETHON_ENV_FILE="$ENV_FILE"
    export TELETHON_HOST_DATA_DIR="$HOST_DATA"
    export TELETHON_CONTAINER_SESSION_PATH="/data/$BASE"
    echo "Using TELETHON_HOST_DATA_DIR=$HOST_DATA -> /data , session basename=$BASE"
    (cd "$TELETHON_REPO" && timeout 120 docker compose run --rm --entrypoint gastown-telethon-ping forum-health) || echo "Telethon Docker run failed (network, FloodWait, or compose)."
  fi
else
  echo "Skip: telethon repo not at $TELETHON_REPO (set GASTOWN_TELETHON_ROOT)"
fi

echo ""
echo "Note: Bot API (mgmt) and MTProto (Telethon) are different Telegram APIs."
echo "For mgmt to post in the group, configure channels.telegram in OpenClaw (see scripts/apply-mgmt-telegram-token.sh)."
