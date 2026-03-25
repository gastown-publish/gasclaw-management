#!/usr/bin/env bash
# Hourly: send progress report request to each bot topic, using existing Telethon session
set -euo pipefail

LOCK=/tmp/gastown-hourly-report.lock
exec 200>"$LOCK"
if ! flock -n 200; then
  echo "$(date -Is) hourly-report: skipped (another run active)" >&2
  exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MGMT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG="$MGMT_ROOT/config/forum_health.json"
SESSION="/home/nic/gasclaw-workspace/telegram-test/tg_test_session.session"

python3 << PYEOF
import asyncio, json, os, sys
from telethon import TelegramClient

SESSION = "$SESSION"
API_ID = 29672461
API_HASH = "0e0b535e8e0db252f86f0a6a8de3624e"
GROUP_ID = -1003810709807

with open("$CONFIG") as f:
    config = json.load(f)

PING = config["ping_message"]

async def main():
    client = TelegramClient(SESSION, API_ID, API_HASH)
    await client.start()
    group = await client.get_entity(GROUP_ID)
    
    for topic in config["topics"]:
        tid = topic["topic_id"]
        label = topic["label"]
        optional = topic.get("optional", False)
        
        if optional:
            print(f"  skip {label} (optional)")
            continue
        
        try:
            await client.send_message(group, PING, reply_to=tid)
            print(f"  sent to {label} (topic {tid})")
        except Exception as e:
            print(f"  FAIL {label}: {e}")
    
    await client.disconnect()
    print("done")

asyncio.run(main())
PYEOF
