#!/bin/bash
# Alert webhook - sends health notifications to Slack/Telegram
# Usage: ./alert-webhook.sh "message" [critical|warning|info]

set -e

MESSAGE="${1:-Health check alert}"
SEVERITY="${2:-warning}"
WEBHOOK_URL="${WEBHOOK_URL:-}"

if [ -z "$WEBHOOK_URL" ]; then
    echo "ERROR: WEBHOOK_URL not set"
    exit 1
fi

# Format payload based on severity
case "$SEVERITY" in
    critical)
        EMOJI="🔴"
        ;;
    warning)
        EMOJI="🟡"
        ;;
    *)
        EMOJI="ℹ️"
        ;;
esac

PAYLOAD="{\"text\":\"$EMOJI $MESSAGE\"}"

# Send webhook
response=$(curl -s -X POST \
    -H "Content-Type: application/json" \
    -d "$PAYLOAD" \
    "$WEBHOOK_URL" 2>&1)

if [ $? -eq 0 ]; then
    echo "✓ Alert sent: $MESSAGE"
else
    echo "✗ Failed to send alert: $response"
    exit 1
fi