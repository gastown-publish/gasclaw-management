#!/usr/bin/env bash
# Mayor-driven hourly check: gather context, craft per-bot prompts, send, inspect.
# The mgmt mayor (main agent) controls this process via Telethon.
set -euo pipefail

LOCK=/tmp/gastown-mayor-hourly.lock
exec 200>"$LOCK"
if ! flock -n 200; then echo "$(date -Is) mayor-hourly: skipped (locked)" >&2; exit 0; fi

PYTHON="/home/nic/gasclaw-workspace/telethon/.venv/bin/python3"
SESSION="/home/nic/gasclaw-workspace/telegram-test/tg_test_session.session"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

echo "[$TIMESTAMP] === MAYOR HOURLY CHECK START ==="

# ── Step 1: Gather context from each repo ──
echo "[$TIMESTAMP] Step 1: Gathering context..."

GASCLAW_CONTEXT=$(cd /home/nic/gasclaw-workspace/gasclaw 2>/dev/null && git log --oneline --since="1 hour ago" 2>/dev/null | head -5 || echo "no recent commits")
GASCLAW_ISSUES=$(gh issue list --repo gastown-publish/gasclaw --limit 5 --json number,title 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); [print(f'#{i[\"number\"]}: {i[\"title\"]}') for i in d]" 2>/dev/null || echo "unable to fetch")
GASCLAW_CI=$(gh run list --repo gastown-publish/gasclaw --limit 1 --json status,conclusion 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(d[0]['conclusion'] if d else 'unknown')" 2>/dev/null || echo "unknown")

MINIMAX_CONTEXT=$(cd /home/nic/data/models/MiniMax-M2.5 2>/dev/null && git log --oneline --since="1 hour ago" 2>/dev/null | head -5 || echo "no recent commits")
MINIMAX_ISSUES=$(gh issue list --repo gastown-publish/minimax --limit 5 --json number,title 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); [print(f'#{i[\"number\"]}: {i[\"title\"]}') for i in d]" 2>/dev/null || echo "unable to fetch")
MINIMAX_CI=$(gh run list --repo gastown-publish/minimax --limit 1 --json status,conclusion 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(d[0]['conclusion'] if d else 'unknown')" 2>/dev/null || echo "unknown")

GASSKILL_CONTEXT=$(cd /home/nic/gasclaw-workspace/gasskill 2>/dev/null && git log --oneline --since="1 hour ago" 2>/dev/null | head -5 || echo "no recent commits")
GASSKILL_ISSUES=$(gh issue list --repo gastown-publish/gasskill --limit 5 --json number,title 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); [print(f'#{i[\"number\"]}: {i[\"title\"]}') for i in d]" 2>/dev/null || echo "unable to fetch")

MGMT_CONTEXT=$(cd /home/nic/gasclaw-workspace/gasclaw-management 2>/dev/null && git log --oneline --since="1 hour ago" 2>/dev/null | head -5 || echo "no recent commits")
MGMT_BEADS=$(cd /home/nic/gasclaw-workspace/gasclaw-management && bd ready 2>/dev/null | head -10 || echo "unable to fetch")

VLLM_STATUS=$(curl -s --max-time 5 -o /dev/null -w "%{http_code}" http://localhost:8080/health 2>/dev/null)
LITELLM_STATUS=$(curl -s --max-time 5 -o /dev/null -w "%{http_code}" http://localhost:4000/health 2>/dev/null)

echo "  Context gathered."

# ── Step 2: Send context-aware prompts ──
echo "[$TIMESTAMP] Step 2: Sending context-aware prompts..."

$PYTHON << PYEOF
import asyncio, os
from telethon import TelegramClient

SESSION = "$SESSION"
GROUP_ID = -1003810709807

PROMPTS = {
    918: """[Mayor hourly check — $TIMESTAMP]

You are the gasclaw-dev mayor managing gastown-publish/gasclaw.

CONTEXT FROM YOUR REPO:
- Recent commits: $GASCLAW_CONTEXT
- Open issues: $GASCLAW_ISSUES
- CI status: $GASCLAW_CI

INSTRUCTIONS: Based on this real context, report:
1. STATUS: online/degraded/error
2. METRICS: commits_last_hour, issues_open, CI_status (use actual numbers above)
3. WORK_DONE: what you accomplished (reference specific commits/PRs/issues)
4. GOAL_NEXT_HOUR: pick ONE open issue or task and commit to completing it
5. IMPROVEMENT_PLAN: 3 specific things — one for code quality, one for speed, one for reliability
6. PROJECT_VISION: what gastown-publish/gasclaw should become in 1 month

Do NOT say "none" or "idle". If no commits, explain why and what you will do NOW.""",

    919: """[Mayor hourly check — $TIMESTAMP]

You are the minimax mayor managing gastown-publish/minimax.

CONTEXT FROM YOUR REPO:
- Recent commits: $MINIMAX_CONTEXT
- Open issues: $MINIMAX_ISSUES
- CI status: $MINIMAX_CI
- vLLM: HTTP $VLLM_STATUS | LiteLLM: HTTP $LITELLM_STATUS

INSTRUCTIONS: Based on this real context, report:
1. STATUS: online/degraded/error
2. METRICS: commits_last_hour, issues_open, CI_status, vllm_status, litellm_status
3. WORK_DONE: what you accomplished (reference specific commits/PRs/issues)
4. TOP_3_ISSUES: pick 3 most important open issues and your plan for each
5. GOAL_NEXT_HOUR: pick ONE issue and commit to resolving it
6. IMPROVEMENT_PLAN: 3 specific things — one for security, one for performance, one for UX
7. PROJECT_VISION: what gastown-publish/minimax should become in 1 month

Do NOT say "none" or "idle". 34 open issues means there is ALWAYS work to do.""",

    920: """[Mayor hourly check — $TIMESTAMP]

You are the gasskill mayor managing gastown-publish/gasskill.

CONTEXT FROM YOUR REPO:
- Recent commits: $GASSKILL_CONTEXT
- Open issues: $GASSKILL_ISSUES

INSTRUCTIONS: Based on this real context, report:
1. STATUS: online/degraded/error
2. METRICS: commits_last_hour, issues_open, skills_count
3. WORK_DONE: what you accomplished (reference specific commits/PRs)
4. GOAL_NEXT_HOUR: pick ONE concrete deliverable
5. IMPROVEMENT_PLAN: 3 specific things — one for skill quality, one for testing, one for documentation
6. PROJECT_VISION: what gastown-publish/gasskill should become in 1 month

If repo not cloned, your FIRST goal is to clone it and inspect the codebase.""",

    921: """[Mayor hourly check — $TIMESTAMP]

You are the mgmt mayor managing gastown-publish/gasclaw-management.

CONTEXT FROM YOUR REPO:
- Recent commits: $MGMT_CONTEXT
- Open beads: $MGMT_BEADS
- vLLM: HTTP $VLLM_STATUS | LiteLLM: HTTP $LITELLM_STATUS

PLATFORM STATUS: 4 containers running, 4 bots active, watchdog cron every 5min.

INSTRUCTIONS: As the platform manager, report:
1. STATUS: online/degraded/error (for the WHOLE platform, not just your container)
2. PLATFORM_METRICS: containers_up, gateways_healthy, agents_active, services_up
3. WORK_DONE: what you coordinated across the platform
4. OPEN_BEADS: list the top 3 and your plan for each
5. 10_IMPROVEMENTS: list 10 concrete things to improve across the entire Gasclaw platform
6. GOAL_NEXT_HOUR: the single most impactful thing to do
7. PLATFORM_VISION: what the Gasclaw platform should become in 1 month

You are the manager. Think big. Be specific. Use numbers.""",
}

async def main():
    client = TelegramClient(SESSION, 29672461, "0e0b535e8e0db252f86f0a6a8de3624e")
    await client.start()
    group = await client.get_entity(GROUP_ID)
    for tid, prompt in PROMPTS.items():
        await client.send_message(group, prompt, reply_to=tid)
        print(f"  sent to topic {tid}")
    await client.disconnect()

asyncio.run(main())
PYEOF

echo "[$TIMESTAMP] Prompts sent. Waiting 90s for responses..."
sleep 90

# ── Step 3: Inspect responses ──
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Step 3: Inspecting responses..."

$PYTHON << 'PYEOF'
import asyncio, time
from telethon import TelegramClient

SESSION = "/home/nic/gasclaw-workspace/telegram-test/tg_test_session.session"
GROUP_ID = -1003810709807
TOPICS = {
    918: {"bot": "gasclaw_master_bot", "label": "gasclaw"},
    919: {"bot": "minimax_gastown_publish_bot", "label": "minimax"},
    920: {"bot": "gasskill_agent_bot", "label": "gasskill"},
    921: {"bot": "gasclaw_mgmt_bot", "label": "mgmt"},
}

async def main():
    client = TelegramClient(SESSION, 29672461, "0e0b535e8e0db252f86f0a6a8de3624e")
    await client.start()
    group = await client.get_entity(GROUP_ID)
    cutoff = time.time() - 180
    passed = 0

    for tid, info in TOPICS.items():
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
            correct = (username == info["bot"])
            if correct:
                passed += 1
                lines = len(text.split("\n"))
                has_numbers = any(c.isdigit() for c in text)
                print(f"{'✅' if lines > 5 and has_numbers else '⚠️'} {info['label']}: @{username} ({lines} lines)")
                for line in text.split("\n")[:15]:
                    print(f"   {line.strip()}")
                if lines > 15:
                    print(f"   ... ({lines-15} more lines)")
            else:
                print(f"❌ {info['label']}: WRONG BOT @{username}")
            print()
            break
        if not found:
            print(f"❌ {info['label']}: NO REPLY\n")

    print(f"=== {passed}/4 correct bots ===")
    await client.disconnect()

asyncio.run(main())
PYEOF

echo "[$(date '+%Y-%m-%d %H:%M:%S')] === MAYOR HOURLY CHECK DONE ==="
