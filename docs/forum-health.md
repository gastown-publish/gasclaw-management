# Forum topic health (Telegram)

Gasclaw runs one **OpenClaw** bot per container; each bot has a **dedicated forum topic** in `gastown_publish` (`-1003810709807`). This check uses a **human Telethon session** (same mechanism as integration tests) to:

1. Open each topic by id (918, 919, 920, 921).
2. Post a short health ping **inside that topic** (no `@mention` required in-topic).
3. Wait for a reply from the **expected bot username**.

If anything fails, use the printed debug hints, then on the affected container: `openclaw channels status --probe`, `openclaw doctor`, and confirm the gateway is listening (see [HANDOFF.md](../HANDOFF.md) for ports).

## Configuration

| File | Purpose |
|------|---------|
| [config/forum_health.json](../config/forum_health.json) | Topic ids, bot usernames, ping text, timeout |
| [gastown-publish/telethon](https://github.com/gastown-publish/telethon) | Implementation (`gastown-telethon-forum-health`) |

Edit `forum_health.json` if topics or bots change. Source of truth for topic ↔ bot mapping is [HANDOFF.md](../HANDOFF.md).

## One-off run

```bash
chmod +x scripts/forum_health.sh
export GASTOWN_TELETHON_ROOT=/path/to/telethon   # optional if ../telethon is correct
./scripts/forum_health.sh
```

The Telethon clone must have `.env` configured (see telethon `README.md`): `TELEGRAM_API_ID`, `TELEGRAM_API_HASH`, `TELEGRAM_PHONE`, `TELEGRAM_GROUP_ID`, `TELETHON_SESSION_PATH`.

## Periodic schedule

Add **cron** or **systemd timer** on a host that has network access to Telegram and a valid session file:

```cron
*/15 * * * * /home/nic/gasclaw-workspace/gasclaw-management/scripts/forum_health.sh >> /tmp/forum-health.log 2>&1
```

This is complementary to [scripts/watchdog.sh](../scripts/watchdog.sh) (HTTP/gateway restarts). Forum health validates **end-to-end Telegram** delivery per bot.

## Exit codes

`0` — all topics got a bot reply within the timeout.  
Non-zero — at least one topic failed (see stderr / log).
