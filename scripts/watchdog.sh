#!/bin/bash
# Watchdog: auto-restart critical services if they die
# Run via cron: */5 * * * * /home/nic/gasclaw-workspace/gasclaw-management/scripts/watchdog.sh >> /tmp/watchdog.log 2>&1

LOG="/tmp/watchdog.log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

check_restart_gateway() {
  local container=$1 port=$2
  local health=$(docker exec "$container" bash -c "curl -sf http://localhost:$port/health 2>/dev/null" 2>/dev/null)
  if [ -z "$health" ]; then
    echo "[$TIMESTAMP] $container gateway DOWN on port $port — restarting"
    docker exec "$container" bash -c "
      rm -f /root/.openclaw/gateway.lock
      nohup openclaw gateway --port $port > /tmp/openclaw-gw.log 2>&1 &
    " 2>/dev/null
    sleep 5
    local check=$(docker exec "$container" bash -c "tail -1 /tmp/openclaw-gw.log 2>/dev/null" 2>/dev/null)
    echo "[$TIMESTAMP] $container gateway restart: $check"
  fi
}

check_vllm() {
  local health=$(curl -sf http://localhost:8080/health 2>/dev/null)
  if [ -z "$health" ]; then
    echo "[$TIMESTAMP] vLLM DOWN — restarting"
    cd /home/nic/data/models/MiniMax-M2.5 && ./scripts/start.sh 8 >> /tmp/vllm-restart.log 2>&1 &
  fi
}

check_litellm() {
  local health=$(curl -sf http://localhost:4000/health 2>/dev/null)
  if [ -z "$health" ]; then
    echo "[$TIMESTAMP] LiteLLM DOWN — restarting"
    cd /home/nic/data/models/MiniMax-M2.5
    source .venv/bin/activate
    nohup litellm --config litellm-config.yaml --port 4000 >> /tmp/litellm-restart.log 2>&1 &
  fi
}

check_tailscale_funnel() {
  local funnel=$(pgrep -f "tailscale funnel" 2>/dev/null)
  if [ -z "$funnel" ]; then
    echo "[$TIMESTAMP] Tailscale funnel DOWN — restarting"
    nohup tailscale funnel 4000 >> /tmp/funnel.log 2>&1 &
  fi
}

# Check all gateways
check_restart_gateway gasclaw-dev 18794
check_restart_gateway gasclaw-minimax 18793
check_restart_gateway gasclaw-gasskill 18796
check_restart_gateway gascontext 18797
check_restart_gateway gasclaw-mgmt 18798

# Check core services
check_vllm
check_litellm
check_tailscale_funnel
