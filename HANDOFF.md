# Handoff — Gasclaw Platform Management

**Updated**: 2026-03-25
**Repo**: https://github.com/gastown-publish/gasclaw-management
**Gist**: https://gist.github.com/villaApps/93be609d185e5a4009112337c15a7a6c

## Goal

Run an autonomous AI agent platform with 4 Docker containers, each managing a GitHub repo via Telegram bots. Agents should respond in Telegram, create PRs, fix CI, and manage issues — all tracked with beads.

## Current Progress

### 5 Containers (4 working + 1 planned)

| Container | User | Bot | Repo | Gateway | Topic |
|-----------|------|-----|------|---------|-------|
| gasclaw-dev | /home/gasclaw/ | @gasclaw_master_bot | gastown-publish/gasclaw | :18794 | 918 (🏭 gasclaw) |
| gasclaw-minimax | /home/minimax/ | @minimax_gastown_publish_bot | gastown-publish/minimax | :18793 | 919 (📦 minimax) |
| gasclaw-gasskill | /home/gasskill/ | @gasskill_agent_bot | gastown-publish/gasskill | :18796 | 920 (🔧 gasskill) |
| gasclaw-mgmt | /home/gasclaw-mgmt/ | @gasclaw_mgmt_bot | gastown-publish/gasclaw-management | :18798 | 921 (📊 management) |
| gascontext | /home/gascontext/ | TBD (@gascontext_bot) | gastown-publish/context-hub | :18797 | TBD (📚 context-hub) |

### Agent Teams

- **gasclaw-dev**: main, crew-1 (Developer), crew-2 (Reviewer)
- **gasclaw-minimax**: main, coordinator (Tech Lead), developer, devops, tester, reviewer
- **gasclaw-gasskill**: main, skill-dev, skill-tester
- **gascontext**: main (📚 Context Hub Overseer), content-curator (📝), mcp-tester (🔌)
- **gasclaw-mgmt**: main, infra (Infra Monitor), ci-watcher

### Infrastructure

- **vLLM**: port 8080, MiniMax-M2.5, 8x H100 80GB, TP4+DP2+EP8
- **LiteLLM**: port 4000, models: minimax-m2.5, claude-sonnet-4-6, claude-opus-4-6, kimi-k2.5
- **Tailscale Funnel**: `tailscale funnel 4000` (FOREGROUND process) exposes :443 → :4000
- **CloudFront**: `api.minimax.villamarket.ai` → E2HGXLMODJQ9DP → Tailscale:443 → LiteLLM:4000
- **Telegram Group**: -1003810709807 (gastown_publish), forum with 5 topics

### Telegram Topics (cleaned up)

| Thread | Topic | Bot | Mention required |
|--------|-------|-----|-----------------|
| 1 | General | All (human chat) | Yes |
| 918 | 🏭 gasclaw | @gasclaw_master_bot | No (auto-responds) |
| 919 | 📦 minimax | @minimax_gastown_publish_bot | No (auto-responds) |
| 920 | 🔧 gasskill | @gasskill_agent_bot | No (auto-responds) |
| 921 | 📊 management | @gasclaw_mgmt_bot | No (auto-responds) |

Each bot only responds in its own topic without @mention. In General and other topics, @mention is required.

### Test Results (`python3 /tmp/test_all_bots.py`)

```
17/18 passing (last run)
✅ gasclaw: @mention, /subagents, spawn crew-1, list
✅ minimax: @mention, /subagents, spawn coordinator, list
✅ gasskill: @mention, /subagents, spawn skill-dev, list
✅ mgmt: @mention, /subagents, spawn infra, list
❌ non-mention test: timing (stale spawn reply leaks into window)
✅ API endpoint: HTTP 200
```

### CI Status

- **gasclaw**: ✅ Green (1021 tests, lint, types)
- **minimax**: ✅ Green
- **gasskill**: No CI configured yet

## Context Hub / Gashub Integration

All 4 containers have `gashub` CLI + MCP server installed:

```bash
# CLI commands (available in all containers)
gashub search openai          # search docs
gashub get openai/chat --lang py  # fetch documentation
gashub annotate <id> "note"   # add agent annotations

# MCP server (configured in Claude Code settings)
gashub-mcp                    # stdio MCP server with 5 tools
# Tools: gashub_search, gashub_get, gashub_list, gashub_annotate, gashub_feedback
```

- **Install path**: `/opt/gashub/cli/` (symlinked to `/usr/local/bin/gashub`)
- **MCP config**: `~/.claude-kimigas/settings.json` → `mcpServers.gashub`
- **Repo**: [gastown-publish/context-hub](https://github.com/gastown-publish/context-hub)
- **Registry**: 1,560+ entries (docs + skills)

## What Worked

1. **OpenClaw model config**: `moonshot/kimi-k2.5` in openclaw.json + matching `models.json` per agent with `baseUrl: https://api.minimax.villamarket.ai/v1`
2. **Agent team via workspace AGENTS.md**: Write `~/.openclaw/workspace/AGENTS.md` with team roster — gets injected into LLM system prompt
3. **Per-agent subagents.allowAgents: ["*"]**: Required in each agent's list entry (not defaults) for `/subagents spawn` to work
4. **Topic routing**: Per-topic `requireMention: false` in the bot's own topic, `enabled: false` for other bots' topics
5. **Telethon integration tests**: Session saved at `/home/nic/gasclaw-workspace/telegram-test/tg_test_session.session` — no OTP needed
6. **CloudFront for API**: New distribution E2HGXLMODJQ9DP with AllViewer origin request policy (Host header needed for Tailscale)

## What Didn't Work

1. **`tailscale serve --bg` + `tailscale funnel --bg` on port 443**: Creates a loop (443 → 443). Use foreground `tailscale funnel 4000` instead.
2. **`api.minimax.villamarket.ai` via old setup**: No dedicated CloudFront existed. DNS pointed to API Gateway, requests fell through to website CF which prepends `/minimax` to path → 404.
3. **`instructions` key in openclaw.json agent list**: Not a valid field — use workspace AGENTS.md instead.
4. **`session.spawnAllowedAgentIds`**: Not a valid config key. The correct key is per-agent `subagents.allowAgents` in the agents list.
5. **`commands.native: true/false`**: Changing this breaks `/agents` command authorization. Keep as `"auto"`.
6. **OpenClaw `kimi-coding/k2p5` model**: Default model in fresh containers — MUST be changed to `moonshot/kimi-k2.5` after every container restart.
7. **Gateway overwrites models.json on restart**: Must verify model config after every gateway restart.
8. **`groupAllowFrom` with group IDs**: Only takes USER IDs. Never put group chat IDs there.

## Things That Break on Container Restart

1. **OpenClaw gateway** — not auto-started: `nohup openclaw gateway --port PORT > /tmp/gw.log 2>&1 &`
2. **Agent sessions** — must activate: `openclaw agent --local --agent <id> --message "online"`
3. **models.json** — gateway may overwrite to `kimi-coding/k2p5`, must verify `moonshot/kimi-k2.5`
4. **Tailscale funnel** — foreground process dies: `tailscale funnel 4000`
5. **Sub-agent auth** — copy `models.json` from main agent to all sub-agents

## Next Steps

### Immediate (P0-P1)

1. **Fix the 1 remaining test failure** — non-mention test timing issue (stale spawn reply)
2. **Fix minimax security issues** — gastown-publish/minimax #15 (hardcoded DB password), #16 (command injection), #17 (insecure CORS)
3. **Auto-restart services** — Tailscale funnel, OpenClaw gateways, LiteLLM need supervisor/systemd
4. **Bootstrap improvements** — write AGENTS.md, activate agent sessions, fix model config on startup (issues #340, #341)

### Medium (P2)

5. **Telegram integration tests in CI** — move `/tmp/test_all_bots.py` to repo, run in GitHub Actions
6. **Auto-spawn thread-bound agents** — `/agents` gateway command shows (none) after tasks complete (#343)
7. **Periodic health reporting** — cron on mgmt container to check all services and report to management topic
8. **Monitor Telegram for errors** — Telethon listener that triggers debugging on error messages

### Beads Issues (10 tracked)

```bash
cd /home/nic/gasclaw-workspace/gasclaw-management && bd ready
```

| Beads ID | GH# | P | Title |
|----------|-----|---|-------|
| 4u0 | #6 | P0 | Fix minimax security issues #15-#17 |
| 1j5 | #7 | P1 | Fix minimax mayor context overflow |
| 9kc | #8 | P1 | Fix gasskill mayor root permission error |
| cx0 | #9 | P1 | Bootstrap should activate agent sessions |
| yz4 | #10 | P1 | Bootstrap should write workspace AGENTS.md |
| 27k | #1 | P2 | OpenClaw gateway auto-restart on crash |
| k62 | #2 | P2 | LiteLLM and vLLM auto-restart on crash |
| 5sd | #3 | P2 | Add Telethon integration tests to CI |
| 9t4 | #4 | P2 | Auto-spawn thread-bound agents on Telegram start |
| k0t | #5 | P2 | Fix Telegram groupPolicy per docs |

## Key Files

| File | Purpose |
|------|---------|
| `/tmp/test_all_bots.py` | Full 4-bot integration test (Telethon) |
| `/home/nic/gasclaw-workspace/telegram-test/tg_test_session.session` | Telethon session (no OTP) |
| `/home/nic/data/models/MiniMax-M2.5/litellm-config.yaml` | LiteLLM model config |
| `/home/nic/gasclaw-workspace/gasclaw/` | Gasclaw source + tests |
| `/home/{gasclaw,minimax,gasskill,gasclaw-mgmt}/gasclaw/.env` | Container env files |
| `/home/nic/gasclaw-workspace/gasclaw/reference/openclaw-telegram.md` | OpenClaw Telegram config reference |
| `/home/nic/gasclaw-workspace/gasclaw-management/prompts/context-hub-fork-handoff.md` | Handoff prompt: fork Context Hub, MCP, Gasclaw-managed repo, absolute paths |

## OpenClaw Config Reference

**ALWAYS read `docs/openclaw-config.md` before changing any config.**

```bash
# Verify after ANY change
openclaw config validate
openclaw doctor
openclaw models list  # Auth must be "yes"
```

**Critical config per container:**
```json
{
  "agents.defaults.model.primary": "moonshot/kimi-k2.5",
  "env.MOONSHOT_API_KEY": "sk-9vMJQmXKcQHjP4pFviqsxA",
  "channels.telegram.groups.-1003810709807.requireMention": true,
  "channels.telegram.groups.-1003810709807.topics.TOPIC_ID.requireMention": false,
  "agents.list[].subagents.allowAgents": ["*"]
}
```
