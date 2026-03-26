#!/bin/bash
# Fix dolt push issue: "no common ancestor with remote"
# Bead: gt-00u (resolved)

set -e

cd /workspace/gt

echo "=== Checking dolt remotes ==="
dolt remote -v

echo ""
echo "=== Checking branch status ==="
git status
dolt log --oneline -5

echo ""
echo "=== Attempting fix: Force push ==="
# Warning: This will overwrite remote. Backup first.
read -p "Continue with force push? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    dolt push -f origin main
    echo "✓ Push successful"
else
    echo "Cancelled. Alternative: rebase onto remote branch"
    echo "  git rebase origin/main"
fi