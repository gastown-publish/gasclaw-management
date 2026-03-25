# Hourly progress report (Telethon + agents)

The host runs `forum_health.sh` with `config/forum_health.json`. Bots must answer with a **structured Markdown** report. The Telethon checker **rejects**:

- One-word replies (`OK`, `yes`, …)
- Replies shorter than `min_reply_chars` (default **200**)
- Missing `##` headings that cover keywords: **past**, **repo**, **measurable**, **improvement**
- No measurable repo signal (numbers, commits, PRs, CI, workflow)

See `config/forum_health.json` → `ping_message` for the exact prompt users and agents see.

OpenClaw hourly cron (`install-openclaw-hourly-progress-cron.sh`) should use a message that asks for the **same sections**, so in-app nudges match Telegram checks.
