# Gasclaw Scripts

This directory contains automation scripts for the Gasclaw platform.

## Health & Monitoring

| Script | Description | Usage |
|--------|--------------|-------|
| `health-check.sh` | Check gateway, git, beads health | `./health-check.sh` |
| `host-health-check.sh` | Check vLLM, LiteLLM (run on host) | `./host-health-check.sh` |
| `resource-metrics.sh` | Collect CPU, disk, memory metrics | `./resource-metrics.sh` |
| `dashboard.sh` | Generate HTML dashboard | `./dashboard.sh > /tmp/d.html` |
| `ci-status.sh` | Check GitHub Actions status | `./ci-status.sh` |

## Alerting

| Script | Description | Usage |
|--------|--------------|-------|
| `alert-webhook.sh` | Send alerts to Slack/Telegram | `WEBHOOK_URL=... ./alert-webhook.sh "msg"` |
| `service-auto-restart.sh` | Auto-restart vLLM/LiteLLM | `./service-auto-restart.sh all` |

## Automation

| Script | Description | Usage |
|--------|--------------|-------|
| `log-rotate.sh` | Rotate logs to prevent disk full | Run daily via cron |
| `cron/health-check-cron.sh` | Health check every 5min | Add to crontab |

## Mayors

| Script | Description |
|--------|-------------|
| `mayor-hourly-check.sh` | Hourly platform check |
| `mayor-loop.sh` | Persistent mayor conversation |

## Utilities

| Script | Description |
|--------|-------------|
| `watchdog.sh` | Watchdog cron |
| `restart-gateways.sh` | Restart all gateways |
| `crosstalk-monitor.sh` | Monitor cross-topic replies |
| `forum_health.sh` | Check forum health |

## Cron Setup

```bash
# Health check every 5 minutes
*/5 * * * * /workspace/gt/scripts/cron/health-check-cron.sh >> /var/log/gasclaw-health.log 2>&1

# Log rotation daily at 2am
0 2 * * * /workspace/gt/scripts/log-rotate.sh >> /var/log/gasclaw-rotate.log 2>&1

# Resource metrics every minute
* * * * * /workspace/gt/scripts/resource-metrics.sh
```

## Environment Variables

Set these for alerting:
```bash
export WEBHOOK_URL="https://hooks.slack.com/services/..."  # or Telegram webhook
export ALERT_ON_FAIL=true
```