#!/bin/bash
# Watchdog: auto-restart critical services if they die
# Run via cron: */5 * * * * /home/nic/gasclaw-workspace/gasclaw-management/scripts/watchdog.sh >> /tmp/watchdog.log 2>&1

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

check_restart_gateway() {
  local container=$1 port=$2
  # Check if container is running first
  if ! docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
    return
  fi
  local health=$(docker exec "$container" bash -c "curl -sf http://localhost:$port/health 2>/dev/null" 2>/dev/null)
  if [ -z "$health" ]; then
    echo "[$TIMESTAMP] $container gateway DOWN on port $port — restarting"
    docker exec "$container" bash -c "
      rm -f /root/.openclaw/gateway.lock
      nohup openclaw gateway run --port $port --allow-unconfigured >> /tmp/openclaw-gw.log 2>&1 &
    " 2>/dev/null
    sleep 5
    local check=$(docker exec "$container" bash -c "tail -1 /tmp/openclaw-gw.log 2>/dev/null" 2>/dev/null)
    echo "[$TIMESTAMP] $container gateway restart: $check"
  fi
}

check_vllm() {
  # vLLM returns 200 with empty body on /health
  local http_code=$(curl -s --max-time 10 -o /dev/null -w "%{http_code}" http://localhost:8080/health 2>/dev/null)
  if [ "$http_code" != "200" ]; then
    echo "[$TIMESTAMP] vLLM DOWN (HTTP $http_code on :8080) — restarting"
    cd /home/nic/data/models/MiniMax-M2.5 && ./scripts/start.sh 8 >> /tmp/vllm-restart.log 2>&1 &
  fi
}

check_litellm() {
  # LiteLLM returns 401 without auth key — that means it's UP
  local http_code=$(curl -s --max-time 10 -o /dev/null -w "%{http_code}" http://localhost:4000/health 2>/dev/null)
  if [ "$http_code" = "000" ] || [ -z "$http_code" ]; then
    echo "[$TIMESTAMP] LiteLLM DOWN (no response on :4000) — restarting"
    cd /home/nic/data/models/MiniMax-M2.5
    source .venv/bin/activate
    nohup litellm --config litellm-config.yaml --port 4000 >> /tmp/litellm-restart.log 2>&1 &
  fi
}

check_tailscale_funnel() {
  # Check if funnel is active via tailscale CLI
  local status=$(tailscale funnel status 2>/dev/null | grep -c "Funnel on")
  if [ "$status" -eq 0 ]; then
    echo "[$TIMESTAMP] Tailscale funnel DOWN — restarting"
    nohup tailscale funnel 4000 >> /tmp/funnel.log 2>&1 &
  fi
}

check_duplicate_gateways() {
  for container in gasclaw-dev gasclaw-minimax gasclaw-gasskill gasclaw-context gasclaw-mgmt; do
    if ! docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
      continue
    fi
    local count=$(docker exec "$container" bash -c "pgrep -f 'node.*openclaw' 2>/dev/null | wc -l" 2>/dev/null)
    if [ "$count" -gt 2 ]; then
      echo "[$TIMESTAMP] $container has $count gateway processes — killing duplicates"
      docker exec "$container" bash -c "
        for f in /proc/[0-9]*/exe; do
          target=\$(readlink \"\$f\" 2>/dev/null)
          if echo \"\$target\" | grep -q 'node'; then
            pid=\$(echo \"\$f\" | cut -d/ -f3)
            kill -9 \$pid 2>/dev/null
          fi
        done
      " 2>/dev/null
    fi
  done
}

# Check for duplicate gateway processes first
check_duplicate_gateways

# Check all gateways
check_restart_gateway gasclaw-dev 18794
check_restart_gateway gasclaw-minimax 18793
check_restart_gateway gasclaw-gasskill 18796
check_restart_gateway gasclaw-context 18797
check_restart_gateway gasclaw-mgmt 18798

# Check core services
check_vllm
check_litellm
check_tailscale_funnel
