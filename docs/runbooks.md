# Runbooks - Common Failure Scenarios

Quick fixes for the most common Gasclaw platform issues.

## 1. Gateway Not Responding

**Symptoms:** `curl localhost:18798/health` returns connection refused

**Fix:**
```bash
# Restart gateway
openclaw gateway restart

# Or manually
cd /root/.openclaw && node_modules/.bin/openclaw gateway start
```

**Prevention:** Watchdog cron every 5min (`scripts/watchdog.sh`)

---

## 2. vLLM/LiteLLM Not Responding

**Symptoms:** Model calls fail with connection timeout

**Fix:**
```bash
# Check if services are running (on host)
ps aux | grep vllm
ps aux | grep litellm

# Restart vLLM
cd /home/nic/data/models/MiniMax-M2.5 && ./scripts/stop.sh && ./scripts/start.sh 8

# Restart LiteLLM
pkill -f litellm
cd /home/nic/data/models/MiniMax-M2.5/.venv && litellm --config /home/nic/data/models/MiniMax-M2.5/litellm-config.yaml
```

**Prevention:** Run `scripts/service-auto-restart.sh` as cron every 5min

---

## 3. Beads/Dolt Issues

**Symptoms:** `bd list` fails, "database not found" error

**Fix:**
```bash
cd /workspace/gt

# If locked/stuck
rm -f .beads/dolt-server.lock
bd init --force
```

**Prevention:** Use JSONL-only mode: `bd config set use-no-db true`

---

## 4. Telegram Bot Not Responding

**Symptoms:** Messages to bot get no response

**Fix:**
```bash
# Check bot token
grep botToken /root/.openclaw/openclaw.json

# Restart container
lxc restart <container-name>
```

**Prevention:** Ensure `groupAllowFrom` includes user IDs

---

## 5. Agent Spawning Fails

**Symptoms:** `sessions_spawn` returns error

**Fix:**
```bash
# Check agent config
openclaw status

# Verify model keys
grep API_KEY /root/.openclaw/openclaw.json
```

**Prevention:** Monitor agent health with `scripts/health-check.sh`

---

## Quick Diagnostic Commands

```bash
# Full health check
./scripts/health-check.sh

# Host services check (run on host)
./scripts/host-health-check.sh

# Check all services
./scripts/service-auto-restart.sh all
```