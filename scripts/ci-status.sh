#!/bin/bash
# CI Status - Check GitHub Actions workflow status
# Usage: ./ci-status.sh [workflow-name]

WORKFLOW="${1:-Telegram Integration Tests}"
REPO="${REPO:-gastown-publish/gasclaw-management}"
TOKEN="${GITHUB_TOKEN:-}"

if [ -z "$TOKEN" ]; then
    echo "ERROR: GITHUB_TOKEN not set"
    echo "Set with: export GITHUB_TOKEN=ghp_..."
    exit 1
fi

# Get latest workflow run
response=$(curl -s -H "Authorization: token $TOKEN" \
    "https://api.github.com/repos/$REPO/actions/workflows/$WORKFLOW/runs?per_page=1")

# Parse status
status=$(echo "$response" | jq -r '.workflow_runs[0].conclusion // .workflow_runs[0].status // "none"')
conclusion=$(echo "$response" | jq -r '.workflow_runs[0].conclusion // "pending"')

echo "Workflow: $WORKFLOW"
echo "Status: $conclusion"

# Parse details
if [ "$conclusion" = "success" ]; then
    echo "✓ CI PASSED"
    exit 0
elif [ "$conclusion" = "failure" ]; then
    echo "✗ CI FAILED"
    exit 1
elif [ "$conclusion" = "pending" ]; then
    echo "◐ CI RUNNING"
    exit 2
else
    echo "? CI UNKNOWN"
    exit 3
fi