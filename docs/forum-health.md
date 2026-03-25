# Forum topic health + hourly progress (Telegram)

Gasclaw runs one **OpenClaw** bot per container; each bot has a **dedicated forum topic** in `gastown_publish` (`-1003810709807`). This check uses a **human Telethon session** (same mechanism as integration tests) to:

1. Open each topic by id (918, 919, 920, 921).
2. Post the configured prompt **inside that topic** (no `@mention` required in-topic) — default text requires a **measurable hourly repo report** (`##` headings, commits/PRs/CI, counts). See [hourly-progress-template.md](hourly-progress-template.md).
3. Wait for a reply from the **expected bot username** in the **same thread** (see [gastown-publish/telethon](https://github.com/gastown-publish/telethon) forum matching).
4. **Validate** the reply (telethon `progress_report.py`): rejects one-word **OK**, replies that are too short, missing required sections, or no measurable repo signals.

If anything fails, use the printed debug hints, then on the affected container: `openclaw channels status --probe`, `openclaw doctor`, and confirm the gateway is listening (see [HANDOFF.md](../HANDOFF.md) for ports).

## Configuration

| File | Purpose |
|------|---------|
| [config/forum_health.json](../config/forum_health.json) | Topic ids, bot usernames, ping text, `min_reply_chars`, validation keywords |
| [gastown-publish/telethon](https://github.com/gastown-publish/telethon) | Implementation (`gastown-telethon-forum-health`) |

Edit `forum_health.json` if topics or bots change. Source of truth for topic ↔ bot mapping is [HANDOFF.md](../HANDOFF.md).

### OpenClaw: one bot per topic

Each container runs **one** Telegram bot. In that bot’s `openclaw.json`, under `channels.telegram.groups["-1003810709807"].topics`, set **`enabled: false`** for every topic id **except** the one that bot owns, and configure `requireMention` / in-topic behavior for that topic only. That keeps each agent in its own thread; see [gastown-publish/telethon `docs/gasclaw-integration.md`](https://github.com/gastown-publish/telethon/blob/main/docs/gasclaw-integration.md) (section *Forum topic isolation*).

The Telethon health checker only counts a reply if it appears **in the same forum thread** as the ping (not merely “any message from that bot elsewhere in the group”).

## One-off run

```bash
chmod +x scripts/forum_health.sh
export GASTOWN_TELETHON_ROOT=/path/to/telethon   # optional if ../telethon is correct
./scripts/forum_health.sh
```

The Telethon clone must have `.env` configured (see telethon `README.md`): `TELEGRAM_API_ID`, `TELEGRAM_API_HASH`, `TELEGRAM_PHONE`, `TELEGRAM_GROUP_ID`, `TELETHON_SESSION_PATH`.

## Two layers: Telethon (host) + OpenClaw cron (containers)

| Layer | What it does | Schedule |
|-------|----------------|----------|
| **Telethon** — `scripts/forum_health.sh` on a machine with your **human** session | Posts into **each** forum topic and **verifies** the right bot answers (end-to-end Telegram). | **Hourly** recommended: `0 * * * *` (UTC minute 0). |
| **OpenClaw cron** — inside each Gasclaw container | Schedules the **`main`** agent with a progress message; `--no-deliver` avoids spamming General — agents typically reply in their forum topic. | Same cadence: `0 * * * *` |

They are complementary: Telethon **proves** delivery per topic; OpenClaw cron **nudges** agents on a timer even without a human ping.

### Host cron (Telethon)

On a host with network access to Telegram and a valid session file:

```cron
0 * * * * /home/nic/gasclaw-workspace/gasclaw-management/scripts/forum_health.sh >> /tmp/forum-health.log 2>&1
```

Adjust the path to your clone. **Legacy:** some hosts used `*/15` for faster feedback; for “hourly progress reporting” use **`0 * * * *`** above.

The script uses `flock` on `/tmp/gastown-forum-health.lock` so only one Telethon process touches the session sqlite at a time.

**Credentials:** create `../telethon/.env` from `telethon/.env.example` (gitignored). This machine uses the same session path as `telegram-test/tg_test_session` unless you override `TELETHON_SESSION_PATH`.

**Management topic (`@gasclaw_mgmt_bot`):** if the container has no `channels.telegram.botToken`, Telegram polling is **not** running (`openclaw channels status --probe` shows “not configured”). Topic **921** is marked **`"optional": true`** in `forum_health.json` so the check still exits **0** while you restore the token. Use **`scripts/apply-mgmt-telegram-token.sh`** (reads `GASCLAW_MGMT_TELEGRAM_BOT_TOKEN` or `~/.config/gastown/gasclaw_mgmt_bot_token`), then set **`optional": false`** on that topic when you want a hard failure.

**Agent “model 401” in replies:** transport is healthy; fix LiteLLM / `MOONSHOT_API_KEY` / `models.json` per `HANDOFF.md` (gateway sometimes resets to `kimi-coding/k2p5`).

### OpenClaw cron (per container)

Install once per running container (from a host with `docker`):

```bash
chmod +x scripts/install-openclaw-hourly-progress-cron.sh
./scripts/install-openclaw-hourly-progress-cron.sh              # print commands
./scripts/install-openclaw-hourly-progress-cron.sh --apply     # register jobs
```

Override defaults with env vars: `OPENCLAW_PROGRESS_CRON`, `OPENCLAW_PROGRESS_JOB_NAME`, `OPENCLAW_PROGRESS_AGENT`, `OPENCLAW_PROGRESS_MESSAGE`.

If a job name already exists, run `docker exec <container> openclaw cron list` and `openclaw cron remove <id>` before re-adding.

Reference: `openclaw cron add --name … --cron "0 * * * *" --agent main --message "…" --no-deliver` (see Gasclaw `maintainer/knowledge/openclaw-reference.md`).

This is complementary to [scripts/watchdog.sh](../scripts/watchdog.sh) (HTTP/gateway restarts). Forum health validates **end-to-end Telegram** delivery per bot; OpenClaw cron keeps agents on a **scheduled** progress cadence inside the gateway.

## Exit codes

`0` — all topics got a bot reply within the timeout.  
Non-zero — at least one topic failed (see stderr / log).

## Failure → mayor escalation (gasclaw-mgmt)

If forum health fails, you can notify the **gasclaw-mgmt** OpenClaw agent (default **`infra`**) with logs so it **watches Gastown `gt mayor`**, fixes gateway/Telegram, and **retests** until resolved. See [mayor-escalation.md](mayor-escalation.md) and run [`scripts/forum_health_escalate.sh`](../scripts/forum_health_escalate.sh) with `GASCLAW_ESCALATE_ON_FAILURE=1`.
