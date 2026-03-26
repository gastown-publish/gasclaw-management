#!/usr/bin/env bash
# Mayor-driven hourly conversation: gather context, have a REAL conversation with each bot.
# Not a nudge — a multi-turn dialogue where the manager asks, follows up, and challenges.
set -euo pipefail

LOCK=/tmp/gastown-mayor-hourly.lock
exec 200>"$LOCK"
if ! flock -n 200; then echo "$(date -Is) mayor-hourly: skipped (locked)" >&2; exit 0; fi

PYTHON="/home/nic/gasclaw-workspace/telethon/.venv/bin/python3"
SESSION="/home/nic/gasclaw-workspace/telegram-test/tg_test_session.session"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

echo "[$TIMESTAMP] === MAYOR HOURLY CONVERSATION START ==="

# ── Step 1: Gather context ──
echo "[$TIMESTAMP] Step 1: Gathering context..."

GASCLAW_COMMITS=$(cd /home/nic/gasclaw-workspace/gasclaw 2>/dev/null && git log --oneline --since="1 hour ago" 2>/dev/null | head -5 || echo "none")
GASCLAW_ISSUES=$(gh issue list --repo gastown-publish/gasclaw --limit 5 --json number,title -q '.[].title' 2>/dev/null | head -5 || echo "unknown")
GASCLAW_CI=$(gh run list --repo gastown-publish/gasclaw --limit 1 --json conclusion -q '.[0].conclusion' 2>/dev/null || echo "unknown")

MINIMAX_COMMITS=$(cd /home/nic/data/models/MiniMax-M2.5 2>/dev/null && git log --oneline --since="1 hour ago" 2>/dev/null | head -5 || echo "none")
MINIMAX_ISSUES_COUNT=$(gh issue list --repo gastown-publish/minimax --json number 2>/dev/null | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "?")
MINIMAX_ISSUES=$(gh issue list --repo gastown-publish/minimax --limit 5 --json number,title -q '.[] | "#\(.number): \(.title)"' 2>/dev/null | head -5 || echo "unknown")
MINIMAX_CI=$(gh run list --repo gastown-publish/minimax --limit 1 --json conclusion -q '.[0].conclusion' 2>/dev/null || echo "unknown")

GASSKILL_COMMITS=$(cd /home/nic/gasclaw-workspace/gasskill 2>/dev/null && git log --oneline --since="1 hour ago" 2>/dev/null | head -5 || echo "none")
GASSKILL_ISSUES=$(gh issue list --repo gastown-publish/gasskill --limit 5 --json number,title -q '.[] | "#\(.number): \(.title)"' 2>/dev/null | head -5 || echo "none")

CONTEXT_COMMITS=$(cd /home/nic/gasclaw-workspace/context-hub 2>/dev/null && git log --oneline --since="1 hour ago" 2>/dev/null | head -5 || echo "none")
CONTEXT_ISSUES=$(gh issue list --repo gastown-publish/context-hub --limit 5 --json number,title -q '.[] | "#\(.number): \(.title)"' 2>/dev/null | head -5 || echo "none")

MGMT_COMMITS=$(cd /home/nic/gasclaw-workspace/gasclaw-management 2>/dev/null && git log --oneline --since="1 hour ago" 2>/dev/null | head -5 || echo "none")
MGMT_BEADS=$(cd /home/nic/gasclaw-workspace/gasclaw-management && bd ready 2>/dev/null | head -10 || echo "unknown")

VLLM_S=$(curl -s --max-time 5 -o /dev/null -w "%{http_code}" http://localhost:8080/health 2>/dev/null)
LITELLM_S=$(curl -s --max-time 5 -o /dev/null -w "%{http_code}" http://localhost:4000/health 2>/dev/null)

echo "  Done."

# ── Step 2: Conversation with each bot (3 turns: opening → follow-up → challenge) ──
echo "[$TIMESTAMP] Step 2: Starting conversations..."

$PYTHON << PYEOF
import asyncio, time
from telethon import TelegramClient

SESSION = "$SESSION"
GROUP_ID = -1003810709807

BOTS = {
    918: {"label": "gasclaw", "bot": "gasclaw_master_bot"},
    919: {"label": "minimax", "bot": "minimax_gastown_publish_bot"},
    920: {"label": "gasskill", "bot": "gasskill_agent_bot"},
    921: {"label": "mgmt", "bot": "gasclaw_mgmt_bot"},
    1425: {"label": "context", "bot": "gascontext_bot"},
}

# ── Turn 1: Opening — status + 10 improvements ──
TURN1 = {
    918: """[Mayor — $TIMESTAMP]

I'm the platform manager doing the hourly review. Here's what I see for your repo:

- Commits last hour: $GASCLAW_COMMITS
- Open issues: $GASCLAW_ISSUES
- CI: $GASCLAW_CI

I need you to do 3 things RIGHT NOW:

1. Give me your honest STATUS (online/degraded/error) and explain why.
2. List 10 specific improvements you would make to gastown-publish/gasclaw. Not generic — reference actual code, actual issues, actual architecture. For each one, explain WHY it matters and WHAT the impact would be.
3. What is the single most important thing you should do in the next hour? Not "review issues" — give me a specific commit you will make.

I will follow up on your answers. Do not be vague.""",

    919: """[Mayor — $TIMESTAMP]

Hourly review for minimax. Here's the real data:

- Commits last hour: $MINIMAX_COMMITS
- Open issues: $MINIMAX_ISSUES_COUNT total. Top 5: $MINIMAX_ISSUES
- CI: $MINIMAX_CI
- vLLM: HTTP $VLLM_S | LiteLLM: HTTP $LITELLM_S

I need HONEST answers:

1. STATUS and why. If everything is "fine" but you have $MINIMAX_ISSUES_COUNT open issues, that's not fine — explain.
2. List 10 specific improvements for gastown-publish/minimax. For each: what file/component, what's wrong, what you'd change, and the user impact. I want specifics — not "improve documentation".
3. Of those 10, rank them by impact. Which 3 would you do THIS WEEK?
4. What will you commit to delivering in the next hour? Be specific — file name, what changes.

This is a conversation, not a form. I'll push back if your answers are weak.""",

    920: """[Mayor — $TIMESTAMP]

Hourly review for gasskill. Data:

- Commits last hour: $GASSKILL_COMMITS
- Open issues: $GASSKILL_ISSUES

I need you to think hard:

1. STATUS — and if you say "online" but have done nothing, explain why.
2. List 10 improvements for gastown-publish/gasskill. Skills need to be high quality, well tested, and well documented. What's missing? What's broken? What would make skills 10x more useful?
3. For each improvement, explain WHO benefits (the agent? the user? the platform?) and HOW MUCH.
4. What specific deliverable will you produce in the next hour?

If the repo isn't cloned yet, that IS your first deliverable. Tell me the plan.""",

    921: """[Mayor — $TIMESTAMP]

Self-review time. You're the platform manager. Here's your data:

- Your commits: $MGMT_COMMITS
- Open beads: $MGMT_BEADS
- vLLM: HTTP $VLLM_S | LiteLLM: HTTP $LITELLM_S
- 5 containers running, 5 bots active

Be BRUTALLY honest with yourself:

1. PLATFORM STATUS — not just "online". Grade each: containers, gateways, agents, services, Telegram, CI, documentation, monitoring. Use A/B/C/D/F.
2. List 10 improvements for the ENTIRE Gasclaw platform. Think about: reliability, monitoring, automation, developer experience, documentation, security, performance, cost, scalability, user experience.
3. For each improvement, estimate: effort (hours), impact (high/medium/low), and who should do it (which container's agent).
4. What is the #1 thing that would make this platform PRODUCTION READY? Be specific.
5. What will YOU personally deliver in the next hour?

You are the manager. I expect manager-quality thinking.""",

    1425: """[Mayor — $TIMESTAMP]

Hourly review for context-hub. Data:

- Commits last hour: $CONTEXT_COMMITS
- Open issues: $CONTEXT_ISSUES

This is a fresh fork of andrewyng/context-hub with gashub CLI + MCP server.

1. STATUS — have you inspected the codebase yet? What did you find?
2. List 10 improvements for gastown-publish/context-hub. Think about: gashub CLI usability, MCP server reliability, content quality, documentation, testing, CI/CD, npm publishing, Gasclaw integration.
3. For each, explain the user benefit and estimated effort.
4. What will you deliver in the next hour?

This repo has real users (all 5 Gasclaw containers use gashub). Quality matters.""",
}

# ── Turn 2: Follow-up (sent after reading Turn 1 responses) ──
TURN2_TEMPLATE = """Good start, but I need more depth on your improvements list.

Pick your top 3 improvements and for EACH one:
- What EXACTLY would you change? (file paths, function names, config keys)
- What's the current behavior vs desired behavior?
- How would you TEST that the improvement works?
- What could go wrong during implementation?

Also: you mentioned your next-hour goal. Break it into 3 concrete steps with time estimates. I want to see you've actually thought it through, not just said something that sounds good."""

# ── Turn 3: Challenge (sent after reading Turn 2 responses) ──
TURN3_TEMPLATE = """Final question for this hour:

1. What is ONE thing you've been AVOIDING or POSTPONING? Every project has something uncomfortable. Name it.
2. If I gave you 10x the resources (more agents, more compute), what would you do DIFFERENTLY? This tells me if you're thinking big enough.
3. Grade yourself A-F on this hour's performance. Justify the grade.

Be honest. I'll use your answers to prioritize next hour's work across the whole platform."""

async def main():
    client = TelegramClient(SESSION, 29672461, "0e0b535e8e0db252f86f0a6a8de3624e")
    await client.start()
    group = await client.get_entity(GROUP_ID)

    # ── TURN 1: Send opening to all bots ──
    print("Turn 1: Sending opening questions...")
    for tid, prompt in TURN1.items():
        await client.send_message(group, prompt, reply_to=tid)
        print(f"  → {BOTS[tid]['label']} (topic {tid})")

    print("Waiting 120s for Turn 1 responses...")
    await asyncio.sleep(120)

    # ── Read Turn 1 responses ──
    print("\nTurn 1 responses:")
    cutoff = time.time() - 150
    responding = []
    for tid, info in BOTS.items():
        async for msg in client.iter_messages(group, reply_to=tid, limit=3):
            if msg.date.timestamp() < cutoff:
                continue
            is_bot = getattr(msg.sender, "bot", False)
            username = getattr(msg.sender, "username", "") if msg.sender else ""
            if is_bot and username == info["bot"]:
                lines = len((msg.text or "").split("\n"))
                print(f"  ✅ {info['label']}: @{username} ({lines} lines)")
                responding.append(tid)
                break
        else:
            print(f"  ❌ {info['label']}: no reply yet")

    # ── TURN 2: Follow up with bots that responded ──
    if responding:
        print(f"\nTurn 2: Following up with {len(responding)} bots...")
        for tid in responding:
            await client.send_message(group, TURN2_TEMPLATE, reply_to=tid)
            print(f"  → {BOTS[tid]['label']}")

        print("Waiting 120s for Turn 2 responses...")
        await asyncio.sleep(120)

        # Read Turn 2
        print("\nTurn 2 responses:")
        cutoff2 = time.time() - 150
        turn2_ok = []
        for tid in responding:
            info = BOTS[tid]
            async for msg in client.iter_messages(group, reply_to=tid, limit=3):
                if msg.date.timestamp() < cutoff2:
                    continue
                is_bot = getattr(msg.sender, "bot", False)
                username = getattr(msg.sender, "username", "") if msg.sender else ""
                if is_bot and username == info["bot"]:
                    lines = len((msg.text or "").split("\n"))
                    print(f"  ✅ {info['label']}: ({lines} lines)")
                    turn2_ok.append(tid)
                    break
            else:
                print(f"  ⏳ {info['label']}: still thinking...")

        # ── TURN 3: Challenge ──
        if turn2_ok:
            print(f"\nTurn 3: Challenging {len(turn2_ok)} bots...")
            for tid in turn2_ok:
                await client.send_message(group, TURN3_TEMPLATE, reply_to=tid)
                print(f"  → {BOTS[tid]['label']}")

            print("Waiting 90s for Turn 3 responses...")
            await asyncio.sleep(90)

            # Read Turn 3
            print("\nTurn 3 responses:")
            cutoff3 = time.time() - 120
            for tid in turn2_ok:
                info = BOTS[tid]
                async for msg in client.iter_messages(group, reply_to=tid, limit=3):
                    if msg.date.timestamp() < cutoff3:
                        continue
                    is_bot = getattr(msg.sender, "bot", False)
                    username = getattr(msg.sender, "username", "") if msg.sender else ""
                    if is_bot and username == info["bot"]:
                        lines = len((msg.text or "").split("\n"))
                        text = msg.text or ""
                        # Look for self-grade
                        grade = "?"
                        for line in text.split("\n"):
                            if "grade" in line.lower() and any(g in line for g in ["A","B","C","D","F"]):
                                grade = line.strip()[:60]
                                break
                        print(f"  ✅ {info['label']}: ({lines} lines) — {grade}")
                        break
                else:
                    print(f"  ⏳ {info['label']}: still thinking...")

    # ── Summary ──
    print(f"\n=== CONVERSATION COMPLETE ===")
    print(f"Turn 1: {len(responding)}/5 responded")
    print(f"Turn 2: {len(turn2_ok) if responding else 0}/{len(responding)} elaborated")
    print(f"Turn 3: challenged those who elaborated")
    print(f"Total conversation: ~5.5 min across {len(BOTS)} topics")

    await client.disconnect()

asyncio.run(main())
PYEOF

echo "[$(date '+%Y-%m-%d %H:%M:%S')] === MAYOR HOURLY CONVERSATION DONE ==="
