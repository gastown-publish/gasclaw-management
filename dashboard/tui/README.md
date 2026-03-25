# Gasclaw TUI - AI-Optimized Terminal Interface

A terminal user interface for managing Gasclaw infrastructure, designed for both human operators and AI agents.

## Installation

```bash
# Install dependencies
pip install -r requirements.txt

# Or install as package
pip install -e .
```

## Quick Start

```bash
# Show system status
gasclaw status

# JSON output for AI parsing
gasclaw status --json

# Watch containers in real-time
gasclaw containers --watch

# Interactive TUI mode
gasclaw tui
```

## Commands

### Core Commands

| Command | Description | AI Optimized |
|---------|-------------|--------------|
| `status` | Overall system status | ✅ JSON/YAML |
| `containers` | Docker container status | ✅ JSON/YAML |
| `agents` | Agent status across containers | ✅ JSON/YAML |
| `issues` | Beads issues tracking | ✅ JSON/YAML |
| `gateways` | OpenClaw gateway health | ✅ JSON/YAML |
| `metrics` | GPU metrics | ✅ JSON/YAML |
| `tui` | Interactive terminal UI | Human focused |

### Global Options

```bash
--api-url URL    # Dashboard API URL (default: https://status.gpu.villamarket.ai)
--json           # Output JSON for AI parsing
--yaml           # Output YAML for AI parsing
```

## AI Agent Usage

### Structured Output

All commands support `--json` for machine-readable output:

```bash
# Get system status as JSON
gasclaw status --json

# Example output:
{
  "health": {"status": "healthy"},
  "containers": [
    {"name": "gasclaw-dev", "status": "running", "uptime": "3 days"}
  ],
  "agents": {"active": 8, "total": 12, "agents": [...]},
  "gateways": [...],
  "issues": [...]
}
```

### Exit Codes

| Code | Meaning | Use Case |
|------|---------|----------|
| 0 | Success | All healthy |
| 1 | Warning | Some components degraded |
| 2 | Error | Critical failure |

```bash
# Check status and react based on exit code
gasclaw status --json > /tmp/status.json
if [ $? -eq 2 ]; then
    echo "Critical error detected"
    # Trigger alert
fi
```

### Watch Mode

Monitor components in real-time:

```bash
# Watch agents (updates every 5 seconds)
gasclaw agents --watch

# Custom interval
gasclaw agents --watch --interval 2
```

### Filtering

```bash
# Show only open issues
gasclaw issues --filter=open

# Show only critical issues
gasclaw issues --priority=0

# Show all issues
gasclaw issues --filter=all
```

## Human Usage

### Rich Terminal Output

Without `--json` or `--yaml`, commands produce beautiful terminal output:

```bash
$ gasclaw status

┌──────────────────────────────────────────────────────────┐
│                 [bold cyan]Gasclaw Status[/bold cyan]                   │
├──────────────────────────────────────────────────────────┤
│  Component      │ Status    │ Details                   │
├──────────────────────────────────────────────────────────┤
│  Containers     │ 3/3       │ ✓ All operational         │
│  Gateways       │ 3/3       │ ✓ All healthy             │
│  Agents         │ 8/12      │ ⚠ Some inactive           │
│  Issues         │ 15 total  │ 0 critical, 2 high        │
└──────────────────────────────────────────────────────────┘
```

### Interactive TUI

```bash
gasclaw tui
```

Provides a live-updating dashboard in the terminal with:
- Real-time container status
- Agent activity
- Issue tracking
- GPU metrics
- MiniMax service health

Press `Ctrl+C` to exit.

## Automation Examples

### Health Check Script

```bash
#!/bin/bash
# health-check.sh - Automated health monitoring

OUTPUT=$(gasclaw status --json 2>/dev/null)
EXIT_CODE=$?

if [ $EXIT_CODE -eq 2 ]; then
    echo "CRITICAL: Gasclaw system error"
    echo "$OUTPUT" | jq '.error'
    exit 1
elif [ $EXIT_CODE -eq 1 ]; then
    echo "WARNING: Some components degraded"
    # Extract issues
    echo "$OUTPUT" | jq '.containers[] | select(.status != "running")'
fi

echo "System healthy"
```

### Container Restart on Failure

```bash
#!/bin/bash
# auto-restart.sh - Restart failed containers

for container in $(gasclaw containers --json | jq -r '.[] | select(.status != "running") | .name'); do
    echo "Restarting $container..."
    docker restart $container
done
```

### Issue Reporting

```bash
#!/bin/bash
# issue-report.sh - Generate daily issue report

echo "=== Open Critical Issues ==="
gasclaw issues --filter=open --priority=0 --json | jq -r '.[] | "\(.id): \(.title)"'

echo ""
echo "=== Open High Priority Issues ==="
gasclaw issues --filter=open --priority=1 --json | jq -r '.[] | "\(.id): \(.title)"'
```

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `GASCLAW_API_URL` | Dashboard API URL | https://status.gpu.villamarket.ai |

## API Endpoints

The TUI connects to these dashboard API endpoints:

- `GET /api/health` - Health check
- `GET /api/overview` - Complete system status
- `GET /api/containers` - Docker containers
- `GET /api/agents` - Agent status
- `GET /api/gateways` - Gateway health
- `GET /api/issues` - Beads issues
- `GET /api/metrics` - GPU metrics

## Development

```bash
# Run directly
python gasclaw.py status --json

# Install in development mode
pip install -e .

# Run tests
gasclaw status --json | jq '.'
```
