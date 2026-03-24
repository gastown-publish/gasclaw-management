import asyncio
import time
from telethon import TelegramClient

API_ID = 31673510
API_HASH = "20dc095d3d24ac960032c8f0e744d07e"
SESSION = "/home/nic/gasclaw-workspace/telegram-test/tg_test_session"
GROUP_ID = -1003810709807

BOTS = {
    "gasclaw_master_bot": "gasclaw",
    "minimax_gastown_publish_bot": "minimax", 
    "gasskill_agent_bot": "gasskill",
}

PASS = 0; FAIL = 0; RESULTS = []

def report(name, passed, detail=""):
    global PASS, FAIL
    if passed:
        PASS += 1; RESULTS.append(f"  ✅ {name}")
    else:
        FAIL += 1; RESULTS.append(f"  ❌ {name}: {detail}")

async def wait_reply(client, group, bot, timeout=30):
    deadline = time.time() + timeout
    seen = set()
    async for msg in client.iter_messages(group, limit=3):
        seen.add(msg.id)
    while time.time() < deadline:
        await asyncio.sleep(2)
        async for msg in client.iter_messages(group, limit=5):
            if msg.id not in seen:
                sender = await msg.get_sender()
                if sender and hasattr(sender, "username") and sender.username == bot:
                    return msg.text
                seen.add(msg.id)
    return None

async def main():
    client = TelegramClient(SESSION, API_ID, API_HASH)
    await client.start(phone="+66924734102")
    group = await client.get_entity(GROUP_ID)
    
    print("=" * 60)
    print("  ALL BOTS INTEGRATION TEST")
    print("=" * 60)
    
    for bot, label in BOTS.items():
        print(f"\n--- {label} (@{bot}) ---")
        
        # 1. Mention test
        print(f"  🧪 @mention response...")
        await client.send_message(group, f"@{bot} ping")
        reply = await wait_reply(client, group, bot, timeout=30)
        report(f"{label}: responds to @mention", reply is not None, "no reply")
        if reply: print(f"     → {reply[:60]}...")
        await asyncio.sleep(5)
        
        # 2. /subagents
        print(f"  🧪 /subagents menu...")
        await client.send_message(group, f"/subagents@{bot}")
        reply = await wait_reply(client, group, bot, timeout=20)
        report(f"{label}: /subagents", reply is not None and "spawn" in (reply or "").lower(), (reply or "no reply")[:60])
        if reply: print(f"     → {reply[:60]}...")
        await asyncio.sleep(5)
        
        # 3. Spawn an agent
        agents_map = {
            "gasclaw_master_bot": "crew-1",
            "minimax_gastown_publish_bot": "coordinator",
            "gasskill_agent_bot": "skill-dev",
        }
        agent = agents_map[bot]
        print(f"  🧪 spawn {agent}...")
        await client.send_message(group, f"/subagents@{bot} spawn {agent} Check the repo status with gh issue list and summarize")
        reply = await wait_reply(client, group, bot, timeout=45)
        ok = reply and "spawn" in reply.lower() and "fail" not in reply.lower() and "not allowed" not in reply.lower()
        report(f"{label}: spawn {agent}", ok, (reply or "no reply")[:60])
        if reply: print(f"     → {reply[:60]}...")
        await asyncio.sleep(5)
        
        # 4. /subagents list
        print(f"  🧪 /subagents list...")
        await client.send_message(group, f"/subagents@{bot} list")
        reply = await wait_reply(client, group, bot, timeout=20)
        report(f"{label}: /subagents list", reply is not None and ("subagent" in (reply or "").lower() or "active" in (reply or "").lower() or "running" in (reply or "").lower()), (reply or "no reply")[:60])
        if reply: print(f"     → {reply[:80]}...")
        await asyncio.sleep(8)
    
    # Final: non-mention test (all bots should ignore)
    print(f"\n--- Non-mention test (all bots) ---")
    print(f"  🧪 bots ignore non-mentioned message...")
    last_id = 0
    async for msg in client.iter_messages(group, limit=1):
        last_id = msg.id
    await asyncio.sleep(10)
    await client.send_message(group, "random message nobody should reply to this")
    await asyncio.sleep(20)
    found = False
    async for msg in client.iter_messages(group, limit=5):
        if msg.id <= last_id: break
        if msg.text and "random message" in msg.text: continue
        sender = await msg.get_sender()
        if sender and hasattr(sender, "username") and sender.username in BOTS:
            found = True; break
    report("all bots ignore non-mentioned", not found, "a bot replied")
    
    print()
    print("=" * 60)
    print(f"  RESULTS: {PASS} passed, {FAIL} failed out of {PASS+FAIL}")
    print("=" * 60)
    for r in RESULTS: print(r)
    
    await client.disconnect()
    return FAIL == 0

asyncio.run(main())
