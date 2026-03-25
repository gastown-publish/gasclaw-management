# Gasclaw Management

Central management hub for the Gasclaw platform — autonomous AI agent infrastructure running on 8x NVIDIA H100 80GB GPUs.

## What This Repo Is

This repo tracks the full infrastructure setup, configuration, testing, and ongoing management of the Gasclaw platform. It serves as the single source of truth for:

- **Infrastructure state** — what's running, how it's configured, how to fix it
- **Agent team configuration** — which bots manage which repos
- **Testing** — Telegram integration tests, CI verification, tmux capture patterns
- **Issue tracking** — all known bugs, features, and improvements tracked with beads

## Platform Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     Public Endpoints                            │
│  minimax.villamarket.ai     → Website (S3 + CloudFront)        │
│  app.minimax.villamarket.ai → DeerFlow Chat UI (CloudFront)    │
│  api.minimax.villamarket.ai → API (CloudFront → LiteLLM)       │
│  status.gpu.villamarket.ai  → Monitoring Dashboard             │
└───────────────────────────────┬─────────────────────────────────┘
                                │
┌───────────────────────────────▼─────────────────────────────────┐
│               LiteLLM Proxy (port 4000)                         │
│  Key auth, cost tracking, model routing                         │
└───────────────────────────────┬─────────────────────────────────┘
                                │
┌───────────────────────────────▼─────────────────────────────────┐
│               vLLM (port 8080)                                  │
│  MiniMax-M2.5, TP4+DP2+EP8, FP8, 8x H100 80GB, 128K ctx       │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│  Container        │ Bot                        │ Repo           │
│  gasclaw-dev      │ @gasclaw_master_bot        │ gasclaw        │
│  gasclaw-minimax  │ @minimax_gastown_pub_bot   │ minimax        │
│  gasclaw-gasskill │ @gasskill_agent_bot        │ gasskill       │
│  gasclaw-context  │ TBD                        │ context-hub    │
└─────────────────────────────────────────────────────────────────┘
```

## Managed Repos

| Repo | Container | Bot | Agents | Status |
|------|-----------|-----|--------|--------|
| [gastown-publish/gasclaw](https://github.com/gastown-publish/gasclaw) | gasclaw-dev | @gasclaw_master_bot | main, crew-1, crew-2 | CI green ✅ |
| [gastown-publish/minimax](https://github.com/gastown-publish/minimax) | gasclaw-minimax | @minimax_gastown_publish_bot | main, coordinator, developer, devops, tester, reviewer | CI green ✅ |
| [gastown-publish/gasskill](https://github.com/gastown-publish/gasskill) | gasclaw-gasskill | @gasskill_agent_bot | main, skill-dev, skill-tester | Active |
| [gastown-publish/context-hub](https://github.com/gastown-publish/context-hub) | gasclaw-context | TBD | main, content-curator, mcp-tester | Running |

## Monitoring Dashboard

Real-time monitoring at **https://status.gpu.villamarket.ai**

```bash
# Deploy/Update dashboard
cd dashboard && ./deploy.sh

# View locally
cd dashboard && python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt && python app.py
# Open http://localhost:5000
```

Dashboard shows:
- Container status (Docker)
- Gateway health (OpenClaw)
- Agent activity
- MiniMax service metrics (tokens/sec, parallel sessions)
- GPU status (8x H100)
- Beads issues

## Quick Reference

```bash
# Check all containers
docker ps --format "table {{.Names}}\t{{.Status}}" | grep gasclaw

# Check all gateways
for c in gasclaw-dev gasclaw-minimax gasclaw-gasskill; do
  echo -n "$c: " && docker exec $c curl -sf http://localhost:$(docker exec $c python3 -c "import json; print(json.loads(open('/root/.openclaw/openclaw.json').read())['gateway']['port'])")/health 2>&1
  echo ""
done

# Check all mayors
for c in gasclaw-dev gasclaw-minimax gasclaw-gasskill; do
  echo "=== $c ===" && docker exec $c bash -c "cd /workspace/gt && gt mayor status" 2>&1
done

# Run Telegram integration tests
cd tests && python3 test_all_bots.py

# Forum topic health (per-bot ping in each topic; uses gastown-publish/telethon)
# See docs/forum-health.md — requires ../telethon with .env + session
./scripts/forum_health.sh

# Restore @gasclaw_mgmt_bot Telegram token in container (after BotFather token is available)
# ./scripts/apply-mgmt-telegram-token.sh

# Check CI across all repos
for repo in gasclaw minimax gasskill; do
  echo "=== $repo ===" && gh run list --repo gastown-publish/$repo --limit 1
done
```

## Directory Structure

```
gasclaw-management/
├── README.md                    # This file
├── CLAUDE.md                    # Agent instructions
├── docs/
│   ├── infrastructure.md        # Full infra setup guide
│   ├── openclaw-config.md       # OpenClaw configuration reference
│   ├── telegram-setup.md        # Telegram bot setup + config rules
│   ├── forum-health.md          # Periodic per-topic bot health (Telethon)
│   └── troubleshooting.md       # All known issues + fixes
├── config/
│   ├── forum_health.json        # Topic ids + bots for scripts/forum_health.sh
│   ├── gasclaw-dev.env.example  # Container env templates
│   ├── gasclaw-minimax.env.example
│   ├── gasclaw-gasskill.env.example
│   └── litellm-config.yaml.example
├── tests/
│   ├── test_all_bots.py         # Telegram integration tests (Telethon)
│   ├── test_telegram_integration.py  # Per-bot detailed tests
│   └── verify-all.sh            # Full stack verification script
├── dashboard/                   # Monitoring dashboard (status.gpu.villamarket.ai)
│   ├── app.py                   # Flask backend API
│   ├── static/                  # Frontend assets
│   ├── aws/                     # CloudFront deployment
│   └── deploy.sh                # Deployment script
├── scripts/
│   ├── restart-gateways.sh      # Restart all OpenClaw gateways
│   ├── activate-agents.sh       # Activate all agent sessions
│   ├── forum_health.sh          # Telethon ping per forum topic (uses ../telethon)
│   ├── watchdog.sh              # Cron: restart gateways / vLLM / LiteLLM / funnel
│   └── check-health.sh          # Health check all services
└── issues/                      # Tracked issues (beads compatible)
    └── README.md
```
