# Issue Tracker

All issues tracked with `bd` (beads). This file lists known open issues across all repos.

## Open Issues — gastown-publish/gasclaw

| # | Title | Type | Priority |
|---|-------|------|----------|
| 340 | Bootstrap should write workspace AGENTS.md with team roster | bug | high |
| 341 | Bootstrap should activate all agent sessions after startup | bug | high |
| 342 | Telegram groupPolicy should use 'open' with requireMention per docs | bug | medium |
| 343 | Auto-spawn thread-bound agents on Telegram session start | enhancement | medium |
| 338 | Add health check endpoint test for Dolt TCP connectivity | test | low |
| 335 | Support multi-agent team setup documentation | docs | low |
| 334 | Docker container persistence: OpenClaw state lost on restart | docs | low |
| 333 | groupPolicy config validation rejects valid 'open' policy | bug | medium |
| 330 | OpenClaw installer merges agent configs incorrectly | bug | medium |
| 328 | MiniMax/Custom API URL Support: Hardcoded Kimi API URLs | enhancement | medium |

## Open Issues — gastown-publish/minimax

| # | Title | Type | Priority |
|---|-------|------|----------|
| 51 | Add health check for vLLM backend connectivity | test | low |
| 43 | mm launch toad: ACP adapter not found | bug | high |
| 17 | CRITICAL: Insecure CORS in Lambda | security | critical |
| 16 | CRITICAL: Command injection in ACP Server | security | critical |
| 15 | CRITICAL: Hardcoded DB password in start-all.sh | security | critical |

## Open PRs

| Repo | # | Title | CI |
|------|---|-------|----|
| gasclaw | 339 | TestDoltTcpCheck tests | pending |
| minimax | 52 | healthcheck.sh | ✅ passed |

## Completed This Session

### Fixes pushed to gasclaw main:
1. Fixed 10 failing tests (bootstrap mocks, lifecycle tests)
2. Fixed 19 lint errors
3. Fixed 4 bootstrap bugs (dolt init, TCP socket check, port mismatch, cwd)
4. Fixed proxy.py to respect env vars (not hardcode Kimi)
5. Fixed lifecycle tests for SIM117 lint
6. Added CI-must-pass rules to CLAUDE.md
7. Closed 16 issues (#312-#324, #331, #332, #337)

### Infrastructure created:
1. New Linux user `gasskill`
2. New Telegram bot `@gasskill_agent_bot` (token: stored in .env)
3. New gasclaw container `gasclaw-gasskill` for gastown-publish/gasskill
4. All 3 bots connected to Telegram group
5. OpenClaw configured with agent teams, model auth, thread bindings
6. Telethon integration tests (session saved, no OTP needed)
7. Full gist documentation: https://gist.github.com/villaApps/93be609d185e5a4009112337c15a7a6c
