#!/usr/bin/env bash
# Validates OpenClaw plugin configuration in JSON files
# Called by pre-commit hook to catch plugin configuration errors before commit

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

ERRORS=0

# Function to validate a single JSON file
validate_plugin_config() {
    local file="$1"

    if [ ! -f "$file" ]; then
        return 0
    fi

    # Check if file contains "plugins" key
    if ! grep -q '"plugins"' "$file" 2>/dev/null; then
        return 0
    fi

    echo "Validating plugin configuration in: $file"

    # Check for valid JSON
    if ! python3 -c "import json; json.load(open('$file'))" 2>/dev/null; then
        echo -e "${RED}✗ Invalid JSON in $file${NC}"
        ERRORS=$((ERRORS + 1))
        return 1
    fi

    # Extract and validate plugin configuration
    local plugins_json
    plugins_json=$(python3 -c "
import json
import sys

try:
    data = json.load(open('$file'))
    plugins = data.get('plugins', {})

    # Check for slots
    slots = plugins.get('slots', {})

    # Valid plugin types (adjust as needed)
    valid_plugins = ['none', 'memory', 'redis', 'postgres', 'sqlite', 'file']

    for slot_name, plugin_value in slots.items():
        if plugin_value not in valid_plugins:
            print(f'ERROR: Invalid plugin value \"{plugin_value}\" for slot \"{slot_name}\"')
            print(f'Valid values: {valid_plugins}')
            sys.exit(1)

    # Check for unknown keys in plugins section
    allowed_keys = {'slots', 'config', 'enabled'}
    for key in plugins.keys():
        if key not in allowed_keys:
            print(f'ERROR: Unknown key \"{key}\" in plugins section')
            print(f'Allowed keys: {allowed_keys}')
            sys.exit(1)

    print('OK')
except json.JSONDecodeError as e:
    print(f'ERROR: Invalid JSON - {e}')
    sys.exit(1)
except Exception as e:
    print(f'ERROR: {e}')
    sys.exit(1)
" 2>&1)

    if [ "$plugins_json" = "OK" ]; then
        echo -e "${GREEN}✓ Plugin configuration valid${NC}"
        return 0
    else
        echo -e "${RED}✗ $plugins_json${NC}"
        ERRORS=$((ERRORS + 1))
        return 1
    fi
}

# Main: find all JSON files in the diff that contain "plugins"
echo "=== OpenClaw Plugin Configuration Validation ==="

# Get list of staged JSON files
STAGED_JSON=$(git diff --cached --name-only --diff-filter=ACM | grep -E '\.(json)$' || true)

if [ -z "$STAGED_JSON" ]; then
    echo "No JSON files staged for commit"
    exit 0
fi

echo "Checking staged JSON files for plugin configuration..."

for file in $STAGED_JSON; do
    validate_plugin_config "$file" || true
done

if [ $ERRORS -gt 0 ]; then
    echo ""
    echo -e "${RED}Plugin validation failed: $ERRORS error(s)${NC}"
    echo "Please fix the plugin configuration errors before committing."
    exit 1
fi

echo ""
echo -e "${GREEN}✓ All plugin configurations valid${NC}"
exit 0