#!/bin/bash
# Quick system info summary
echo "=== System Info ==="
echo "Host: $(hostname)"
echo "Uptime: $(cat /proc/uptime | awk '{printf "%.1f days", $1/86400}')"
echo "Load: $(cat /proc/loadavg | awk '{print $1}')"
echo "Cores: $(nproc)"
MEM_TOTAL=$(grep MemTotal /proc/meminfo | awk '{printf "%.0f", $2/1024/1024}')
MEM_AVAIL=$(grep MemAvailable /proc/meminfo | awk '{printf "%.0f", $2/1024/1024}')
echo "Memory: $((MEM_TOTAL - MEM_AVAIL))GB / ${MEM_TOTAL}GB"
SWAP_TOTAL=$(grep SwapTotal /proc/meminfo | awk '{printf "%.0f", $2/1024}')
SWAP_FREE=$(grep SwapFree /proc/meminfo | awk '{printf "%.0f", $2/1024}')
echo "Swap: $((SWAP_TOTAL - SWAP_FREE))GB / ${SWAP_TOTAL}GB"
echo "Disk: $(df -h / | tail -1 | awk '{print $3 "/" $2 " (" $5 " used)"}')"
echo "IP: $(hostname -I 2>/dev/null || echo 'N/A')"
echo "TZ: $(cat /etc/timezone 2>/dev/null || date +%Z)"