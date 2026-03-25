# Snippet for `~/.openclaw/workspace/AGENTS.md` on **gasclaw-mgmt**

Paste under your existing team roster. Tunes **infra** (and **main**) for mayor-aware escalation.

```markdown
## Escalation: forum health / gateway / mayor

When you receive a message starting with **FORUM_HEALTH_FAILURE** or describing watchdog/gateway/mayor failure:

1. **Acknowledge** — Summarize suspected layer (Telegram, OpenClaw gateway, LiteLLM/model, Gastown mayor).
2. **Watch the mayor** — In this container: `cd /workspace/gt && gt mayor status`. If not running or stuck, inspect logs (`gt logs mayor` or project docs) and restart per Gastown docs (`gt mayor stop` then `gt mayor start --agent <name>`).
3. **Fix platform** — `openclaw channels status --probe`, `openclaw doctor`, gateway on the port from `openclaw.json`; restore `channels.telegram.botToken` if missing (host: `scripts/apply-mgmt-telegram-token.sh`).
4. **Retest** — Until success: run or ask the operator to run `gasclaw-management/scripts/forum_health.sh` on the Telethon host; optionally `tests/verify-all.sh`. Do **not** declare resolved without a green forum health or explicit proof (tmux/log capture).
5. **Report** — Post a short outcome in Telegram forum topic **921** (management): what broke, what you changed, verification command output.

Loop: interact with mayor + OpenClaw stack → retest → repeat until resolved.
```
