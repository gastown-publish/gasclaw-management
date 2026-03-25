# gasclaw-context — Context Hub stack (mayor / ops)

**Purpose:** Dedicated Gasclaw container for [gastown-publish/context-hub](https://github.com/gastown-publish/context-hub).

## Names (use these in scripts and muscle memory)

| What | Value |
|------|--------|
| **Docker container** | `gasclaw-context` — starts with `gasclaw-` so `docker ps --filter name=gasclaw-` lists all platform stacks together |
| **Compose project** | `gasclaw-context` (see `/home/gascontext/gasclaw/docker-compose.yml`) |
| **Host Unix user** | `gascontext` (home: `/home/gascontext/`) — unchanged; only the **container** name uses the `gasclaw-` prefix |
| **OpenClaw gateway** | port **18797** (host and container) |
| **Rig repo** | `GT_RIG_URL` → `gastown-publish/context-hub` in `/home/gascontext/gasclaw/.env` |

## Quick commands

```bash
docker ps --filter name=gasclaw-context
docker exec gasclaw-context tmux ls
docker exec gasclaw-context bash -c 'curl -sf http://127.0.0.1:18797/health || true'
```

Management scripts in this repo: `scripts/watchdog.sh`, `scripts/restart-gateways.sh`, `scripts/activate-agents.sh` (agents: **main**, **content-curator**, **mcp-tester**).

## Telegram

Bot and forum topic are still **TBD** — see `HANDOFF.md`. When wired, document the topic ID here.

## Related

- Env template: `config/gascontext.env.example`
- Full platform: [infrastructure.md](infrastructure.md)
