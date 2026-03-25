#!/bin/bash
# Activate all OpenClaw agent sessions after restart

export MOONSHOT_API_KEY="${MOONSHOT_API_KEY:-sk-9vMJQmXKcQHjP4pFviqsxA}"

echo "=== gasclaw-dev ==="
docker exec gasclaw-dev bash -c "
export MOONSHOT_API_KEY=$MOONSHOT_API_KEY
for agent in main crew-1 crew-2; do
  echo \"Activating \$agent...\"
  openclaw agent --local --agent \$agent --message 'Agent online.' 2>&1 | tail -1
done
" 2>&1

echo "=== gasclaw-minimax ==="
docker exec gasclaw-minimax bash -c "
export MOONSHOT_API_KEY=$MOONSHOT_API_KEY
for agent in main coordinator developer devops tester reviewer; do
  echo \"Activating \$agent...\"
  openclaw agent --local --agent \$agent --message 'Agent online.' 2>&1 | tail -1
done
" 2>&1

echo "=== gasclaw-gasskill ==="
docker exec gasclaw-gasskill bash -c "
export MOONSHOT_API_KEY=$MOONSHOT_API_KEY
for agent in main skill-dev skill-tester; do
  echo \"Activating \$agent...\"
  openclaw agent --local --agent \$agent --message 'Agent online.' 2>&1 | tail -1
done
" 2>&1

echo "=== gasclaw-context ==="
docker exec gasclaw-context bash -c "
export MOONSHOT_API_KEY=$MOONSHOT_API_KEY
for agent in main content-curator mcp-tester; do
  echo \"Activating \$agent...\"
  openclaw agent --local --agent \$agent --message 'Agent online.' 2>&1 | tail -1
done
" 2>&1
