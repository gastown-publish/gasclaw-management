#!/bin/bash
# Health check cron - run every 5 minutes
# Installed via: crontab -e
# */5 * * * * /workspace/gt/scripts/cron/health-check-cron.sh

cd /workspace/gt

ALERT_LOG="${ALERT_LOG:-/tmp/gasclaw-alerts.log}"

# Run health check
./scripts/health-check.sh

# Check exit code
if [ $? -ne 0 ]; then
    # Alert on failure
    if [ -n "$WEBHOOK_URL" ]; then
        ./scripts/alert-webhook.sh "Health check failed" critical
    else
        # Fallback: log to local file
        timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        echo "[$timestamp] [critical] Health check failed" >> "$ALERT_LOG"
    fi
fi