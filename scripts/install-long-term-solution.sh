#!/bin/bash
# Install long-term solution for MiniMax connection management
# Run as root or with sudo

set -e

echo "╔══════════════════════════════════════════════════════════════════════════════╗"
echo "║      Installing Long-Term Solution for MiniMax Connection Management         ║"
echo "╚══════════════════════════════════════════════════════════════════════════════╝"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    log_error "Please run as root or with sudo"
    exit 1
fi

# Get the actual user (not root)
ACTUAL_USER=${SUDO_USER:-$USER}
ACTUAL_HOME=$(eval echo ~$ACTUAL_USER)

echo "Installing for user: $ACTUAL_USER"
echo "Home directory: $ACTUAL_HOME"
echo ""

# Step 1: Kill existing duplicate processes
echo "Step 1/6: Cleaning up existing processes..."
log_info "Killing duplicate LiteLLM processes..."
pkill -f "litellm --config" 2>/dev/null || true
sleep 2

# Check if any LiteLLM still running
LITELLM_COUNT=$(pgrep -c -f "litellm --config" 2>/dev/null || echo 0)
if [ "$LITELLM_COUNT" -gt 0 ]; then
    log_warn "Some LiteLLM processes still running, forcing kill..."
    pkill -9 -f "litellm --config" 2>/dev/null || true
fi

log_info "Killing duplicate vLLM processes..."
pkill -f "vllm serve" 2>/dev/null || true
sleep 5

# Verify cleanup
LITELLM_COUNT=$(pgrep -c -f "litellm --config" 2>/dev/null || echo 0)
VLLM_COUNT=$(pgrep -c -f "vllm serve" 2>/dev/null || echo 0)
log_info "Remaining processes - LiteLLM: $LITELLM_COUNT, vLLM: $VLLM_COUNT"
echo ""

# Step 2: Create systemd service files
echo "Step 2/6: Creating systemd services..."

cat > /etc/systemd/system/litellm-minimax.service << 'EOF'
[Unit]
Description=LiteLLM Proxy for MiniMax-M2.5
After=network.target postgresql.service
Wants=postgresql.service

[Service]
Type=simple
User=nic
WorkingDirectory=/home/nic/data/models/MiniMax-M2.5
Environment="PATH=/home/nic/data/models/MiniMax-M2.5/.venv/bin"
Environment="PYTHONUNBUFFERED=1"
Environment="OPENCLAW_HTTP_KEEPALIVE=false"
ExecStart=/home/nic/data/models/MiniMax-M2.5/.venv/bin/litellm \
    --config /home/nic/data/models/MiniMax-M2.5/litellm-config.yaml \
    --host 0.0.0.0 \
    --port 4000
ExecStop=/bin/kill -TERM $MAINPID
Restart=always
RestartSec=10
StartLimitInterval=60s
StartLimitBurst=3
LimitNOFILE=65536
LimitNPROC=4096

[Install]
WantedBy=multi-user.target
EOF

cat > /etc/systemd/system/vllm-minimax.service << 'EOF'
[Unit]
Description=vLLM Server for MiniMax-M2.5
After=network.target

[Service]
Type=simple
User=nic
WorkingDirectory=/home/nic/data/models/MiniMax-M2.5
Environment="PATH=/home/nic/data/models/MiniMax-M2.5/.venv/bin"
Environment="CUDA_VISIBLE_DEVICES=0,1,2,3,4,5,6,7"
Environment="PYTHONUNBUFFERED=1"
ExecStart=/home/nic/data/models/MiniMax-M2.5/.venv/bin/vllm serve \
    /home/nic/data/models/MiniMax-M2.5-NVFP4 \
    --host 0.0.0.0 \
    --port 8080 \
    --tensor-parallel-size 4 \
    --enable-expert-parallel \
    --trust-remote-code \
    --gpu-memory-utilization 0.90 \
    --max-num-seqs 64 \
    --max-model-len 131072 \
    --enable-prefix-caching \
    --enable-chunked-prefill \
    --enable-auto-tool-choice \
    --tool-call-parser minimax_m2 \
    --reasoning-parser minimax_m2_append_think \
    --served-model-name minimax-m2.5 MiniMaxAI/MiniMax-M2.5 \
    --compilation-config '{"cudagraph_mode": "PIECEWISE"}' \
    --quantization modelopt_fp4 \
    --attention-backend FLASH_ATTN \
    --data-parallel-size 2 \
    --swap-space 16
ExecStop=/bin/kill -TERM $MAINPID
Restart=always
RestartSec=30
StartLimitInterval=120s
StartLimitBurst=3
LimitNOFILE=65536
LimitNPROC=4096

[Install]
WantedBy=multi-user.target
EOF

log_info "Systemd services created"
echo ""

# Step 3: Update LiteLLM config with limits
echo "Step 3/6: Updating LiteLLM configuration..."

# Backup existing config
if [ -f "/home/nic/data/models/MiniMax-M2.5/litellm-config.yaml" ]; then
    cp /home/nic/data/models/MiniMax-M2.5/litellm-config.yaml \
       /home/nic/data/models/MiniMax-M2.5/litellm-config.yaml.bak.$(date +%Y%m%d)
    log_info "Backup created"
fi

# Config is already updated in the repo, just need to copy
cp /home/nic/gasclaw-workspace/gasclaw-management/../MiniMax-M2.5/litellm-config.yaml \
   /home/nic/data/models/MiniMax-M2.5/litellm-config.yaml 2>/dev/null || \
   log_warn "Could not copy config from repo, existing config kept"

chown $ACTUAL_USER:$ACTUAL_USER /home/nic/data/models/MiniMax-M2.5/litellm-config.yaml 2>/dev/null || true
echo ""

# Step 4: Setup monitoring script
echo "Step 4/6: Setting up monitoring..."

MONITOR_SCRIPT="/home/nic/gasclaw-workspace/gasclaw-management/scripts/monitor-connections.sh"

if [ -f "$MONITOR_SCRIPT" ]; then
    chmod +x "$MONITOR_SCRIPT"
    log_info "Monitoring script ready"
else
    log_error "Monitoring script not found at $MONITOR_SCRIPT"
    exit 1
fi

# Add cron job
CRON_JOB="* * * * * /home/nic/gasclaw-workspace/gasclaw-management/scripts/monitor-connections.sh"

# Check if already in crontab
if ! (crontab -u $ACTUAL_USER -l 2>/dev/null | grep -q "monitor-connections.sh"); then
    (crontab -u $ACTUAL_USER -l 2>/dev/null; echo "$CRON_JOB") | crontab -u $ACTUAL_USER -
    log_info "Cron job added for monitoring"
else
    log_info "Cron job already exists"
fi

echo ""

# Step 5: Reload systemd and start services
echo "Step 5/6: Starting services..."

systemctl daemon-reload

# Enable services
systemctl enable litellm-minimax.service
systemctl enable vllm-minimax.service

# Start vLLM first (LiteLLM depends on it)
log_info "Starting vLLM..."
systemctl start vllm-minimax.service

# Wait for vLLM to be ready
log_info "Waiting for vLLM to be ready (60s)..."
sleep 60

# Check vLLM health
for i in {1..10}; do
    if curl -s --max-time 5 http://localhost:8080/health > /dev/null 2>&1; then
        log_info "vLLM is healthy"
        break
    fi
    log_warn "vLLM not ready yet, waiting... ($i/10)"
    sleep 10
done

# Start LiteLLM
log_info "Starting LiteLLM..."
systemctl start litellm-minimax.service

# Wait for LiteLLM
log_info "Waiting for LiteLLM to be ready (30s)..."
sleep 30

echo ""

# Step 6: Verify installation
echo "Step 6/6: Verifying installation..."

# Check services
LITELLM_STATUS=$(systemctl is-active litellm-minimax)
VLLM_STATUS=$(systemctl is-active vllm-minimax)

log_info "LiteLLM status: $LITELLM_STATUS"
log_info "vLLM status: $VLLM_STATUS"

# Check processes
LITELLM_PROCS=$(pgrep -c -f "litellm --config" 2>/dev/null || echo 0)
log_info "LiteLLM processes: $LITELLM_PROCS (should be 1)"

# Check connections
sleep 5
LITELLM_CONN=$(ss -tn | grep ':4000' | wc -l)
VLLM_CONN=$(ss -tn | grep ':8080' | wc -l)
log_info "LiteLLM connections: $LITELLM_CONN"
log_info "vLLM connections: $VLLM_CONN"

echo ""
echo "╔══════════════════════════════════════════════════════════════════════════════╗"

if [ "$LITELLM_STATUS" = "active" ] && [ "$VLLM_STATUS" = "active" ] && [ "$LITELLM_PROCS" -eq 1 ]; then
    echo -e "║                  ${GREEN}INSTALLATION SUCCESSFUL!${NC}                                 ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo ""
    log_info "Services are running and configured correctly"
    echo ""
    echo "Useful commands:"
    echo "  sudo systemctl status litellm-minimax  - Check LiteLLM status"
    echo "  sudo systemctl status vllm-minimax     - Check vLLM status"
    echo "  sudo journalctl -u litellm-minimax -f  - View LiteLLM logs"
    echo "  tail -f /tmp/connection-monitor.log    - View monitoring logs"
    echo ""
    echo "Documentation: docs/LONG_TERM_SOLUTION.md"
    exit 0
else
    echo -e "║                  ${RED}INSTALLATION ISSUES DETECTED${NC}                            ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo ""
    log_error "Some services are not running correctly"
    echo ""
    echo "Troubleshooting:"
    echo "  sudo journalctl -u litellm-minimax -n 50"
    echo "  sudo journalctl -u vllm-minimax -n 50"
    echo "  cat /tmp/connection-monitor.log"
    exit 1
fi
