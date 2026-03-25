#!/usr/bin/env bash
# Restore @gasclaw_mgmt_bot Telegram polling inside gasclaw-mgmt when botToken is missing from openclaw.json.
#
# Get the token from @BotFather for @gasclaw_mgmt_bot, then either:
#   export GASCLAW_MGMT_TELEGRAM_BOT_TOKEN='123456:ABC...'
#   ./scripts/apply-mgmt-telegram-token.sh
# or:
#   mkdir -p ~/.config/gastown
#   echo -n '123456:ABC...' > ~/.config/gastown/gasclaw_mgmt_bot_token
#   chmod 600 ~/.config/gastown/gasclaw_mgmt_bot_token
#   ./scripts/apply-mgmt-telegram-token.sh
#
# Then run: openclaw channels status --probe (inside container)

set -euo pipefail

TOKEN="${GASCLAW_MGMT_TELEGRAM_BOT_TOKEN:-}"
if [[ -z "$TOKEN" && -f "${HOME}/.config/gastown/gasclaw_mgmt_bot_token" ]]; then
  TOKEN="$(tr -d '\n' < "${HOME}/.config/gastown/gasclaw_mgmt_bot_token")"
fi

if [[ -z "$TOKEN" ]]; then
  echo "error: set GASCLAW_MGMT_TELEGRAM_BOT_TOKEN or create ~/.config/gastown/gasclaw_mgmt_bot_token" >&2
  exit 1
fi

CONTAINER="${GASCLAW_MGMT_CONTAINER:-gasclaw-mgmt}"
PORT="${GASCLAW_MGMT_GATEWAY_PORT:-18798}"

docker exec "$CONTAINER" openclaw config set "channels.telegram.botToken" "$TOKEN"
docker exec "$CONTAINER" openclaw config set "channels.telegram.enabled" true --json
docker exec "$CONTAINER" openclaw config set "gateway.mode" local --json 2>/dev/null || true

docker exec "$CONTAINER" bash -c 'pkill -f openclaw-gateway 2>/dev/null || true; rm -f /root/.openclaw/gateway.lock'
sleep 2
docker exec "$CONTAINER" bash -c "nohup openclaw gateway run --port $PORT --allow-unconfigured >> /tmp/openclaw-gw.log 2>&1 &"
sleep 3
docker exec "$CONTAINER" curl -sf "http://127.0.0.1:$PORT/health" && echo " — gateway OK"
docker exec "$CONTAINER" openclaw channels status --probe 2>&1 | tail -5
