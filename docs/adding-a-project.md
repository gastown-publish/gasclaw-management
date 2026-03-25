# Adding a New Project to the Gasclaw Platform

This guide explains how to add a new GitHub repo as a Gasclaw-managed project with its own container, Telegram bot, and agent team.

## Prerequisites

- SSH access to the GPU host (`gpu-workspace`)
- GitHub org access to `gastown-publish`
- Telegram account with BotFather access
- Existing Gasclaw base image (`gasclaw-dev-gasclaw:latest`)

## Overview

Each project gets:
- A **GitHub repo** under `gastown-publish/`
- A **Docker container** running the Gasclaw image
- An **OpenClaw gateway** on a unique port
- A **Telegram bot** responding in a dedicated forum topic
- An **agent team** (main + specialists)
- **gashub** CLI + MCP for documentation access
- **Beads** issue tracking

## Step-by-Step

### 1. Create the GitHub Repo

```bash
# Create repo (or fork an existing one)
gh repo create gastown-publish/<project-name> --public --description "Description here"

# Clone locally
cd /home/nic/gasclaw-workspace
git clone https://github.com/gastown-publish/<project-name>.git
```

### 2. Register a Telegram Bot

1. Open Telegram, message [@BotFather](https://t.me/BotFather)
2. Send `/newbot`
3. Name: `<project-name> Gastown Publish`
4. Username: `<project-name>_gastown_publish_bot` (or shorter)
5. Save the bot token — you'll need it for the `.env` file

### 3. Create a Telegram Forum Topic

In the `gastown_publish` group (`-1003810709807`):

1. Create a new topic (e.g. "📦 project-name")
2. Note the **topic ID** (visible in the URL when you click the topic, or from the Telethon API)
3. The bot will auto-respond in this topic without @mention

### 4. Choose a Port

Pick the next available gateway port:

| Port | Container |
|------|-----------|
| 18793 | gasclaw-minimax |
| 18794 | gasclaw-dev |
| 18796 | gasclaw-gasskill |
| 18797 | gascontext (reserved) |
| 18798 | gasclaw-mgmt |
| **18799** | **next available** |

### 5. Create the Environment File

```bash
cat > /home/nic/gasclaw-workspace/gasclaw-management/config/<project-name>.env.example << 'EOF'
ANTHROPIC_BASE_URL=https://api.minimax.villamarket.ai
ANTHROPIC_API_KEY=sk-LITELLM_KEY
GASTOWN_KIMI_KEYS=sk-LITELLM_KEY
OPENCLAW_KIMI_KEY=sk-LITELLM_KEY
TELEGRAM_BOT_TOKEN=YOUR_BOT_TOKEN
TELEGRAM_OWNER_ID=2045995148
TELEGRAM_GROUP_IDS=-1003810709807
TELEGRAM_ALLOW_IDS=2045995148
GT_RIG_URL=https://TOKEN@github.com/gastown-publish/<project-name>.git
GT_AGENT_COUNT=2
DOLT_PORT=<unique-dolt-port>
GATEWAY_PORT=<chosen-port>
MONITOR_INTERVAL=300
ACTIVITY_DEADLINE=3600
EOF

# Create the actual .env with real values
cp config/<project-name>.env.example /home/<project-name>/gasclaw/.env
# Edit with real tokens
```

### 6. Create the Container

```bash
# Create user home directory
sudo mkdir -p /home/<project-name>/gasclaw
sudo cp -r /home/nic/gasclaw-workspace/gasclaw/src/gasclaw /home/<project-name>/gasclaw/src/gasclaw

# Run the container
docker run -d \
  --name gasclaw-<project-name> \
  --init \
  -p <port>:<port> \
  -v gasclaw-<project-name>-openclaw:/root/.openclaw \
  -v gasclaw-<project-name>-dolt:/root/.dolt \
  -v gasclaw-<project-name>-state:/root/.gasclaw \
  -v gasclaw-<project-name>-claude:/root/.claude-kimigas \
  -v gasclaw-<project-name>-workspace:/workspace \
  --restart unless-stopped \
  --env-file /home/<project-name>/gasclaw/.env \
  gasclaw-dev-gasclaw
```

Or use docker-compose:

```yaml
# /home/<project-name>/gasclaw/docker-compose.yml
services:
  gasclaw:
    image: gasclaw-dev-gasclaw
    container_name: gasclaw-<project-name>
    init: true
    ports:
      - "<port>:<port>"
    volumes:
      - ./src/gasclaw:/usr/local/lib/python3.13/site-packages/gasclaw
      - gasclaw-<project-name>-openclaw:/root/.openclaw
      - gasclaw-<project-name>-dolt:/root/.dolt
      - gasclaw-<project-name>-state:/root/.gasclaw
      - gasclaw-<project-name>-claude:/root/.claude-kimigas
      - gasclaw-<project-name>-workspace:/workspace
    env_file:
      - .env
    restart: unless-stopped

volumes:
  gasclaw-<project-name>-openclaw:
  gasclaw-<project-name>-dolt:
  gasclaw-<project-name>-state:
  gasclaw-<project-name>-claude:
  gasclaw-<project-name>-workspace:
```

### 7. Configure OpenClaw

Write the openclaw.json inside the container:

```bash
docker exec gasclaw-<project-name> bash -c 'cat > /root/.openclaw/openclaw.json << EOCFG
{
  "agents": {
    "defaults": {
      "model": {"primary": "moonshot/kimi-k2.5"},
      "workspace": "/root/.openclaw/workspace",
      "contextPruning": {"mode": "cache-ttl", "ttl": "30m"},
      "compaction": {"mode": "safeguard"},
      "heartbeat": {"every": "30m"}
    },
    "list": [
      {"id": "main", "identity": {"name": "<Project> Overseer", "emoji": "🤖"}, "subagents": {"allowAgents": ["*"]}},
      {"id": "developer", "identity": {"name": "Developer", "emoji": "💻"}, "subagents": {"allowAgents": ["*"]}},
      {"id": "reviewer", "identity": {"name": "Reviewer", "emoji": "🔍"}, "subagents": {"allowAgents": ["*"]}}
    ]
  },
  "tools": {"exec": {"security": "full"}},
  "commands": {"native": "auto"},
  "env": {"MOONSHOT_API_KEY": "sk-YOUR-KEY"},
  "channels": {
    "telegram": {
      "groupPolicy": "open",
      "groupAllowFrom": ["2045995148", "8662958386"],
      "groups": {
        "-1003810709807": {
          "requireMention": true,
          "topics": {"<TOPIC_ID>": {"requireMention": false}}
        }
      }
    }
  },
  "gateway": {"port": <PORT>},
  "plugins": {"slots": {"memory": "none"}}
}
EOCFG'
```

### 8. Fix models.json for All Agents

```bash
MODELS_JSON='{
  "providers": {
    "moonshot": {
      "baseUrl": "https://api.minimax.villamarket.ai/v1",
      "api": "openai-completions",
      "models": [{"id": "kimi-k2.5", "name": "Kimi K2.5", "reasoning": false, "input": ["text","image"], "cost": {"input":0,"output":0,"cacheRead":0,"cacheWrite":0}, "contextWindow": 256000, "maxTokens": 8192}],
      "apiKey": "MOONSHOT_API_KEY"
    }
  }
}'

docker exec gasclaw-<project-name> bash -c "
  for d in /root/.openclaw/agents/*/agent/; do
    echo '$MODELS_JSON' > \$d/models.json
  done
"
```

### 9. Start the Gateway

```bash
docker exec gasclaw-<project-name> bash -c "
  rm -f /root/.openclaw/gateway.lock
  nohup openclaw gateway --port <PORT> > /tmp/openclaw-gw.log 2>&1 &
"
```

### 10. Activate Agents

```bash
export MOONSHOT_API_KEY="sk-YOUR-KEY"
for agent in main developer reviewer; do
  docker exec gasclaw-<project-name> bash -c \
    "export MOONSHOT_API_KEY=$MOONSHOT_API_KEY; openclaw agent --local --agent $agent --message 'Agent online.'"
done
```

### 11. Install gashub

```bash
docker exec gasclaw-<project-name> bash -c "
  git clone --depth 1 https://github.com/gastown-publish/context-hub.git /opt/gashub
  cd /opt/gashub/cli && npm install --production
  ln -sf /opt/gashub/cli/bin/gashub /usr/local/bin/gashub
  ln -sf /opt/gashub/cli/bin/gashub-mcp /usr/local/bin/gashub-mcp
  chmod +x /opt/gashub/cli/bin/gashub /opt/gashub/cli/bin/gashub-mcp
  gashub update
  gashub search openai  # verify
"
```

### 12. Update Management Scripts

In `/home/nic/gasclaw-workspace/gasclaw-management/`:

**`scripts/activate-agents.sh`** — add:
```bash
echo "=== gasclaw-<project-name> ==="
docker exec gasclaw-<project-name> bash -c "
export MOONSHOT_API_KEY=$MOONSHOT_API_KEY
for agent in main developer reviewer; do
  openclaw agent --local --agent \$agent --message 'Agent online.' 2>&1 | tail -1
done
"
```

**`scripts/restart-gateways.sh`** — add to CONTAINERS array:
```bash
CONTAINERS=("... existing ..." "gasclaw-<project-name>:<PORT>")
```

**`scripts/watchdog.sh`** — add:
```bash
check_restart_gateway gasclaw-<project-name> <PORT>
```

**`docs/infrastructure.md`** — add container section.

**`HANDOFF.md`** — add row to containers table.

### 13. Verify

```bash
# Container running
docker ps | grep gasclaw-<project-name>

# Gateway healthy
docker exec gasclaw-<project-name> tail -3 /tmp/openclaw-gw.log

# Agents responding
docker exec gasclaw-<project-name> bash -c \
  "export MOONSHOT_API_KEY=sk-KEY; openclaw agent --local --agent main --message 'status'"

# Bot responds in Telegram
# Send a message in the project's topic — bot should reply

# gashub works
docker exec gasclaw-<project-name> gashub search openai
```

### 14. Track with Beads

```bash
cd /home/nic/gasclaw-workspace/gasclaw-management
bd create "New project: <project-name>" -t feature -p P2 \
  -d "Container gasclaw-<project-name> on port <PORT>, bot @<bot>, topic <ID>"
```

---

## Quick Reference: Existing Projects

| Container | Port | Bot | Repo | Topic |
|-----------|------|-----|------|-------|
| gasclaw-dev | 18794 | @gasclaw_master_bot | gastown-publish/gasclaw | 918 🏭 |
| gasclaw-minimax | 18793 | @minimax_gastown_publish_bot | gastown-publish/minimax | 919 📦 |
| gasclaw-gasskill | 18796 | @gasskill_agent_bot | gastown-publish/gasskill | 920 🔧 |
| gasclaw-mgmt | 18798 | @gasclaw_mgmt_bot | gastown-publish/gasclaw-management | 921 📊 |
| gascontext | 18797 | TBD | gastown-publish/context-hub | TBD 📚 |

## Common Pitfalls

1. **models.json resets on gateway restart** — always verify `moonshot/kimi-k2.5` with `baseUrl: https://api.minimax.villamarket.ai/v1` after restart
2. **`groupAllowFrom` takes USER IDs only** — never put group chat IDs
3. **`commands.native: "auto"`** — don't change, breaks `/agents` command
4. **Sub-agent auth** — copy `models.json` from main agent dir to all sub-agents after creation
5. **Empty `src/gasclaw/` dir** — if using volume mount overlay, populate from `/home/nic/gasclaw-workspace/gasclaw/src/gasclaw/`
6. **Validate config after every change** — `docker exec <container> openclaw config validate`
