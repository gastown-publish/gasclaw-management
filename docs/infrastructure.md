# Infrastructure Setup

## Hardware
- 8x NVIDIA H100 80GB HBM3 GPUs (640 GB VRAM)
- 2 TB system RAM, 224 CPU threads
- Storage: `/home/nic/data` (51 TB ZFS)
- NVIDIA driver: 590.48.01 (CUDA 13.1)

## vLLM (MiniMax M2.5)
- Model: `/home/nic/data/models/MiniMax-M2.5-HF/` (~230 GB, FP8)
- Config: TP=4, DP=2, EP=8, max-seqs=32, gpu-mem=0.85
- Start: `cd /home/nic/data/models/MiniMax-M2.5 && ./scripts/start.sh 8`
- Stop: `./scripts/stop.sh`
- Port: 8080
- Performance: ~640-720 tok/s, 128K context
- **CRITICAL**: `CUDA_HOME=/usr/local/cuda-12.8`, BF16 KV cache only, `VLLM_DISABLE_CUSTOM_ALL_REDUCE=1`

## LiteLLM Proxy
- Config: `/home/nic/data/models/MiniMax-M2.5/litellm-config.yaml`
- venv: `/home/nic/data/models/MiniMax-M2.5/.venv/`
- Port: 4000
- Master key: in config file
- DB: PostgreSQL `litellm` on localhost:5432
- Models: minimax-m2.5, claude-sonnet-4-6, claude-opus-4-6, kimi-k2.5 (all → vLLM)
- **CRITICAL**: `database_url` + `disable_prisma_schema_update: true`, `prisma` on PATH

## Gasclaw Containers

### gasclaw-dev
- User: `/home/gasclaw/gasclaw/`
- Image: `gasclaw-dev-gasclaw` (built locally)
- Compose: `/home/gasclaw/gasclaw/docker-compose.yml`
- Port: 18794 (gateway)
- Repo: gastown-publish/gasclaw
- Bot: @gasclaw_master_bot
- Agents: main, crew-1, crew-2

### gasclaw-minimax
- User: `/home/minimax/gasclaw/`
- Image: `gasclaw-minimax-gasclaw`
- Compose: `/home/minimax/gasclaw/docker-compose.yml`
- Port: 18793 (gateway)
- Repo: gastown-publish/minimax
- Bot: @minimax_gastown_publish_bot
- Agents: main, coordinator, developer, devops, tester, reviewer

### gasclaw-gasskill
- User: `/home/gasskill/gasclaw/`
- Image: `gasclaw-dev-gasclaw` (shared)
- Compose: `/home/gasskill/gasclaw/docker-compose.yml`
- Port: 18796 (gateway)
- Repo: gastown-publish/gasskill
- Bot: @gasskill_agent_bot
- Agents: main, skill-dev, skill-tester

### gasclaw-context (context-hub)
- User: `/home/gascontext/gasclaw/` (Unix user `gascontext`; container name **`gasclaw-context`** for `docker ps --filter name=gasclaw-`)
- Image: `gasclaw-dev-gasclaw` (shared)
- Compose: `/home/gascontext/gasclaw/docker-compose.yml` — **`name: gasclaw-context`**, **`container_name: gasclaw-context`**
- Port: 18797 (gateway)
- Repo: gastown-publish/context-hub
- Bot: TBD (@gascontext_bot)
- Agents: main, content-curator, mcp-tester
- Local clone: `/home/nic/gasclaw-workspace/context-hub`
- Mayor / ops: [docs/gasclaw-context.md](gasclaw-context.md)

## CloudFront Distribution
- Website: `minimax.villamarket.ai` → S3 `minimax-villamarket-website`
- Chat: `app.minimax.villamarket.ai` → DeerFlow (port 10000)
- API: `api.minimax.villamarket.ai` → Tailscale Funnel → LiteLLM (port 4000)

## Key Files
- LiteLLM config: `/home/nic/data/models/MiniMax-M2.5/litellm-config.yaml`
- Gasclaw source: `/home/nic/gasclaw-workspace/gasclaw/`
- Container .env files: `/home/{gasclaw,minimax,gasskill}/gasclaw/.env`
- Telegram test: `/home/nic/gasclaw-workspace/telegram-test/`
- Telethon session: `/home/nic/gasclaw-workspace/telegram-test/tg_test_session.session`
