#!/bin/bash
# Platform health check - with alerting
# Sends webhook alert if any check fails
set -e

ALERT_ON_FAIL="${ALERT_ON_FAIL:-true}"
WEBHOOK_URL="${WEBHOOK_URL:-}"

FAILED=0

log_fail() {
    echo "✗ FAILED"
    FAILED=1
}

echo "=== Gasclaw Platform Health Check ==="
echo ""

# Gateway (in container)
echo -n "Gateway (18798): "
if curl -s --max-time 5 -o /dev/null -w "%{http_code}" http://localhost:18798/health 2>/dev/null | grep -q "200"; then
    echo "✓ OK"
else
    log_fail
    [ -n "$WEBHOOK_URL" ] && [ "$ALERT_ON_FAIL" = "true" ] && \
        WEBHOOK_URL="$WEBHOOK_URL" ./scripts/alert-webhook.sh "Gateway (18798) unhealthy" critical &
fi

# Git repo
echo -n "Git repo: "
if [ -d "/workspace/gt/.git" ] && git -C /workspace/gt rev-parse --git-dir >/dev/null 2>&1; then
    echo "✓ OK"
else
    log_fail
    [ -n "$WEBHOOK_URL" ] && [ "$ALERT_ON_FAIL" = "true" ] && \
        WEBHOOK_URL="$WEBHOOK_URL" ./scripts/alert-webhook.sh "Git repo inaccessible" warning &
fi

# Memory plugin
echo -n "Memory plugin: "
if openclaw plugins doctor 2>&1 | grep -q "No plugin issues"; then
    echo "✓ OK"
else
    log_fail
    [ -n "$WEBHOOK_URL" ] && [ "$ALERT_ON_FAIL" = "true" ] && \
        WEBHOOK_URL="$WEBHOOK_URL" ./scripts/alert-webhook.sh "Memory plugin unhealthy" warning &
fi

# Beads
echo -n "Beads: "
if timeout 5 bd list >/dev/null 2>&1; then
    echo "✓ OK"
else
    log_fail
    [ -n "$WEBHOOK_URL" ] && [ "$ALERT_ON_FAIL" = "true" ] && \
        WEBHOOK_URL="$WEBHOOK_URL" ./scripts/alert-webhook.sh "Beads unhealthy" warning &
fi

echo ""
echo "=== Host Services (run on GPU host) ==="
echo "vLLM (8080): Check with host-health-check.sh"
echo "LiteLLM (4000): Check with host-health-check.sh"
echo ""
echo "=== Done ==="

if [ $FAILED -eq 1 ]; then
    echo "⚠️ Some checks failed"
    exit 1
fi

echo "✓ All checks passed"
exit 0