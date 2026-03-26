#!/usr/bin/env bash
# Mayor conversation loop: persistent management with REAL follow-up.
# Every 30 min: review → read → follow up on specifics → assign → check later
#
# Start:  nohup ./scripts/mayor-loop.sh >> /tmp/mayor-loop.log 2>&1 &
# Stop:   kill $(cat /tmp/mayor-loop.pid)
set -euo pipefail

echo $$ > /tmp/mayor-loop.pid
trap "rm -f /tmp/mayor-loop.pid" EXIT

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

  # ── Gather context ──
  GC=$(cd /home/nic/gasclaw-workspace/gasclaw 2>/dev/null && git log --oneline --since="30 minutes ago" 2>/dev/null | head -5 || echo "none")
  MC=$(cd /home/nic/data/models/MiniMax-M2.5 2>/dev/null && git log --oneline --since="30 minutes ago" 2>/dev/null | head -5 || echo "none")
  MI=$(gh issue list --repo gastown-publish/minimax --json number -q 'length' 2>/dev/null || echo "?")
  GSC=$(cd /home/nic/gasclaw-workspace/gasskill 2>/dev/null && git log --oneline --since="30 minutes ago" 2>/dev/null | head -5 || echo "none")
  CC=$(cd /home/nic/gasclaw-workspace/context-hub 2>/dev/null && git log --oneline --since="30 minutes ago" 2>/dev/null | head -5 || echo "none")
  MGC=$(cd /home/nic/gasclaw-workspace/gasclaw-management 2>/dev/null && git log --oneline --since="30 minutes ago" 2>/dev/null | head -5 || echo "none")
  BD=$(cd /home/nic/gasclaw-workspace/gasclaw-management && bd ready 2>/dev/null | head -5 | tr '\n' '; ' || echo "?")

  # Write context to JSON file to avoid heredoc quoting issues
  python3 -c "
import json
ctx = {
    'gc': '''$(echo "$GC" | tr "'" " ")''',
    'mc': '''$(echo "$MC" | tr "'" " ")''',
    'mi': '$MI',
    'gsc': '''$(echo "$GSC" | tr "'" " ")''',
    'cc': '''$(echo "$CC" | tr "'" " ")''',
    'mgc': '''$(echo "$MGC" | tr "'" " ")''',
    'bd': '''$(echo "$BD" | tr "'" " ")''',
    'ts': '$TS',
    'cycle': $CYCLE,
}
json.dump(ctx, open('/tmp/mayor-context.json','w'))
"

  $PYTHON << 'PYEOF'
import asyncio, time, re, json
from telethon import TelegramClient

with open("/tmp/mayor-context.json") as f:
    CTX = json.load(f)

SESSION = "/home/nic/gasclaw-workspace/telegram-test/tg_test_session.session"
GROUP_ID = -1003810709807
CYCLE = CTX["cycle"]
TS = CTX["ts"]

BOTS = {
    918: {"label": "gasclaw", "bot": "gasclaw_master_bot"},
    919: {"label": "minimax", "bot": "minimax_gastown_publish_bot"},
    920: {"label": "gasskill", "bot": "gasskill_agent_bot"},
    921: {"label": "mgmt", "bot": "gasclaw_mgmt_bot"},
    1425: {"label": "context", "bot": "gascontext_bot"},
}

# ── Build Turn 1 prompts ──
if CYCLE == 1:
    T1 = {
        918: f"[Manager cycle 1] Your repo: gastown-publish/gasclaw. Commits last 30m: {CTX['gc']}. Give me: 1) STATUS 2) 10 specific improvements with file paths and WHY 3) Pick #1 and START now. I return in 30 min expecting a commit.",
        919: f"[Manager cycle 1] Your repo: gastown-publish/minimax ({CTX['mi']} open issues). Commits last 30m: {CTX['mc']}. Give me: 1) STATUS 2) 10 improvements — file paths, what's broken, user impact 3) Rank by impact 4) Start on #1 NOW. I expect evidence in 30 min.",
        920: f"[Manager cycle 1] Your repo: gastown-publish/gasskill. Commits last 30m: {CTX['gsc']}. Give me: 1) STATUS 2) 10 improvements for skills 3) Start building or improving a skill NOW. Show me a diff in 30 min.",
        921: f"[Manager cycle 1] You manage the platform. Commits: {CTX['mgc']}. Beads: {CTX['bd']}. Grade each area A-F: containers, gateways, agents, services, Telegram, CI, docs, monitoring, security. List 10 platform improvements. Start on #1.",
        1425: f"[Manager cycle 1] Your repo: gastown-publish/context-hub. Commits last 30m: {CTX['cc']}. Give me: 1) STATUS 2) 10 improvements for gashub CLI/MCP 3) Start on the most impactful. Show progress in 30 min.",
    }
else:
    T1 = {
        918: f"[Manager cycle {CYCLE}] I'm back. Commits since last check: {CTX['gc']}. SHOW ME: 1) What you shipped (commits, PRs, diffs) 2) If nothing: what blocked you and how to unblock 3) Next 30 min deliverable. No vague answers.",
        919: f"[Manager cycle {CYCLE}] Back. Minimax ({CTX['mi']} issues). Commits: {CTX['mc']}. 1) What did you ship? Numbers. 2) Which of your 10 improvements are you progressing? 3) Next 30 min — specific file and change.",
        920: f"[Manager cycle {CYCLE}] Gasskill check-in. Commits: {CTX['gsc']}. 1) What did you produce? 2) Show me the skill you're building or improving 3) Next deliverable.",
        921: f"[Manager cycle {CYCLE}] Platform self-check. Commits: {CTX['mgc']}. Beads: {CTX['bd']}. 1) Which grades improved? 2) What shipped? 3) Next action.",
        1425: f"[Manager cycle {CYCLE}] Context-hub check. Commits: {CTX['cc']}. 1) What did you ship? 2) Did you run gashub search/get to verify? 3) Next improvement.",
    }

async def read_bot_response(client, group, tid, info, cutoff):
    """Read the latest bot response and return it."""
    async for msg in client.iter_messages(group, reply_to=tid, limit=5):
        if msg.date.timestamp() < cutoff:
            continue
        is_bot = getattr(msg.sender, "bot", False)
        username = getattr(msg.sender, "username", "") if msg.sender else ""
        if is_bot and username == info["bot"]:
            return msg.text or ""
    return None

def build_followup(label, response_text):
    """Read the bot's response and craft a SPECIFIC follow-up based on what it said."""
    if not response_text:
        return f"You didn't respond. This is your job. Report NOW: what are you doing?"

    lines = response_text.split("\n")
    text_lower = response_text.lower()

    # Find specific things to follow up on
    followups = []

    # Look for mentioned projects, files, issues
    mentioned_items = re.findall(r'(?:#\d+|[a-zA-Z_-]+\.(?:py|js|ts|md|yaml|json|sh)|\b(?:villa|database|api|endpoint|test|bug|fix|feature)\S*)', response_text)
    if mentioned_items:
        items = list(set(mentioned_items))[:3]
        followups.append(f"You mentioned {', '.join(items)}. For EACH: what's the current state, what will you change, and when will it be done?")

    # Look for numbered lists (improvements they listed)
    numbered = re.findall(r'(?:^|\n)\s*(\d+[\.\)]\s*.{10,60})', response_text)
    if len(numbered) >= 3:
        followups.append(f"You listed {len(numbered)} items. Pick your top 3 and for each: what EXACT file will you modify, what's the expected diff, and how will you test it?")

    # Look for vague words
    vague_phrases = ["will review", "plan to", "looking into", "considering", "might", "could", "should", "need to", "want to"]
    found_vague = [p for p in vague_phrases if p in text_lower]
    if found_vague:
        followups.append(f"I see vague language: '{found_vague[0]}'. Convert that to a SPECIFIC action: what file, what line, what change, by when?")

    # Look for "none", "idle", "no work"
    if any(w in text_lower for w in ["none", "idle", "no work", "nothing", "n/a"]):
        followups.append(f"You said something is 'none' or 'idle'. That's not acceptable. Find ONE thing in your repo that needs fixing and start on it. What will it be?")

    # Look for self-grade
    grade_match = re.search(r'(?:grade|rating)[:\s]*([A-F][+-]?)', response_text, re.I)
    if grade_match:
        grade = grade_match.group(1)
        if grade.startswith(("D", "F")):
            followups.append(f"You graded yourself {grade}. What ONE change would move you to a B? Be specific.")
        elif grade.startswith("C"):
            followups.append(f"You graded yourself {grade}. Good honesty. What's the gap between C and A? Name 2 concrete things.")

    # Default: ask for depth on whatever they said
    if not followups:
        first_substantive = ""
        for line in lines:
            if len(line.strip()) > 30:
                first_substantive = line.strip()[:80]
                break
        followups.append(f"You said: '{first_substantive}'. Elaborate: what specifically will you do about this in the next 30 minutes? Give me file paths and expected changes.")

    return "\n\n".join(followups)

async def main():
    client = TelegramClient(SESSION, 29672461, "0e0b535e8e0db252f86f0a6a8de3624e")
    await client.start()
    group = await client.get_entity(GROUP_ID)

    # ── TURN 1: Send review/assignment ──
    print("Turn 1: Sending...")
    for tid, prompt in T1.items():
        await client.send_message(group, prompt, reply_to=tid)
        print(f"  → {BOTS[tid]['label']}")

    print("  Waiting 90s...")
    await asyncio.sleep(90)

    # ── Read Turn 1 + build context-aware follow-ups ──
    print("\nTurn 1 responses + follow-up generation:")
    cutoff = time.time() - 120
    turn1_responses = {}

    for tid, info in BOTS.items():
        text = await read_bot_response(client, group, tid, info, cutoff)
        if text:
            lines = len(text.split("\n"))
            turn1_responses[tid] = text
            print(f"  ✅ {info['label']}: {lines} lines")
        else:
            turn1_responses[tid] = None
            print(f"  ❌ {info['label']}: no reply")

    # ── TURN 2: Send SPECIFIC follow-ups based on what each bot said ──
    print("\nTurn 2: Context-aware follow-ups...")
    for tid, info in BOTS.items():
        followup = build_followup(info["label"], turn1_responses.get(tid))
        await client.send_message(group, f"[Follow-up]\n\n{followup}", reply_to=tid)
        snippet = followup[:60].replace('\n', ' ')
        print(f"  → {info['label']}: {snippet}...")

    print("  Waiting 90s...")
    await asyncio.sleep(90)

    # ── Read Turn 2 responses ──
    print("\nTurn 2 responses:")
    cutoff2 = time.time() - 120
    turn2_responses = {}

    for tid, info in BOTS.items():
        text = await read_bot_response(client, group, tid, info, cutoff2)
        if text:
            lines = len(text.split("\n"))
            turn2_responses[tid] = text
            print(f"  ✅ {info['label']}: {lines} lines")
        else:
            print(f"  ⏳ {info['label']}: no reply")

    # ── TURN 3: Assign specific next-30-min deliverable based on conversation ──
    print("\nTurn 3: Assigning deliverables...")
    for tid, info in BOTS.items():
        t1 = turn1_responses.get(tid, "")
        t2 = turn2_responses.get(tid, "")
        combined = f"{t1}\n{t2}"

        # Extract what they committed to
        commitments = re.findall(r'(?:will|going to|plan to|next hour|deliverable)[:\s]*(.{20,80})', combined, re.I)

        if commitments:
            assignment = f"[Assignment] You committed to: '{commitments[0].strip()}'. I'm holding you to it. When I return in 30 minutes, show me the EVIDENCE: a commit hash, a PR link, or a file diff. No excuses."
        else:
            assignment = f"[Assignment] You haven't committed to a specific deliverable. Pick ONE thing from your improvement list and tell me RIGHT NOW: what file will you modify and what will the change be? I return in 30 min."

        await client.send_message(group, assignment, reply_to=tid)
        print(f"  → {info['label']}")

    # ── Summary ──
    t1_count = sum(1 for v in turn1_responses.values() if v)
    t2_count = sum(1 for v in turn2_responses.values() if v)
    print(f"\n=== Cycle {CYCLE}: T1={t1_count}/5 T2={t2_count}/5 assigned=5/5 ===")

    await client.disconnect()

asyncio.run(main())
PYEOF

  echo "[$TS] Cycle $CYCLE complete. Sleeping 30 min..."
  sleep 1800
done
