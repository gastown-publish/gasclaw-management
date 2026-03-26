#!/bin/bash
# Platform health check
# Note: vLLM/LiteLLM run on HOST, not in this container
set -e

echo "=== Gasclaw Platform Health Check ==="
echo ""

# Gateway (in container)
echo -n "Gateway (18798): "
if curl -s -o /dev/null -w "%{http_code}" http://localhost:18798/health 2>/dev/null | grep -q "200"; then
    echo "✓ OK"
else
    echo "✗ FAILED"
fi

# Git repo
echo -n "Git repo: "
if [ -d "/workspace/gt/.git" ] && git -C /workspace/gt rev-parse --git-dir >/dev/null 2>&1; then
    echo "✓ OK"
else
    echo "✗ FAILED"
fi

# Beads
echo -n "Beads: "
if bd list >/dev/null 2>&1; then
    echo "✓ OK"
else
    echo "✗ FAILED"
fi

echo ""
echo "=== Host Services (run on GPU host) ==="
echo "vLLM (8080): Check manually on host"
echo "LiteLLM (4000): Check manually on host"
echo ""
echo "=== Done ==="
