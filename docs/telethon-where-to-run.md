# Where Telethon runs (vs `gasclaw-mgmt`)

## Why it isn’t “inside gasclaw-mgmt” by default

| Piece | What it is | Credential |
|--------|------------|------------|
| **`gasclaw-mgmt` container** | OpenClaw + **Telegram Bot API** (`@gasclaw_mgmt_bot`) | `channels.telegram.botToken` in `openclaw.json` |
| **Forum health (`gastown-telethon-forum-health`)** | **Telethon** = your **human user** account (MTProto) | `TELEGRAM_API_ID` / `API_HASH`, **phone**, **`*.session`** file |

Those are **different** Telegram identities and **different** APIs. The health check **posts as your user** into each forum topic, then checks that the **correct bot** answers. A bot container does not replace a **logged-in user session**.

So: **you do not need Telethon to run inside `gasclaw-mgmt`** for the design to work. The repo expects Telethon on a **host** (or any machine) next to the `telethon` clone, with cron calling `scripts/forum_health.sh`.

## What to do to “make it work” (recommended)

1. **On a machine that can reach Telegram** (your `nic` host is fine):
   - Clone [gastown-publish/telethon](https://github.com/gastown-publish/telethon) **next to** `gasclaw-management` (so `../telethon` exists), **or** set `GASTOWN_TELETHON_ROOT` to the clone path.
   - Create `telethon/.env` from `telethon/.env.example` with API id/hash, phone, group id, **`TELETHON_SESSION_PATH`** pointing at your **human** `.session` (e.g. under `telegram-test/`).
   - `cd telethon && python3 -m venv .venv && .venv/bin/pip install -e .`
   - Test once: `export TELETHON_FORUM_HEALTH_CONFIG=/path/to/gasclaw-management/config/forum_health.json && .venv/bin/python -m gastown_telethon.scripts.forum_health`

2. **Cron** (hourly is already the pattern you use):
   - `0 * * * * .../gasclaw-management/scripts/run_hourly_forum_health_with_escalation.sh >> /tmp/forum-health.log 2>&1`
   - Only **one** Telethon process may use the same `.session` at a time (`flock` in `forum_health.sh` avoids overlap).

3. **Escalation to OpenClaw** (optional): `GASCLAW_ESCALATE_ON_FAILURE=1` uses **`docker exec gasclaw-mgmt`** to message the **`infra`** agent — that part **does** touch `gasclaw-mgmt`, but Telethon still runs on the host.

That is the supported layout: **Telethon on host**, **OpenClaw bots in containers**.

## If you insist on running Telethon *inside* `gasclaw-mgmt`

Possible, but you must add **user-session** material to the container (not the bot token):

- Install Python + `gastown-telethon` in the image (or `pip install` at build time).
- **Bind-mount only** (no copying credentials into the image): a host directory with your **`*.session`** and an env file, mounted read-only if you prefer, e.g. `/run/telethon-secrets:ro`.
- Set `TELETHON_CONTAINER_SESSION_PATH` / `TELETHON_ENV_FILE` to paths **inside** the container that match those mounts (see `gastown-publish/telethon` `docker-compose.yml`).
- Set `GASTOWN_TELETHON_ROOT` to that mount path and run `forum_health.sh` from **cron inside the container** or use the **Telethon Docker** image next to mgmt (same bind-mount pattern).
- Ensure **no second** cron on the host uses the **same** session file (otherwise SQLite “database is locked”).

**Check both sides:** `scripts/verify_telegram_telethon_stack.sh` probes OpenClaw Telegram on `gasclaw-mgmt` and runs a Telethon Docker ping using host bind mounts only.

This duplicates what the host already does; use it only if you have a policy that “everything must run in the mgmt container.”

## Summary

- **Working setup:** Telethon + session on **host** (or one dedicated runner), `gasclaw-management` scripts + `config/forum_health.json`, cron hourly.
- **`gasclaw-mgmt` container:** runs the **management bot** and OpenClaw; it does **not** have to run Telethon unless you explicitly containerize the **human** session as above.
