#!/bin/bash
# Monitor and clean up stale connections to MiniMax/vLLM
# Run this via cron every minute: * * * * * /home/nic/gasclaw-workspace/gasclaw-management/scripts/monitor-connections.sh

LOG_FILE="/tmp/connection-monitor.log"
MAX_LITELLM_CONN=150
MAX_VLLM_CONN=10
ALERT_THRESHOLD=100

# Function to log with timestamp
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Count connections
LITELLM_CONN=$(ss -tn | grep ':4000' | wc -l)
VLLM_CONN=$(ss -tn | grep ':8080' | wc -l)

# Get connection ages (in seconds)
OLD_LITELLM_CONN=$(ss -tn -o state established '( dport = :4000 or sport = :4000 )' | awk '{print $6}' | grep -E '^[0-9]+' | awk '$1 > 300' | wc -l)

log "Status: LiteLLM=$LITELLM_CONN, vLLM=$VLLM_CONN, Old(>5min)=$OLD_LITELLM_CONN"

# Alert if too many connections
if [ "$LITELLM_CONN" -gt "$ALERT_THRESHOLD" ]; then
    log "WARNING: High connection count to LiteLLM: $LITELLM_CONN"
    
    # Kill connections idle for more than 5 minutes
    if [ "$OLD_LITELLM_CONN" -gt 0 ]; then
        log "Killing $OLD_LITELLM_CONN stale connections (>5min idle)"
        ss -tn -o state established '( dport = :4000 or sport = :4000 )' | \
            awk '$6 > 300 {print $4}' | \
            cut -d: -f2 | \
            xargs -r -I {} sh -c 'ss -K dst 127.0.0.1 dport = {}' 2>/dev/null
    fi
fi

# Check for duplicate LiteLLM processes
LITELLM_PROCS=$(pgrep -c -f "litellm --config")
if [ "$LITELLM_PROCS" -gt 1 ]; then
    log "WARNING: Found $LITELLM_PROCS LiteLLM processes! Killing duplicates..."
    
    # Keep the oldest process (lowest PID), kill others
    MAIN_PID=$(pgrep -o -f "litellm --config")
    pgrep -f "litellm --config" | grep -v "^$MAIN_PID$" | xargs -r kill -9
    
    log "Kept PID $MAIN_PID, killed others"
fi

# Check for duplicate vLLM processes  
VLLM_PROCS=$(pgrep -c -f "vllm serve")
if [ "$VLLM_PROCS" -gt 8 ]; then  # 1 parent + 1 coordinator + 2 engine cores + 4 workers = 8 expected
    log "WARNING: Found $VLLM_PROCS vLLM processes!"
    # Don't auto-kill vLLM as it's harder to restart safely
fi

# Check LiteLLM health (use /health with auth or check if process is responding)
HEALTH_STATUS=$(curl -s --max-time 5 -H "Authorization: Bearer sk-1564f41cd82a7303e6e3eb15cedc15eb76d1a3f556d8b890" \
    -o /dev/null -w "%{http_code}" http://localhost:4000/health 2>/dev/null || echo "000")
if [ "$HEALTH_STATUS" != "200" ]; then
    log "ERROR: LiteLLM health check failed (HTTP $HEALTH_STATUS)"
    
    # Check if process is still running
    LITELLM_PID=$(pgrep -o -f "litellm --config" 2>/dev/null)
    if [ -z "$LITELLM_PID" ]; then
        log "LiteLLM process not found!"
        # Try to restart via systemd if available
        if systemctl is-active --quiet litellm-minimax 2>/dev/null; then
            log "Restarting litellm-minimax via systemd..."
            sudo systemctl restart litellm-minimax
        fi
    else
        log "LiteLLM process running (PID: $LITELLM_PID) but health check failed"
    fi
fi

# Check vLLM health
VLLM_HEALTH=$(curl -s --max-time 5 -o /dev/null -w "%{http_code}" http://localhost:8080/health 2>/dev/null || echo "000")
if [ "$VLLM_HEALTH" != "200" ]; then
    log "ERROR: vLLM health check failed (HTTP $VLLM_HEALTH)"
    
    if systemctl is-active --quiet vllm-minimax 2>/dev/null; then
        log "Restarting vllm-minimax via systemd..."
        sudo systemctl restart vllm-minimax
    fi
fi

# Rotate log if too large (>10MB)
if [ -f "$LOG_FILE" ] && [ $(stat -f%z "$LOG_FILE" 2>/dev/null || stat -c%s "$LOG_FILE" 2>/dev/null || echo 0) -gt 10485760 ]; then
    mv "$LOG_FILE" "${LOG_FILE}.old"
    touch "$LOG_FILE"
fi
