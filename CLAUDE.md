# CLAUDE.md — Gasclaw Management Agent Instructions

You manage the Gasclaw platform infrastructure: 3 Docker containers running autonomous AI agents on 8x H100 GPUs.

## MANDATORY: CI Must Pass

**NEVER merge a PR unless ALL GitHub Actions checks pass.** Verify with `gh pr checks`.

## MANDATORY: Test with tmux capture

**Never assume something works without capturing real output.** Use tmux capture-pane as evidence.

## MANDATORY: Read OpenClaw docs before config changes

**ALWAYS read `docs/openclaw-config.md` before touching openclaw.json.** Invalid config silently breaks.

## Platform Quick Reference

### Containers
| Container | Port | Bot | Repo |
|-----------|------|-----|------|
| gasclaw-dev | 18794 | @gasclaw_master_bot | gastown-publish/gasclaw |
| gasclaw-minimax | 18793 | @minimax_gastown_publish_bot | gastown-publish/minimax |
| gasclaw-gasskill | 18796 | @gasskill_agent_bot | gastown-publish/gasskill |

### Key Services
- **vLLM**: port 8080 (MiniMax M2.5, 8x H100)
- **LiteLLM**: port 4000 (proxy, key management)
- **API**: https://api.minimax.villamarket.ai

### Telegram Group
- Group ID: `-1003810709807`
- Owner: `2045995148`
- Test account: `8662958386` (+66 92-473-4102)
- `requireMention: true` — bots only respond when @mentioned

### OpenClaw Config Rules
- `groupPolicy: "open"`, `groupAllowFrom: ["2045995148", "8662958386"]`
- `commands.native: "auto"` — don't change
- Per-agent `subagents.allowAgents: ["*"]` — allows spawning
- `acp.allowedAgents: [list]` — allows ACP connections
- Model: `moonshot/kimi-k2.5` → LiteLLM → vLLM
- `MOONSHOT_API_KEY` in `env` section of openclaw.json

### After Gateway Restart
Must activate agents:
```bash
export MOONSHOT_API_KEY=sk-KEY
for agent in main crew-1 crew-2; do
  openclaw agent --local --agent $agent --message "Agent online."
done
```

### Testing
```bash
# Telegram integration
cd tests && python3 test_all_bots.py

# Unit tests (gasclaw repo)
cd /home/nic/gasclaw-workspace/gasclaw && source .venv/bin/activate
python -m pytest tests/unit/ -q && ruff check src/
```

## Issue Tracking with Beads

Use `bd` for all issue tracking:
```bash
bd ready              # Find work
bd show <id>          # View issue
bd update <id> --claim  # Claim work
bd close <id>         # Complete
```
