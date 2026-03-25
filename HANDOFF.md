# Handoff Summary — 2026-03-25

## Platform State

### 4 Containers Running

| Container | User | Bot | Repo | Gateway | Status |
|-----------|------|-----|------|---------|--------|
| gasclaw-dev | /home/gasclaw/ | @gasclaw_master_bot | gastown-publish/gasclaw | :18794 | ✅ Working |
| gasclaw-minimax | /home/minimax/ | @minimax_gastown_publish_bot | gastown-publish/minimax | :18793 | ✅ Working |
| gasclaw-gasskill | /home/gasskill/ | @gasskill_agent_bot | gastown-publish/gasskill | :18796 | ✅ Working |
| gasclaw-mgmt | /home/gasclaw-mgmt/ | @gasclaw_mgmt_bot | gastown-publish/gasclaw-management | :18798 | ✅ Working |

### Agent Teams

**gasclaw-dev**: main (Overseer), crew-1 (Developer), crew-2 (Reviewer)
**gasclaw-minimax**: main (Overseer), coordinator (Tech Lead), developer (Backend Dev), devops (DevOps), tester (Test Engineer), reviewer (Code Reviewer)
**gasclaw-gasskill**: main (Overseer), skill-dev (Skill Developer), skill-tester (Skill Tester)
**gasclaw-mgmt**: main (Management Overseer), infra (Infra Monitor), ci-watcher (CI Watcher)

### Infrastructure
- **vLLM**: port 8080, MiniMax-M2.5, 8x H100, TP4+DP2+EP8
- **LiteLLM**: port 4000, 6 model aliases
- **Tailscale Funnel**: `tailscale funnel 4000` (foreground process) exposes :443 → :4000
- **CloudFront**: `api.minimax.villamarket.ai` → E2HGXLMODJQ9DP → Tailscale → LiteLLM
- **Telegram Group**: -1003810709807, topics: 638 (Status), 639 (CI), 640 (Alerts), 641 (Chat)

### Test Results (python3 /tmp/test_all_bots.py)
```
11/13 passing
✅ gasclaw: @mention, /subagents, spawn, list
✅ minimax: @mention, /subagents, spawn, list
✅ gasskill: /subagents, spawn, list (mention timing flaky)
❌ gasskill @mention: timing issue in test (works in Telegram)
❌ non-mention: stale reply from previous test leaks
```

## Critical Fixes Made This Session

1. **Created `api.minimax.villamarket.ai` CloudFront** (E2HGXLMODJQ9DP)
   - Root cause of 502: no CF distribution existed, fell through to website CF with /minimax path prefix
   - Fix: new CF with AllViewer origin request policy, port 443, no origin path

2. **Tailscale Funnel for LiteLLM**
   - `tailscale funnel 4000` as foreground process
   - Do NOT use `serve --bg` + `funnel --bg` on port 443 — creates loop
   - This process must be running for CloudFront to reach LiteLLM

3. **OpenClaw model config**
   - Model: `moonshot/kimi-k2.5` (NOT `kimi-coding/k2p5`)
   - `baseUrl: https://api.minimax.villamarket.ai/v1` in models.json
   - `MOONSHOT_API_KEY` in openclaw.json env section
   - Each sub-agent needs own models.json copied from main

4. **Gasclaw CI fixed** — all 1021 tests passing, lint clean

## Known Issues (10 beads tracked)

| P | Issue |
|---|-------|
| P0 | Fix minimax security issues #15-#17 |
| P1 | Fix minimax mayor context overflow |
| P1 | Bootstrap should write workspace AGENTS.md |
| P1 | Bootstrap should activate agent sessions |
| P2 | Auto-spawn thread-bound agents on Telegram |
| P2 | Add Telethon tests to CI |
| P2 | LiteLLM/vLLM auto-restart |
| P2 | Gateway auto-restart |

## Things That Break on Container Restart

1. **OpenClaw gateway** — not auto-started, must run: `nohup openclaw gateway --port PORT &`
2. **Agent sessions** — must activate: `openclaw agent --local --agent <id> --message "online"`
3. **models.json** — gateway may overwrite, must verify `moonshot/kimi-k2.5`
4. **Tailscale funnel** — foreground process, must restart: `tailscale funnel 4000`

## Key Files

- Test script: `/tmp/test_all_bots.py`
- Telethon session: `/home/nic/gasclaw-workspace/telegram-test/tg_test_session.session`
- LiteLLM config: `/home/nic/data/models/MiniMax-M2.5/litellm-config.yaml`
- Gist: https://gist.github.com/villaApps/93be609d185e5a4009112337c15a7a6c
- Repo: https://github.com/gastown-publish/gasclaw-management
