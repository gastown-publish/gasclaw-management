# Troubleshooting

## Mayor "Not logged in"
- Container env needs `ANTHROPIC_API_KEY` + `ANTHROPIC_BASE_URL`
- `GASTOWN_KIMI_KEYS` in .env must be the LiteLLM key (bootstrap uses this)
- `proxy.py` respects env vars — don't revert to hardcoded Kimi URL

## OpenClaw "Unknown model" / "Missing auth"
- OpenClaw uses `models.json` + `auth-profiles.json`, NOT `ANTHROPIC_API_KEY`
- Set `MOONSHOT_API_KEY` in openclaw.json `env` section
- Run `openclaw models list` — Auth column must be "yes"
- Register with: `openclaw models auth paste-token --provider moonshot`

## Telegram "/agents" shows "(none)"
- Shows **running** subagents only — they disappear when tasks complete
- Spawn real work: `/subagents spawn coordinator <complex task>`
- Use `/subagents list` to see completed agents

## Telegram "Not authorized"
- User not in `allowFrom`/`groupAllowFrom` — add their user ID
- `groupPolicy: "open"` required (not `"allowlist"` with group IDs)

## Telegram "agentId not allowed for sessions_spawn"
- Need `subagents.allowAgents: ["*"]` in each agent's list entry
- NOT in `agents.defaults` — per-agent only

## Container crash-looping
- `gasclaw-container: not found` → empty src bind mount
- `Dolt process exited early` → data dir missing (auto-creates now)
- `not in a Gas Town workspace` → gt commands need cwd=/workspace/gt
- `agent 'kimi-claude' not found` → use 'claude' agent

## LiteLLM dead
```bash
ps aux | grep litellm | grep -v grep
# If empty:
cd /home/nic/data/models/MiniMax-M2.5 && source .venv/bin/activate
nohup litellm --config litellm-config.yaml --host 0.0.0.0 --port 4000 > /tmp/litellm.log 2>&1 &
```

## vLLM dead
```bash
cd /home/nic/data/models/MiniMax-M2.5 && ./scripts/start.sh 8
```

## Gateway dead
```bash
docker exec CONTAINER bash -c 'rm -f /root/.openclaw/gateway.lock && nohup openclaw gateway --port PORT > /tmp/openclaw-gw.log 2>&1 &'
```

## Gasskill mayor "dangerously-skip-permissions" error
- Claude Code rejects `--dangerously-skip-permissions` under root
- Fix: ensure `bypassPermissionsModeAccepted: true` in `.claude.json`
