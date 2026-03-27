# Long-Term Solution: Prevent Connection Duplication

## Problem Summary

We identified 42 duplicate LiteLLM processes and 114+ idle connections to the MiniMax vLLM instance. This caused:
- Rate limiting errors
- Memory pressure
- Degraded performance
- Connection leaks

## Root Causes

1. **No process supervision** - Manual restarts created duplicates
2. **No connection limits** - Agents kept persistent connections open
3. **No timeouts** - Idle connections never closed
4. **No health checks** - Failed services not auto-restarted

## Solution Components

### 1. Systemd Service Management

Prevents duplicate processes and auto-restarts on failure:

```bash
# Install services
sudo systemctl daemon-reload
sudo systemctl enable litellm-minimax vllm-minimax
sudo systemctl start litellm-minimax vllm-minimax

# Check status
sudo systemctl status litellm-minimax
sudo systemctl status vllm-minimax
```

**Benefits:**
- Only ONE LiteLLM process allowed (systemd prevents duplicates)
- Auto-restart on crash
- Automatic dependency management (PostgreSQL)
- Resource limits (file descriptors, processes)

### 2. LiteLLM Configuration with Limits

Updated `/home/nic/data/models/MiniMax-M2.5/litellm-config.yaml`:

```yaml
general_settings:
  max_parallel_requests: 80      # Limit concurrent requests
  max_requests_per_minute: 1000  # Rate limiting
  timeout: 300                   # Request timeout
  health_check_interval: 30      # Health checks
  
litellm_settings:
  request_timeout: 300
  stream_timeout: 600
  
router_settings:
  circuit_breaker:
    enabled: true
    threshold: 5                 # Stop routing to vLLM after 5 failures
    timeout: 60                  # Retry after 60s
```

**Benefits:**
- Prevents overloading vLLM
- Automatic failover
- Circuit breaker protects vLLM

### 3. Connection Monitoring Script

`scripts/monitor-connections.sh` - Run via cron every minute:

```bash
# Add to crontab
crontab -e
# Add this line:
* * * * * /home/nic/gasclaw-workspace/gasclaw-management/scripts/monitor-connections.sh
```

**Features:**
- Kills idle connections (>5 minutes)
- Removes duplicate LiteLLM processes
- Health checks both services
- Auto-restart via systemd
- Log rotation

### 4. Agent Configuration (Connection Pooling)

Configure OpenClaw agents to use connection pooling:

```bash
# In each container, set these environment variables:
export OPENCLAW_HTTP_KEEPALIVE=false      # Don't keep connections alive
export OPENCLAW_HTTP_TIMEOUT=120          # 2 minute timeout
export OPENCLAW_HTTP_POOL_SIZE=2          # Max 2 connections per agent
```

Add to container startup scripts or docker-compose:

```yaml
environment:
  - OPENCLAW_HTTP_KEEPALIVE=false
  - OPENCLAW_HTTP_TIMEOUT=120
  - OPENCLAW_HTTP_POOL_SIZE=2
```

## Installation Steps

### Step 1: Stop Current Processes

```bash
# Kill all existing processes
pkill -f "litellm --config"
pkill -f "vllm serve"
sleep 5

# Verify none running
ps aux | grep -E "litellm|vllm" | grep -v grep
```

### Step 2: Install Systemd Services

```bash
# Services are already created in /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable litellm-minimax vllm-minimax
sudo systemctl start litellm-minimax vllm-minimax
```

### Step 3: Setup Monitoring

```bash
# Add cron job
echo "* * * * * /home/nic/gasclaw-workspace/gasclaw-management/scripts/monitor-connections.sh" | crontab -

# Test the script
./scripts/monitor-connections.sh
cat /tmp/connection-monitor.log
```

### Step 4: Update Agent Containers

```bash
# Set environment variables in all containers
for container in gasclaw-dev gasclaw-minimax 7a45d446dc36_gasclaw-gasskill; do
    docker exec $container bash -c '
        echo "export OPENCLAW_HTTP_KEEPALIVE=false" >> ~/.bashrc
        echo "export OPENCLAW_HTTP_TIMEOUT=120" >> ~/.bashrc
    '
done
```

## Monitoring Dashboard

Add to your dashboard at `https://status.gpu.villamarket.ai/`:

```python
# Add this endpoint to dashboard/app.py
@app.route('/api/minimax/connections')
def get_minimax_connections():
    """Get connection stats for MiniMax"""
    litellm_conn = int(subprocess.getoutput("ss -tn | grep ':4000' | wc -l"))
    vllm_conn = int(subprocess.getoutput("ss -tn | grep ':8080' | wc -l"))
    litellm_procs = int(subprocess.getoutput("pgrep -c -f 'litellm --config'"))
    
    return jsonify({
        "litellm_connections": litellm_conn,
        "vllm_connections": vllm_conn,
        "litellm_processes": litellm_procs,
        "timestamp": datetime.now().isoformat()
    })
```

## Expected Behavior

After implementing this solution:

| Metric | Before | After |
|--------|--------|-------|
| LiteLLM processes | 42 | 1 |
| Idle connections | 114 | <20 |
| Connection age | Hours | Minutes |
| Auto-restart | Manual | Automatic |
| Health checks | None | Every 30s |

## Troubleshooting

### Check service status:
```bash
sudo systemctl status litellm-minimax
sudo journalctl -u litellm-minimax -n 50
```

### View monitoring logs:
```bash
tail -f /tmp/connection-monitor.log
```

### Manual restart:
```bash
sudo systemctl restart litellm-minimax vllm-minimax
```

### Check connections:
```bash
ss -tn | grep -E ':4000|:8080' | wc -l
```

## Maintenance

- **Weekly**: Check `/tmp/connection-monitor.log` for issues
- **Monthly**: Review systemd logs `journalctl -u litellm-minimax --since "1 month ago"`
- **Quarterly**: Update LiteLLM/vLLM versions

## Cost Savings

With proper connection management:
- Fewer GPU memory errors
- Reduced restart frequency
- Better agent response times
- No more duplicate process overhead
