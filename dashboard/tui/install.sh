#!/bin/bash
# Install gasclaw-tui

set -e

echo "Installing Gasclaw TUI..."

# Check Python version
python_version=$(python3 --version 2>&1 | awk '{print $2}' | cut -d. -f1,2)
required_version="3.8"

if [ "$(printf '%s\n' "$required_version" "$python_version" | sort -V | head -n1)" != "$required_version" ]; then 
    echo "Error: Python 3.8+ required, found $python_version"
    exit 1
fi

# Install dependencies
echo "Installing dependencies..."
pip3 install --user -q click requests rich pyyaml 2>/dev/null || pip3 install -q click requests rich pyyaml

# Create symlink
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="$SCRIPT_DIR/gasclaw.py"

if [ -d "$HOME/.local/bin" ]; then
    mkdir -p "$HOME/.local/bin"
    ln -sf "$TARGET" "$HOME/.local/bin/gasclaw"
    echo "Installed to $HOME/.local/bin/gasclaw"
    echo "Make sure ~/.local/bin is in your PATH"
elif [ -d "$HOME/bin" ]; then
    ln -sf "$TARGET" "$HOME/bin/gasclaw"
    echo "Installed to $HOME/bin/gasclaw"
else
    echo "Please add $SCRIPT_DIR to your PATH or create a symlink manually:"
    echo "  sudo ln -s $TARGET /usr/local/bin/gasclaw"
fi

echo ""
echo "Installation complete!"
echo ""
echo "Quick start:"
echo "  gasclaw status        # Show system status"
echo "  gasclaw status --json # JSON output for AI"
echo "  gasclaw tui           # Interactive mode"
