#!/bin/bash
# Restart all OpenClaw gateways

CONTAINERS=("gasclaw-dev:18794" "gasclaw-minimax:18793" "gasclaw-gasskill:18796")

for entry in "${CONTAINERS[@]}"; do
  container="${entry%%:*}"
  port="${entry##*:}"
  echo "=== $container (port $port) ==="

  docker exec "$container" bash -c "
    for f in /proc/[0-9]*/cmdline; do
      cmd=\$(tr '\0' ' ' < \"\$f\" 2>/dev/null)
      if echo \"\$cmd\" | grep -q 'openclaw-gateway'; then
        pid=\$(echo \"\$f\" | cut -d/ -f3)
        kill -9 \$pid 2>/dev/null
      fi
    done
    rm -f /root/.openclaw/gateway.lock
    sleep 2
    nohup openclaw gateway --port $port > /tmp/openclaw-gw.log 2>&1 &
  " 2>/dev/null

  sleep 5
  docker exec "$container" curl -sf "http://localhost:$port/health" 2>/dev/null && echo " OK" || echo " FAIL"
done
