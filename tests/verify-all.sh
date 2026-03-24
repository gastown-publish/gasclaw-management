#!/bin/bash
# verify-all.sh — Full stack verification
set -euo pipefail

echo "========================================="
echo "  FULL STACK VERIFICATION"
echo "========================================="

echo "=== 1. vLLM ==="
curl -sf http://localhost:8080/health && echo " OK" || echo " FAIL"

echo "=== 2. LiteLLM ==="
curl -sf -H "Authorization: Bearer $(grep master_key /home/nic/data/models/MiniMax-M2.5/litellm-config.yaml | awk '{print $2}')" \
  http://localhost:4000/v1/models | python3 -c "import sys,json; print(f'{len(json.load(sys.stdin)[\"data\"])} models')" 2>/dev/null || echo "FAIL"

echo "=== 3. Containers ==="
docker ps --format "table {{.Names}}\t{{.Status}}" | grep gasclaw

echo "=== 4. Gateways ==="
for c in gasclaw-dev gasclaw-minimax gasclaw-gasskill; do
  port=$(docker exec $c python3 -c "import json; print(json.loads(open('/root/.openclaw/openclaw.json').read())['gateway']['port'])" 2>/dev/null)
  echo -n "$c ($port): " && docker exec $c curl -sf http://localhost:$port/health 2>/dev/null && echo "" || echo "DOWN"
done

echo "=== 5. Mayors ==="
for c in gasclaw-dev gasclaw-minimax gasclaw-gasskill; do
  echo -n "$c: " && docker exec $c bash -c "cd /workspace/gt && gt mayor status 2>&1 | grep -o 'running\|not running'" 2>/dev/null || echo "unknown"
done

echo "=== 6. Telegram Bots ==="
for c in gasclaw-dev gasclaw-minimax gasclaw-gasskill; do
  echo -n "$c: " && docker exec $c bash -c 'cat /tmp/openclaw/openclaw-*.log 2>/dev/null | grep "Telegram: ok" | tail -1' 2>/dev/null | python3 -c "import sys,json; print(json.loads(sys.stdin.read().strip()).get('0','no log'))" 2>/dev/null || echo "no log"
done

echo "=== 7. CI Status ==="
for repo in gasclaw minimax; do
  echo -n "$repo: " && gh run list --repo gastown-publish/$repo --limit 1 --json conclusion --jq '.[0].conclusion' 2>/dev/null || echo "unknown"
done

echo "=== 8. Open Issues ==="
for repo in gasclaw minimax gasskill; do
  count=$(gh issue list --repo gastown-publish/$repo --state open 2>/dev/null | wc -l)
  echo "$repo: $count open"
done

echo ""
echo "========================================="
echo "  VERIFICATION COMPLETE"
echo "========================================="
