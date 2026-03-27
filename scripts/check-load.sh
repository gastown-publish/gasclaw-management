#!/bin/bash
# Check if load average is too high
# Usage: ./check-load.sh [threshold]

THRESHOLD="${1:-50}"  # default threshold
LOAD=$(cat /proc/loadavg | awk '{print $1}')
CORES=$(nproc)
LOAD_PER_CORE=$(awk "BEGIN {printf \"%.2f\", $LOAD/$CORES}")

echo "Load: $LOAD (cores: $CORES, per-core: $LOAD_PER_CORE)"

IS_HIGH=$(awk "BEGIN {print ($LOAD > $THRESHOLD) ? 1 : 0}")
if [ "$IS_HIGH" = "1" ]; then
    echo "WARNING: Load $LOAD exceeds threshold $THRESHOLD"
    exit 1
fi

echo "OK: Load within threshold"
exit 0