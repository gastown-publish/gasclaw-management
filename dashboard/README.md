# Gasclaw Management Dashboard

Real-time monitoring dashboard for the Gasclaw platform - autonomous AI agent infrastructure running on 8x NVIDIA H100 80GB GPUs.

**URL:** https://status.gpu.villamarket.ai

## Features

### Infrastructure Monitoring
- **Docker Containers** - Real-time status of all gasclaw containers
- **OpenClaw Gateways** - Health checks for each container's gateway
- **Agent Status** - Track which agents are active/idle/offline

### MiniMax Service Metrics
- **Throughput** - Tokens per second, total tokens processed
- **Parallel Sessions** - Running and waiting request counts
- **KV Cache Usage** - Per-engine cache utilization
- **Engine States** - Awake/asleep status and weight offloading
- **Historical Charts** - Visual throughput trends

### Issue Tracking
- **Beads Integration** - Live view of open issues from beads
- **Priority Breakdown** - Critical/High/Medium/Low categorization

### GPU Monitoring
- **8x H100 Status** - Temperature, utilization, VRAM usage
- **Visual Indicators** - Color-coded health states

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    status.gpu.villamarket.ai                 │
│                      (CloudFront CDN)                        │
└───────────────────────────┬─────────────────────────────────┘
                            │
┌───────────────────────────▼─────────────────────────────────┐
│              GPU Server (api.minimax.villamarket.ai)        │
│  ┌──────────────────────────────────────────────────────┐   │
│  │           Flask Dashboard (port 5000)                │   │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐          │   │
│  │  │  Docker  │  │  vLLM    │  │  Beads   │          │   │
│  │  │   API    │  │ Metrics  │  │   CLI    │          │   │
│  │  └──────────┘  └──────────┘  └──────────┘          │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

## Quick Start

### Prerequisites
- Python 3.11+
- Docker (for container monitoring)
- Access to GPU server

### Local Development

```bash
cd dashboard

# Create virtual environment
python3 -m venv .venv
source .venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Run development server
python app.py
```

Visit http://localhost:5000

### Production Deployment

```bash
# Deploy to GPU server
./deploy.sh

# Deploy CloudFront distribution (requires AWS CLI)
./aws/deploy-cloudfront.sh
```

## API Endpoints

| Endpoint | Description |
|----------|-------------|
| `GET /api/health` | Health check |
| `GET /api/overview` | Complete system overview |
| `GET /api/containers` | Docker container status |
| `GET /api/gateways` | Gateway health status |
| `GET /api/services` | Core services (vLLM, LiteLLM) |
| `GET /api/minimax` | MiniMax service metrics |
| `GET /api/agents` | Agent status |
| `GET /api/issues` | Beads issues |
| `GET /api/metrics` | System/GPU metrics |

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `DASHBOARD_PORT` | 5000 | Server port |
| `FLASK_ENV` | production | Flask environment |
| `MOONSHOT_API_KEY` | - | API key for agent activation |

### CloudFront Settings

The CloudFront distribution is configured to:
- Cache static assets for 1 day
- No caching for `/api/*` endpoints
- HTTPS redirect
- Gzip/Brotli compression

## File Structure

```
dashboard/
├── app.py                 # Flask backend API
├── wsgi.py               # WSGI entry point
├── requirements.txt      # Python dependencies
├── Dockerfile           # Container image
├── deploy.sh            # Deployment script
├── README.md            # This file
├── logs/                # Log files
├── static/              # Frontend assets
│   ├── index.html      # Main dashboard UI
│   ├── dashboard.js    # Frontend logic
│   └── styles.css      # Styles
└── aws/                # AWS infrastructure
    ├── cloudfront.yaml # CloudFormation template
    ├── deploy-cloudfront.sh
    └── gasclaw-dashboard.service
```

## Monitoring Endpoints

The dashboard collects metrics from:

| Source | Endpoint | Data |
|--------|----------|------|
| Docker | Local socket | Container status |
| vLLM | localhost:8080/metrics | MiniMax metrics |
| OpenClaw | :18793-18796/health | Gateway health |
| Beads | `bd list --json` | Issues |
| nvidia-smi | Local | GPU stats |

## Troubleshooting

### Dashboard not loading
```bash
# Check if running
curl http://localhost:5000/api/health

# Check logs
tail -f logs/error.log
```

### Missing container data
```bash
# Verify Docker access
docker ps

# Check permissions
sudo usermod -aG docker $USER
```

### CloudFront 502 error
- Verify GPU server is accessible from CloudFront
- Check security groups allow port 5000
- Ensure HTTPS/HTTP protocols match

## Security

- Dashboard runs behind CloudFront with HTTPS
- API endpoints served from same origin
- No authentication required (internal tool)
- CORS configured for CloudFront domain

## Development

### Adding New Metrics

1. Add collector function in `app.py`
2. Add API endpoint
3. Update frontend in `static/dashboard.js`
4. Add UI component in `static/index.html`

### Testing

```bash
# Run all API tests
curl http://localhost:5000/api/overview | python3 -m json.tool

# Test specific endpoint
curl http://localhost:5000/api/minimax | python3 -m json.tool
```

## License

Same as gasclaw-management repository.
