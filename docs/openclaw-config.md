# OpenClaw Configuration Reference

**ALWAYS read this before changing any openclaw.json config.**

## Telegram Config

```json
{
  "channels": {
    "telegram": {
      "dmPolicy": "allowlist",
      "allowFrom": ["2045995148", "8662958386"],
      "groupPolicy": "open",
      "groupAllowFrom": ["2045995148", "8662958386"],
      "groups": {
        "-1003810709807": {
          "requireMention": true,
          "groupPolicy": "open"
        }
      },
      "threadBindings": {
        "enabled": true,
        "spawnSubagentSessions": true,
        "spawnAcpSessions": true
      }
    }
  }
}
```

### Rules
- `groupAllowFrom` takes **USER IDs**, never group IDs
- `requireMention: true` — bot only responds when @mentioned (default, correct)
- `groupPolicy: "open"` at top level — allows configured groups
- `commands.native: "auto"` — don't change without understanding
- After changing config: `openclaw config validate`

## Agent Config

```json
{
  "agents": {
    "defaults": {
      "model": {"primary": "moonshot/kimi-k2.5"},
      "subagents": {"maxChildrenPerAgent": 10}
    },
    "list": [
      {"id": "main", "identity": {"name": "Overseer", "emoji": "🏭"}, "subagents": {"allowAgents": ["*"]}},
      {"id": "crew-1", "identity": {"name": "Developer", "emoji": "💻"}, "subagents": {"allowAgents": ["*"]}}
    ]
  }
}
```

### Rules
- `subagents.allowAgents: ["*"]` per agent — allows spawning any agent
- Do NOT add `instructions` to agent list — not a valid key
- Team knowledge goes in `~/.openclaw/workspace/AGENTS.md`
- Each sub-agent needs `auth-profiles.json` + `models.json` in their agent dir

## Model Provider

```json
{
  "env": {"MOONSHOT_API_KEY": "sk-LITELLM_KEY"}
}
```

Plus `~/.openclaw/agents/main/agent/models.json`:
```json
{
  "providers": {
    "moonshot": {
      "baseUrl": "https://api.minimax.villamarket.ai/v1",
      "api": "openai-completions",
      "models": [{"id": "kimi-k2.5", "name": "MiniMax M2.5"}],
      "apiKey": "MOONSHOT_API_KEY"
    }
  }
}
```

LiteLLM must have matching model `kimi-k2.5`.

## /agents vs /subagents

- `/agents` — gateway native command, shows **currently running** subagents
- `/subagents list` — shows all subagents (including completed)
- `/subagents spawn <agent> <task>` — spawns agent with work
- `/subagents send 1 <msg>` — send message to agent by INDEX
- Agents appear in `/agents` only while running; use real tasks, not "stand by"

## Validation
```bash
openclaw config validate
openclaw doctor
openclaw channels status --probe
openclaw models list  # Auth column must be "yes"
openclaw agents list --bindings
```
