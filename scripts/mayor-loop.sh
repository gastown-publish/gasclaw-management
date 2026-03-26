#!/usr/bin/env bash
# Mayor conversation loop: continuous management of all bots.
# Runs as a long-lived process (not cron). The manager never leaves.
#
# Cycle: review → assign → wait 30min → check → follow up → repeat
#
# Start:  nohup ./scripts/mayor-loop.sh >> /tmp/mayor-loop.log 2>&1 &
# Stop:   kill $(cat /tmp/mayor-loop.pid)
set -euo pipefail

echo $$ > /tmp/mayor-loop.pid
PYTHON="/home/nic/gasclaw-workspace/telethon/.venv/bin/python3"
SESSION="/home/nic/gasclaw-workspace/telegram-test/tg_test_session.session"
CYCLE=0

while true; do
  CYCLE=$((CYCLE + 1))
  TS=$(date '+%Y-%m-%d %H:%M:%S')
  echo ""
  echo "================================================================"
  echo "[$TS] CYCLE $CYCLE"
  echo "================================================================"

  # ── Gather fresh context ──
  GASCLAW_COMMITS=$(cd /home/nic/gasclaw-workspace/gasclaw 2>/dev/null && git log --oneline --since="30 minutes ago" 2>/dev/null | head -5 || echo "none")
  MINIMAX_COMMITS=$(cd /home/nic/data/models/MiniMax-M2.5 2>/dev/null && git log --oneline --since="30 minutes ago" 2>/dev/null | head -5 || echo "none")
  MINIMAX_ISSUES=$(gh issue list --repo gastown-publish/minimax --json number -q 'length' 2>/dev/null || echo "?")
  GASSKILL_COMMITS=$(cd /home/nic/gasclaw-workspace/gasskill 2>/dev/null && git log --oneline --since="30 minutes ago" 2>/dev/null | head -5 || echo "none")
  CONTEXT_COMMITS=$(cd /home/nic/gasclaw-workspace/context-hub 2>/dev/null && git log --oneline --since="30 minutes ago" 2>/dev/null | head -5 || echo "none")
  MGMT_COMMITS=$(cd /home/nic/gasclaw-workspace/gasclaw-management 2>/dev/null && git log --oneline --since="30 minutes ago" 2>/dev/null | head -5 || echo "none")
  BEADS=$(cd /home/nic/gasclaw-workspace/gasclaw-management && bd ready 2>/dev/null | head -5 || echo "unknown")

  # ── Phase A: Review + Assign (send to all bots) ──
  echo "[$TS] Phase A: Review + Assign..."

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

CYCLE = $CYCLE

if CYCLE == 1:
    # First cycle: full review
    PHASE_A = {
        918: """[Manager cycle $CYCLE — $TS]

I'm your manager. This is not a one-time check — I will keep coming back every 30 minutes to review your work.

Your repo: gastown-publish/gasclaw
Commits since last check: $GASCLAW_COMMITS

ASSIGNMENT for this cycle:
1. Report your current status honestly.
2. List 10 improvements for your repo. For each: what file, what's wrong, what you'd change, why it matters.
3. Pick the TOP 1 improvement and START WORKING ON IT NOW. I will check back in 30 minutes to see your progress.

When I return, I expect to see: a commit, a PR, or a detailed explanation of what blocked you. "Idle" is not acceptable.""",

        919: """[Manager cycle $CYCLE — $TS]

I'm your manager. I will check back every 30 minutes. No hiding.

Your repo: gastown-publish/minimax ($MINIMAX_ISSUES open issues)
Commits since last check: $MINIMAX_COMMITS

ASSIGNMENT:
1. Status report with honest assessment.
2. List 10 improvements. Be SPECIFIC — file paths, function names, user impact.
3. Pick issue with highest impact and START WORKING. I want a commit or PR when I return in 30 min.
4. If you can't code, at least triage 5 issues with priority labels and next-step comments.

I'm tracking your output. Show me results.""",

        920: """[Manager cycle $CYCLE — $TS]

I'm your manager. I check every 30 minutes.

Your repo: gastown-publish/gasskill
Commits since last check: $GASSKILL_COMMITS

ASSIGNMENT:
1. Status — have you cloned the repo? If not, do it NOW.
2. List 10 improvements for skills quality, testing, documentation.
3. START on the highest-impact one. I want evidence when I return.
4. If the repo is empty or new, your job is to BUILD something. Create a new skill or improve an existing one.

30 minutes. Go.""",

        921: """[Manager cycle $CYCLE — $TS]

Self-management time. You're the platform manager.

Platform data:
- Beads: $BEADS
- Your commits: $MGMT_COMMITS

ASSIGNMENT:
1. Grade each area A-F: containers, gateways, agents, services, Telegram, CI, docs, monitoring, security, reliability.
2. For each area graded C or below: what specific action would raise it to B?
3. List 10 platform-wide improvements with effort estimates.
4. START on the most impactful one. I expect a commit in 30 min.

You manage the managers. Lead by example.""",

        1425: """[Manager cycle $CYCLE — $TS]

I'm your manager. Checking every 30 minutes.

Your repo: gastown-publish/context-hub (gashub CLI + MCP)
Commits since last check: $CONTEXT_COMMITS

ASSIGNMENT:
1. Status — inspect the codebase if you haven't.
2. List 10 improvements for gashub: CLI usability, MCP server, content quality, testing, docs, npm publishing.
3. Pick ONE and start working. I want a diff when I return.
4. Run \`gashub search openai\` and \`gashub-mcp\` — verify they work. Report any issues.

Clock is ticking.""",
    }
else:
    # Subsequent cycles: check progress + reassign
    PHASE_A = {
        918: """[Manager cycle $CYCLE — $TS]

I'm back. Show me what you did since my last message.

Commits since last check: $GASCLAW_COMMITS

REPORT:
1. What did you accomplish? Show me commits, PRs, or code changes. Use numbers.
2. If you didn't finish: what blocked you? Be specific.
3. What will you do in the NEXT 30 minutes? Be concrete — I'll verify.

If you produced nothing: explain why and propose how to unblock yourself. I need momentum, not excuses.""",

        919: """[Manager cycle $CYCLE — $TS]

Back to check on you. Minimax ($MINIMAX_ISSUES open issues).

Commits since last check: $MINIMAX_COMMITS

PROGRESS REPORT:
1. What did you ship? Commits, PRs, issue comments, triaging — show numbers.
2. Which of the 10 improvements are you making progress on?
3. What's blocking you? I can help unblock.
4. Next 30 min goal — be specific. I WILL verify.

$MINIMAX_ISSUES issues open means there's always work. No excuses.""",

        920: """[Manager cycle $CYCLE — $TS]

Checking in on gasskill.

Commits since last check: $GASSKILL_COMMITS

REPORT:
1. What did you produce? Commits, new skills, tests, docs?
2. Did you complete your last assignment? Show evidence.
3. Next 30 min: what specific file will you create or modify?

I'm looking for TANGIBLE output.""",

        921: """[Manager cycle $CYCLE — $TS]

Self-check. How's the platform doing?

Your commits: $MGMT_COMMITS
Beads: $BEADS

REPORT:
1. Did you improve any area since last cycle? Which grade went up?
2. What blocked you?
3. Next 30 min: what will you ship?

As manager, you set the pace. If you're idle, the whole platform stalls.""",

        1425: """[Manager cycle $CYCLE — $TS]

Context-hub check-in.

Commits since last check: $CONTEXT_COMMITS

REPORT:
1. What did you accomplish? Diffs, tests, docs?
2. Did gashub search and gashub-mcp work when you tested?
3. Next 30 min: what improvement will you ship?

This repo serves all 5 containers. Quality matters.""",
    }

async def main():
    client = TelegramClient(SESSION, 29672461, "0e0b535e8e0db252f86f0a6a8de3624e")
    await client.start()
    group = await client.get_entity(GROUP_ID)

    # Send assignments
    for tid, prompt in PHASE_A.items():
        await client.send_message(group, prompt, reply_to=tid)
        print(f"  → {BOTS[tid]['label']}")

    # Wait for responses
    print("  Waiting 120s for responses...")
    await asyncio.sleep(120)

    # Read and summarize
    cutoff = time.time() - 150
    results = {}
    for tid, info in BOTS.items():
        async for msg in client.iter_messages(group, reply_to=tid, limit=3):
            if msg.date.timestamp() < cutoff:
                continue
            is_bot = getattr(msg.sender, "bot", False)
            username = getattr(msg.sender, "username", "") if msg.sender else ""
            if is_bot and username == info["bot"]:
                text = msg.text or ""
                lines = len(text.split("\n"))
                has_commits = "commit" in text.lower()
                has_numbers = any(c.isdigit() for c in text)
                results[info["label"]] = {"lines": lines, "has_commits": has_commits, "has_numbers": has_numbers}
                print(f"  ✅ {info['label']}: {lines} lines {'📝' if has_commits else '❌no commits'}")
                break
        else:
            results[info["label"]] = None
            print(f"  ❌ {info['label']}: no reply")

    # Phase B: Follow up on weak responses
    FOLLOWUPS = {}
    for tid, info in BOTS.items():
        r = results.get(info["label"])
        if r is None:
            FOLLOWUPS[tid] = f"You didn't respond to my last message. This is unacceptable. Report immediately: what are you doing and why didn't you answer?"
        elif r["lines"] < 5:
            FOLLOWUPS[tid] = f"Your response was too short ({r['lines']} lines). I need substance. Elaborate on what you're working on and show me evidence of progress."
        elif not r["has_commits"] and CYCLE > 1:
            FOLLOWUPS[tid] = f"I don't see any commits mentioned. What tangible output did you produce? If nothing, what specific blocker do I need to help with?"

    if FOLLOWUPS:
        print(f"\n  Following up with {len(FOLLOWUPS)} bots...")
        for tid, msg_text in FOLLOWUPS.items():
            await client.send_message(group, msg_text, reply_to=tid)
            print(f"  → {BOTS[tid]['label']} (follow-up)")

    await client.disconnect()

asyncio.run(main())
PYEOF

  echo "[$TS] Cycle $CYCLE complete. Sleeping 30 minutes before next check..."
  sleep 1800
done
