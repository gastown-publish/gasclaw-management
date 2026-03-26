#!/bin/bash
# Host-side health check - run on GPU host
# Checks vLLM, LiteLLM, PostgreSQL
set -e

echo "=== Host Health Check ==="

# vLLM
echo -n "vLLM (8080): "
if curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/v1/models 2>/dev/null | grep -q "200"; then
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

# PostgreSQL
echo -n "PostgreSQL (5432): "
if pg_isready -h localhost -p 5432 -U litellm >/dev/null 2>&1; then
    echo "✓ OK"
else
    echo "✗ FAILED"
fi

echo "=== Done ==="