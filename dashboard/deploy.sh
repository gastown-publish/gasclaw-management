#!/bin/bash
# Gasclaw Management Dashboard Deployment Script
# Deploys the dashboard to run behind CloudFront at status.gpu.villamarket.ai

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

DASHBOARD_PORT=${DASHBOARD_PORT:-5000}
DOMAIN="status.gpu.villamarket.ai"

echo "🚀 Deploying Gasclaw Management Dashboard..."
echo "   Domain: $DOMAIN"
echo "   Port: $DASHBOARD_PORT"
echo ""

# Check prerequisites
check_prereq() {
    if ! command -v "$1" &> /dev/null; then
        echo "❌ $1 is not installed"
        return 1
    fi
    echo "✅ $1 found"
}

echo "Checking prerequisites..."
check_prereq python3
check_prereq pip3
check_prereq docker || true  # Optional but recommended

# Create virtual environment if it doesn't exist
echo ""
echo "📦 Setting up Python environment..."
if [ ! -d ".venv" ]; then
    python3 -m venv .venv
fi

source .venv/bin/activate

# Install/update dependencies
echo "Installing dependencies..."
pip install -q -r requirements.txt

# Stop existing service if running
echo ""
echo "🛑 Stopping existing dashboard (if running)..."
pkill -f "gunicorn.*app:app" 2>/dev/null || true
sleep 2

# Start the dashboard
echo ""
echo "▶️  Starting dashboard on port $DASHBOARD_PORT..."
nohup gunicorn \
    --bind "0.0.0.0:$DASHBOARD_PORT" \
    --workers 2 \
    --threads 4 \
    --timeout 30 \
    --access-logfile logs/access.log \
    --error-logfile logs/error.log \
    --capture-output \
    --daemon \
    app:app

# Wait for startup
sleep 3

# Check if running
if curl -sf "http://localhost:$DASHBOARD_PORT/api/health" > /dev/null 2>&1; then
    echo "✅ Dashboard is running at http://localhost:$DASHBOARD_PORT"
    echo ""
    echo "📊 Dashboard URLs:"
    echo "   Local:     http://localhost:$DASHBOARD_PORT"
    echo "   CloudFront: https://$DOMAIN (after DNS update)"
    echo ""
else
    echo "❌ Dashboard failed to start. Check logs/error.log"
    exit 1
fi

# Create/update systemd service (if running as root or with sudo)
if [ "$EUID" -eq 0 ] || sudo -n true 2>/dev/null; then
    echo "📝 Installing systemd service..."
    sudo cp aws/gasclaw-dashboard.service /etc/systemd/system/
    sudo systemctl daemon-reload
    sudo systemctl enable gasclaw-dashboard
    echo "   Service installed. Start with: sudo systemctl start gasclaw-dashboard"
fi

echo ""
echo "✨ Deployment complete!"
echo ""
echo "Next steps:"
echo "   1. Ensure port $DASHBOARD_PORT is accessible from CloudFront"
echo "   2. Update CloudFront origin to point to this server"
echo "   3. Access dashboard at https://$DOMAIN"
