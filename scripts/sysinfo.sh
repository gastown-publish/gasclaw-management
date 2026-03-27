#!/bin/bash
# Quick system info summary
echo "=== System Info ==="
echo "Host: $(hostname)"
echo "Uptime: $(cat /proc/uptime | awk '{printf "%.1f days", $1/86400}')"
echo "Load: $(cat /proc/loadavg | awk '{print $1}')"
echo "Cores: $(nproc)"
echo "Memory: $(free -h | grep Mem | awk '{print $3 "/" $2}')"
echo "Swap: $(free -h | grep Swap | awk '{print $3 "/" $2}')"
echo "Disk: $(df -h / | tail -1 | awk '{print $3 "/" $2 " (" $5 " used)"}')"
echo "IP: $(hostname -I 2>/dev/null || echo 'N/A')"
echo "TZ: $(cat /etc/timezone 2>/dev/null || date +%Z)"