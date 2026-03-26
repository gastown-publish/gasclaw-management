#!/usr/bin/env bash
# Hourly agent health check + status report
# Uses Telethon to send structured prompt to each topic, waits 5min, inspects responses.
# Cron: 0 * * * *
set -euo pipefail

LOCK=/tmp/gastown-hourly-report.lock
exec 200>"$LOCK"
if ! flock -n 200; then
  echo "$(date -Is) hourly-report: skipped (another run active)" >&2
  exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MGMT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SESSION="/home/nic/gasclaw-workspace/telegram-test/tg_test_session.session"
PYTHON="/home/nic/gasclaw-workspace/telethon/.venv/bin/python3"
LOG="/tmp/hourly-report.log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

echo "[$TIMESTAMP] === HOURLY AGENT REPORT START ==="

# Step 1: Send structured status request to each bot topic
echo "[$TIMESTAMP] Step 1: Sending status requests..."
$PYTHON << 'PYEOF'
import asyncio, json, os, sys
from telethon import TelegramClient

SESSION = os.environ.get("SESSION", "/home/nic/gasclaw-workspace/telegram-test/tg_test_session.session")
API_ID = 29672461
API_HASH = "0e0b535e8e0db252f86f0a6a8de3624e"
GROUP_ID = -1003810709807

TOPICS = {
    918: {"bot": "gasclaw_master_bot", "label": "gasclaw", "mention": "@gasclaw_master_bot"},
    919: {"bot": "minimax_gastown_publish_bot", "label": "minimax", "mention": "@minimax_gastown_publish_bot"},
    920: {"bot": "gasskill_agent_bot", "label": "gasskill", "mention": "@gasskill_agent_bot"},
    921: {"bot": "gasclaw_mgmt_bot", "label": "mgmt", "mention": "@gasclaw_mgmt_bot"},
}

PROMPT = """Hourly status report. RULES: "none" is NOT acceptable for IMPROVEMENT — you MUST find something real. Use numbers everywhere.

STATUS: [online/degraded/error]
CONTAINER: [container name or ID]
REPO: [gastown-publish/<name>]
AGENTS: [count] — [list names]
METRICS:
  beads_closed: [number]
  issues_open: [number]
  commits_last_hour: [number]
  PRs_merged: [number]
  PRs_open: [number]
  tests_passing: [number or "unknown"]
WORK_SUMMARY: [2-3 bullet points with numbers — commits, PRs, issues, lines changed. If idle, state why and what you SHOULD be doing]
BLOCKERS: [specific technical blocker, or "clear"]
GOAL_NEXT_HOUR: [one specific, measurable deliverable you will complete]
PROJECT_GOAL: [the ultimate purpose of your assigned repo in one sentence]
IMPROVEMENT_PLAN:
  1. [concrete process/quality improvement]
  2. [concrete speed improvement]
  3. [concrete reliability improvement]

Do NOT say "none", "n/a", or "idle" without explanation. If you have no work, inspect your repo and find something to do."""

async def main():
    client = TelegramClient(SESSION, API_ID, API_HASH)
    await client.start()
    group = await client.get_entity(GROUP_ID)

    for tid, info in TOPICS.items():
        try:
            await client.send_message(group, PROMPT, reply_to=tid)
            print(f"  sent to {info['label']} (topic {tid})")
        except Exception as e:
            print(f"  FAIL {info['label']}: {e}")

    await client.disconnect()

asyncio.run(main())
PYEOF

# Step 2: Wait 5 minutes for bot responses
WAIT=300
echo "[$TIMESTAMP] Step 2: Waiting ${WAIT}s for bot responses..."
sleep $WAIT

# Step 3: Inspect responses and grade them
INSPECT_TS=$(date '+%Y-%m-%d %H:%M:%S')
echo "[$INSPECT_TS] Step 3: Inspecting responses..."
$PYTHON << 'PYEOF'
import asyncio, json, os, sys, time
from telethon import TelegramClient

SESSION = os.environ.get("SESSION", "/home/nic/gasclaw-workspace/telegram-test/tg_test_session.session")
API_ID = 29672461
API_HASH = "0e0b535e8e0db252f86f0a6a8de3624e"
GROUP_ID = -1003810709807

TOPICS = {
    918: {"bot": "gasclaw_master_bot", "label": "gasclaw"},
    919: {"bot": "minimax_gastown_publish_bot", "label": "minimax"},
    920: {"bot": "gasskill_agent_bot", "label": "gasskill"},
    921: {"bot": "gasclaw_mgmt_bot", "label": "mgmt"},
}

REQUIRED_FIELDS = ["STATUS:", "CONTAINER:", "REPO:", "AGENTS:", "LAST_WORK:", "BLOCKERS:", "IMPROVEMENT:"]

async def main():
    client = TelegramClient(SESSION, API_ID, API_HASH)
    await client.start()
    group = await client.get_entity(GROUP_ID)

    results = {"pass": 0, "fail": 0, "no_reply": 0, "wrong_bot": 0, "details": []}
    cutoff = time.time() - 360  # messages from last 6 min

    for tid, info in TOPICS.items():
        expected_bot = info["bot"]
        label = info["label"]
        found = False

        async for msg in client.iter_messages(group, reply_to=tid, limit=5):
            if msg.date.timestamp() < cutoff:
                continue

            is_bot = getattr(msg.sender, "bot", False)
            username = getattr(msg.sender, "username", "") if msg.sender else ""
            text = msg.text or ""

            if not is_bot:
                continue

            found = True
            if username != expected_bot:
                results["wrong_bot"] += 1
                results["details"].append(f"  ❌ {label}: WRONG BOT @{username} (expected @{expected_bot})")
                break

            # Check response quality
            fields_found = sum(1 for f in REQUIRED_FIELDS if f in text)
            has_status = "STATUS:" in text
            status_val = ""
            for line in text.split("\n"):
                if line.strip().startswith("STATUS:"):
                    status_val = line.split(":", 1)[1].strip().lower()

            if fields_found >= 5 and has_status:
                results["pass"] += 1
                status_icon = "✅" if "online" in status_val else "⚠️"
                results["details"].append(f"  {status_icon} {label}: @{username} — {fields_found}/7 fields, status={status_val}")
            elif fields_found >= 3:
                results["pass"] += 1
                results["details"].append(f"  ⚠️  {label}: @{username} — partial ({fields_found}/7 fields)")
            else:
                results["fail"] += 1
                snippet = text[:80].replace("\n", " ")
                results["details"].append(f"  ❌ {label}: @{username} — bad format ({fields_found}/7): {snippet}")
            break

        if not found:
            results["no_reply"] += 1
            results["details"].append(f"  ❌ {label}: NO REPLY from @{expected_bot}")

    # Print report
    total = results["pass"] + results["fail"] + results["no_reply"] + results["wrong_bot"]
    print(f"\n=== HOURLY REPORT: {results['pass']}/{total} PASS ===")
    for d in results["details"]:
        print(d)
    if results["no_reply"]:
        print(f"\n  ⚠️  {results['no_reply']} bot(s) did not reply — check gateway health")
    if results["wrong_bot"]:
        print(f"\n  ⚠️  {results['wrong_bot']} wrong-bot reply — check topic routing")
    print(f"=== END REPORT ===\n")

    await client.disconnect()

asyncio.run(main())
PYEOF

echo "[$(date '+%Y-%m-%d %H:%M:%S')] === HOURLY AGENT REPORT DONE ==="
