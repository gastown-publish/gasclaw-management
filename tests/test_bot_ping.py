import asyncio, time
from telethon import TelegramClient

API_ID = 31673510
API_HASH = "20dc095d3d24ac960032c8f0e744d07e"
SESSION = "/home/nic/gasclaw-workspace/telegram-test/tg_test_session"
GROUP_ID = -1003810709807

BOTS = ["gasclaw_master_bot", "minimax_gastown_publish_bot", "gasskill_agent_bot"]
PASS = 0; FAIL = 0; R = []

async def get_reply(client, group, bot, after_id, timeout=30):
    deadline = time.time() + timeout
    while time.time() < deadline:
        await asyncio.sleep(3)
        async for msg in client.iter_messages(group, limit=10):
            if msg.id <= after_id: break
            sender = await msg.get_sender()
            if sender and hasattr(sender, "username") and sender.username == bot:
                return msg.text
    return None

async def main():
    global PASS, FAIL
    client = TelegramClient(SESSION, API_ID, API_HASH)
    await client.start(phone="+66924734102")
    group = await client.get_entity(GROUP_ID)
    
    print("=" * 60)
    print("  SIMPLE BOT TEST - ONE AT A TIME")
    print("=" * 60)
    
    for bot in BOTS:
        label = bot.split("_")[0]
        
        # Get last msg ID
        last_id = 0
        async for msg in client.iter_messages(group, limit=1):
            last_id = msg.id
        
        # Send mention
        print(f"\n🧪 @{bot} ping...")
        await client.send_message(group, f"@{bot} ping")
        reply = await get_reply(client, group, bot, last_id, timeout=30)
        if reply:
            PASS += 1; R.append(f"  ✅ {label}: {reply[:50]}")
            print(f"   ✅ {reply[:60]}")
        else:
            FAIL += 1; R.append(f"  ❌ {label}: no reply in 30s")
            print(f"   ❌ no reply")
        
        # Wait 15s between bots for messages to settle
        await asyncio.sleep(15)
    
    print(f"\n{'=' * 60}")
    print(f"  RESULTS: {PASS}/{PASS+FAIL}")
    print(f"{'=' * 60}")
    for r in R: print(r)
    await client.disconnect()

asyncio.run(main())
