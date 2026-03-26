#!/bin/bash
# Platform health check - run this to verify all services
set -e

echo "=== Gasclaw Platform Health Check ==="
echo ""

# Gateway
echo -n "Gateway (18798): "
if curl -s -o /dev/null -w "%{http_code}" http://localhost:18798/health | grep -q "200"; then
    echo "✓ OK"
else
    echo "✗ FAILED"
fi

# vLLM
echo -n "vLLM (8000): "
if curl -s -o /dev/null -w "%{http_code}" http://localhost:8000/v1/models 2>/dev/null | grep -q "200"; then
    echo "✓ OK"
else
    echo "✗ FAILED"
fi

# LiteLLM
echo -n "LiteLLM (4000): "
if curl -s -o /dev/null -w "%{http_code}" http://localhost:4000/health 2>/dev/null | grep -q "200"; then
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
echo "=== Done ==="
