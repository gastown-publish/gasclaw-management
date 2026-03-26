#!/bin/bash
# Service auto-restart - attempts to restart failed services
# Usage: ./service-auto-restart.sh [vllm|litellm|all]
# Run as cron: */5 * * * * /workspace/gt/scripts/service-auto-restart.sh all

SERVICE="${1:-all}"
LOG_FILE="/var/log/gasclaw-service-restart.log"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1" | tee -a "$LOG_FILE"
}

restart_vllm() {
    log "Checking vLLM..."
    if ! curl -s -o /dev/null http://localhost:8080/v1/models; then
        log "vLLM not responding, attempting restart..."
        # This would need to match however vLLM is started on your host
        # Adjust the path to match your setup
        pkill -f "vllm" || true
        sleep 2
        cd /home/nic/data/models/MiniMax-M2.5 && nohup ./scripts/start.sh 8 >/dev/null 2>&1 &
        log "vLLM restart triggered"
    else
        log "vLLM OK"
    fi
}

restart_litellm() {
    log "Checking LiteLLM..."
    if ! curl -s -o /dev/null http://localhost:4000/health; then
        log "LiteLLM not responding, attempting restart..."
        pkill -f "litellm" || true
        sleep 2
        cd /home/nic/data/models/MiniMax-M2.5/.venv && \
            nohup litellm --config /home/nic/data/models/MiniMax-M2.5/litellm-config.yaml >/dev/null 2>&1 &
        log "LiteLLM restart triggered"
    else
        log "LiteLLM OK"
    fi
}

case "$SERVICE" in
    vllm)
        restart_vllm
        ;;
    litellm)
        restart_litellm
        ;;
    all)
        restart_vllm
        restart_litellm
        ;;
    *)
        echo "Usage: $0 [vllm|litellm|all]"
        exit 1
        ;;
esac

log "Service check complete"