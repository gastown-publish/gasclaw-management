#!/usr/bin/env bash
# Cross-talk monitor: detect bots responding in wrong topics.
# Runs every 5 min via cron. On violation: alerts manager in topic 921 + auto-fixes.
#
# Cron: */5 * * * * /path/to/crosstalk-monitor.sh >> /tmp/crosstalk.log 2>&1
set -euo pipefail

PYTHON="/home/nic/gasclaw-workspace/telethon/.venv/bin/python3"
SESSION="/home/nic/gasclaw-workspace/telegram-test/tg_test_session.session"
TS=$(date '+%Y-%m-%d %H:%M:%S')

$PYTHON << 'PYEOF'
import asyncio, time, json, subprocess
from telethon import TelegramClient

SESSION = "/home/nic/gasclaw-workspace/telegram-test/tg_test_session.session"
GROUP_ID = -1003810709807

EXPECTED = {
    918: "gasclaw_master_bot",
    919: "minimax_gastown_publish_bot",
    920: "gasskill_agent_bot",
    921: "gasclaw_mgmt_bot",
    1425: "gascontext_bot",
}
LABELS = {918: "gasclaw", 919: "minimax", 920: "gasskill", 921: "mgmt", 1425: "context"}

# Reverse: bot → its allowed topic
BOT_TO_TOPIC = {v: k for k, v in EXPECTED.items()}

CONTAINERS = {
    "gasclaw_master_bot": "gasclaw-dev",
    "minimax_gastown_publish_bot": "gasclaw-minimax",
    "gasskill_agent_bot": "gasclaw-gasskill",
    "gasclaw_mgmt_bot": "gasclaw-mgmt",
    "gascontext_bot": "gasclaw-context",
}

async def main():
    client = TelegramClient(SESSION, 29672461, "0e0b535e8e0db252f86f0a6a8de3624e")
    await client.start()
    group = await client.get_entity(GROUP_ID)

    cutoff = time.time() - 300  # last 5 min
    violations = []

    for tid, expected_bot in EXPECTED.items():
        async for msg in client.iter_messages(group, reply_to=tid, limit=10):
            if msg.date.timestamp() < cutoff:
                break
            is_bot = getattr(msg.sender, "bot", False)
            username = getattr(msg.sender, "username", "") if msg.sender else ""
            if is_bot and username != expected_bot and username in BOT_TO_TOPIC:
                violations.append({
                    "topic": tid,
                    "label": LABELS[tid],
                    "expected": expected_bot,
                    "intruder": username,
                    "container": CONTAINERS.get(username, "?"),
                    "allowed_topic": BOT_TO_TOPIC.get(username, "?"),
                })

    if not violations:
        return

    # ── Alert: send violation report to manager topic (921) ──
    intruders = set()
    report = f"🚨 CROSS-TALK ALERT — {len(violations)} violation(s) in last 5 min:\n\n"
    for v in violations:
        report += f"• @{v['intruder']} replied in topic {v['topic']} ({v['label']}) — should ONLY be in topic {v['allowed_topic']}\n"
        intruders.add(v["intruder"])

    report += f"\nAuto-fix: cleaning stale sessions from {len(intruders)} container(s)..."
    await client.send_message(group, report, reply_to=921)
    print(f"[{time.strftime('%H:%M:%S')}] Alert sent: {len(violations)} violations, {len(intruders)} intruders")

    # ── Auto-fix: delete stale sessions in offending containers ──
    for bot_username in intruders:
        container = CONTAINERS.get(bot_username)
        allowed_topic = BOT_TO_TOPIC.get(bot_username)
        if not container or not allowed_topic:
            continue

        # Delete sessions for wrong topics
        cmd = f"""docker exec {container} bash -c '
            cd /root/.openclaw/agents/main/sessions/ 2>/dev/null || exit 0
            for f in *-topic-*.jsonl; do
                if ! echo "$f" | grep -q "topic-{allowed_topic}"; then
                    rm -f "$f" && echo "  deleted $f"
                fi
            done
        '"""
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
        if result.stdout.strip():
            print(f"  {container}: {result.stdout.strip()}")

        # Restart the offending gateway
        port_map = {
            "gasclaw-dev": 18794, "gasclaw-minimax": 18793,
            "gasclaw-gasskill": 18796, "gasclaw-context": 18797, "gasclaw-mgmt": 18798,
        }
        port = port_map.get(container, 0)
        if port:
            restart_cmd = f"""docker exec {container} bash -c '
                for f in /proc/[0-9]*/exe; do
                    target=$(readlink "$f" 2>/dev/null)
                    echo "$target" | grep -q node && kill -9 $(echo "$f" | cut -d/ -f3) 2>/dev/null
                done
                rm -f /root/.openclaw/gateway.lock; sleep 1
                nohup openclaw gateway run --port {port} --allow-unconfigured > /tmp/gw-crosstalk-fix.log 2>&1 &
            '"""
            subprocess.run(restart_cmd, shell=True, capture_output=True)
            print(f"  {container}: gateway restarted on port {port}")

    # Send fix confirmation
    await asyncio.sleep(15)
    fix_msg = f"✅ Auto-fix applied: cleaned stale sessions and restarted {len(intruders)} gateway(s). Monitoring continues."
    await client.send_message(group, fix_msg, reply_to=921)

    await client.disconnect()

asyncio.run(main())
PYEOF
