# Glossary — Gasclaw Platform

## Roles

| Term | Definition |
|------|-----------|
| **Mayor** | The top-level orchestrator agent in a container. Runs `gt mayor attach`. Coordinates all other agents, makes decisions, delegates work. Each container has exactly one mayor (the `main` agent). |
| **Crew** | Sub-agents under the mayor. Specialists (developer, reviewer, tester, etc.) that the mayor spawns to do specific work. |
| **Overseer** | Synonym for mayor. The `main` agent identity in each container. |
| **Infra Monitor** | Sub-agent in `gasclaw-mgmt` that watches gateway health, service status, and container state. |
| **CI Watcher** | Sub-agent in `gasclaw-mgmt` that monitors GitHub Actions across all repos. |
| **Content Curator** | Sub-agent in `gasclaw-context` that validates content packs and runs `gashub build`. |

## Containers

| Term | Definition |
|------|-----------|
| **gasclaw-dev** | Container managing `gastown-publish/gasclaw` (the platform code itself). Mayor: Gasclaw Overseer. Crew: crew-1 (Developer), crew-2 (Reviewer). |
| **gasclaw-minimax** | Container managing `gastown-publish/minimax` (MiniMax CLI, website, vLLM config). Mayor: MiniMax Overseer. Crew: coordinator, developer, devops, tester, reviewer. |
| **gasclaw-gasskill** | Container managing `gastown-publish/gasskill` (skills and plugins). Mayor: Gasskill Overseer. Crew: skill-dev, skill-tester. |
| **gasclaw-mgmt** | Container managing `gastown-publish/gasclaw-management` (this repo — infra, scripts, docs, monitoring). Mayor: Management Overseer. Crew: infra, ci-watcher. **The mgmt mayor controls the hourly Telethon health check and coordinates all other containers.** |
| **gasclaw-context** | Container managing `gastown-publish/context-hub` (gashub CLI + MCP). Mayor: Context Hub Overseer. Crew: content-curator, mcp-tester. **Telegram disabled** until `@gascontext_bot` is registered. |

## Services

| Term | Definition |
|------|-----------|
| **Gateway** | OpenClaw gateway process running inside each container. Listens on a unique port (18793-18798). Handles Telegram bot polling, agent sessions, and LLM routing. |
| **LiteLLM** | Proxy on port 4000. Routes model requests to vLLM. Handles API key auth, cost tracking, model aliases. |
| **vLLM** | Inference server on port 8080. Runs MiniMax-M2.5 on 8x H100 GPUs. TP4+DP2+EP8. |
| **Tailscale Funnel** | Exposes LiteLLM (port 4000) to the internet via Tailscale's HTTPS tunnel. Used by CloudFront. |
| **Watchdog** | Cron script (`*/5 * * * *`) that checks gateway health, vLLM, LiteLLM, and funnel. Auto-restarts crashed services. |

## Tools

| Term | Definition |
|------|-----------|
| **gashub** | CLI tool for searching and fetching LLM-optimized documentation. Fork of Context Hub. `gashub search`, `gashub get`, `gashub annotate`. |
| **gashub-mcp** | MCP server for gashub. Exposes `gashub_search`, `gashub_get`, `gashub_list`, `gashub_annotate`, `gashub_feedback` as tools. |
| **Beads (`bd`)** | Issue tracker. `bd ready` shows open work, `bd close <id>` completes issues. Stored in `.beads/` directory. |
| **Gastown (`gt`)** | Git workflow tool. `gt mayor attach` starts the mayor. `gt daemon run` manages background tasks. |
| **OpenClaw** | Agent framework. Manages agent sessions, Telegram integration, tool execution, and model routing. Config in `~/.openclaw/openclaw.json`. |

## Telegram

| Term | Definition |
|------|-----------|
| **Topic** | Forum thread in the `gastown_publish` Telegram group (-1003810709807). Each container's bot auto-responds in its own topic only. |
| **@mention** | Required for a bot to respond outside its own topic. `requireMention: true` at group level, `false` in own topic. |
| **Forum health** | Hourly Telethon check that sends a structured prompt to each topic and verifies the correct bot responds with numerical metrics. |
| **Telethon** | Python library using a human Telegram account (MTProto) to send test messages. NOT the bot API. Runs on the host, not inside containers. |

## Model Config

| Term | Definition |
|------|-----------|
| **`moonshot/kimi-k2.5`** | The model identifier used in `openclaw.json` primary. `moonshot` = provider name, `kimi-k2.5` = model ID in `models.json`. Routes to LiteLLM → vLLM (MiniMax-M2.5). |
| **`models.json`** | Per-agent file at `agents/*/agent/models.json`. Defines providers, API URLs, and model IDs. Must have `baseUrl: https://api.minimax.villamarket.ai/v1`. |
| **Model drift** | When gateway restart or OpenClaw CLI overwrites `models.json` back to upstream defaults (api.moonshot.ai, kimi-coding/k2p5). Fix by copying from working container. |
| **Auth cooldown** | When `auth-profiles.json` records a failed auth attempt, it puts the provider on cooldown. Clear by copying clean auth-profiles from a working container. |

## Processes

| Term | Definition |
|------|-----------|
| **Hourly report** | Cron job (`0 * * * *`) where the mgmt mayor sends a context-aware prompt to each bot topic via Telethon. Bots must respond with numerical metrics, work summary, goals, and improvement plan. |
| **Rolling restart** | Updating containers one at a time: kill gateway → fix config → start gateway → verify → next. Never restart all at once. |
| **Bootstrap** | The startup sequence when a container first runs: configure git, start dolt, install gastown, configure OpenClaw, start gateway, activate agents. |
