# Gasclaw stack health, MiniMax enforcement, and known limitations

This document explains **what the automation is trying to do**, **what breaks**, and how **`scripts/run_comprehensive_stack_check.sh`** fits together. Use it when handing work to another assistant (e.g. Claude in a tmux pane).

## Goals

1. **Prove every Gasclaw gateway is alive** — HTTP `GET /health` and `GET /ready` on each stack’s published port (minimax, dev, gasskill, context, mgmt).
2. **Enforce `moonshot/minimax-m2.5`** as the primary model and remove Kimi / `k2p5` routes from OpenClaw `openclaw.json` and per-agent `agents/*/agent/models.json`.
3. **Run as much as possible from inside `gasclaw-mgmt`** — bridge IP `172.17.0.1` reaches sibling containers’ ports from mgmt; **this container’s** gateway is probed on `127.0.0.1` (hairpin via the bridge IP fails for self).
4. **Optional:** `@gasclaw_mgmt_bot` Telegram polling — separate from Telethon; requires `channels.telegram` / token (see `scripts/apply-mgmt-telegram-token.sh`).

## Scripts (short map)

| Script | Runs on | Purpose |
|--------|---------|---------|
| `scripts/apply_minimax_fix_all_gasclaw.sh` | Host | Copies `fix_openclaw_minimax_local.py` into each container and applies MiniMax config. |
| `scripts/run_inside_mgmt_health_suite.sh` | Host → exec mgmt | `docker cp` fix into mgmt, streams `inside_mgmt_health_suite.sh`. |
| `scripts/inside_mgmt_health_suite.sh` | **Inside** `gasclaw-mgmt` | Gateway curls, `openclaw channels status`, re-patch after CLI, MiniMax JSON check on mgmt. |
| `scripts/check_all_containers_minimax.sh` | Host | Full MiniMax audit in **every** container via `docker exec`. |
| `scripts/run_comprehensive_stack_check.sh` | Host | Applies fix → in-mgmt suite → applies fix again → host audit (see “Ordering” below). |

Telethon / forum health remains separate (`scripts/forum_health.sh`, `gastown-publish/telethon`).

## Problems we hit (and mitigations)

### 1. OpenClaw CLI rewrites agent `models.json`

On **`gasclaw-mgmt`**, running **`openclaw channels status`** (even without `--probe`) can **overwrite** per-agent `models.json` back toward **Kimi** (`kimi-k2.5`, `kimi-coding`).  

**Mitigation:** `run_inside_mgmt_health_suite.sh` copies `fix_openclaw_minimax_local.py` to `/tmp/` and runs it **after** `openclaw channels status`.

### 2. Gateway HTTP checks can trigger config drift in *other* containers

Probing `/health` / `/ready` may wake gateways and allow OpenClaw to **mutate** configs on those stacks.  

**Mitigation:** `run_comprehensive_stack_check.sh` runs **`apply_minimax_fix_all_gasclaw.sh` before and after** the in-mgmt suite, then runs `check_all_containers_minimax.sh`.

### 3. `gasclaw-mgmt` cannot `docker exec` siblings by default

There is **no** `/var/run/docker.sock` in `gasclaw-mgmt`, so **peer** MiniMax file checks cannot run entirely inside mgmt without extra setup.  

**Mitigation:** Host script `check_all_containers_minimax.sh`.  

**Optional:** Mount the Docker socket and install the Docker CLI — see `examples/gasclaw-mgmt-docker-socket.override.yml.example`. Then `inside_mgmt_health_suite.sh` can run peer checks when `docker` + socket exist.

### 4. Telegram bot on mgmt “not configured”

`openclaw channels status` may show **Telegram default: not configured** until the management bot token is applied. That does **not** block gateway `/health`; it blocks **bot** messaging until fixed.

### 5. Telethon vs Bot API

Forum health uses **Telethon** (human MTProto session). Management stack uses **Bot API** (`@gasclaw_mgmt_bot`). Different credentials and processes — see `docs/telethon-where-to-run.md`.

## Ordering in `run_comprehensive_stack_check.sh`

1. Apply MiniMax fix — all containers.  
2. In-mgmt suite (gateways + `openclaw channels status` + re-patch mgmt).  
3. Apply MiniMax fix — all containers again (undo drift from probes/CLI).  
4. Host MiniMax audit — all containers.

## Human Telegram vs this automation

- **OpenClaw / gateway checks** in this doc do **not** post as your **personal** Telegram account. They only hit HTTP endpoints inside Docker.
- **Human-account traffic** (messages you see as “the user” in a group) comes from **Telethon** (`gastown-publish/telethon`: `gastown-telethon-ping`, `gastown-telethon-forum-health`, etc.) using `TELEGRAM_API_*`, phone, and a `*.session` file. That must be **run explicitly** on a machine that has the session (host or Telethon Docker bind-mount). Nothing in `run_comprehensive_stack_check.sh` sends Telethon messages.
- If you expect visible **human** pings in Telegram, run e.g. `gastown-telethon-ping` from the `telethon` repo venv after `pip install -e .`, or use `scripts/forum_health.sh` from `gasclaw-management`.

## tmux: verify a session is receiving work

```bash
tmux capture-pane -t 9 -p -S -120    # last ~120 lines of session 9
tmux list-panes -a -F '#{session_name}:#{window_index}.#{pane_index} #{pane_title}'
```

Inject a one-line prompt (sends Enter after the string):

```bash
tmux send-keys -t 9 'your prompt here' C-m
```

## Related docs

- `docs/telethon-where-to-run.md` — host vs container for Telethon.  
- `docs/forum-health.md` — per-topic bot pings.  
- `docs/mayor-escalation.md` — failures → `gasclaw-mgmt` OpenClaw agents.

## Handoff: ask Claude in tmux session `9`

Paste the block below into session `9` (or use `tmux send-keys` — see example). Replace paths if your clone differs.

```
You are helping with Gastown Gasclaw operations. Read this file for full context:
  /home/nic/gasclaw-workspace/gasclaw-management/docs/stack-health-openclaw-minimax.md

Tasks you can do next:
1. Run:  /home/nic/gasclaw-workspace/gasclaw-management/scripts/run_comprehensive_stack_check.sh
2. If MiniMax drift returns, re-run:  scripts/apply_minimax_fix_all_gasclaw.sh
3. If we need peer checks purely inside gasclaw-mgmt, evaluate mounting Docker socket per examples/gasclaw-mgmt-docker-socket.override.yml.example (security tradeoff).
4. Configure @gasclaw_mgmt_bot token if Telegram should be live: scripts/apply-mgmt-telegram-token.sh

Summarize pass/fail and any OpenClaw version quirks you observe.
```

### One-shot tmux inject (from any shell)

```bash
MSG='Read /home/nic/gasclaw-workspace/gasclaw-management/docs/stack-health-openclaw-minimax.md then run scripts/run_comprehensive_stack_check.sh and report results.'
tmux send-keys -t 9 "$MSG" C-m
```

Use `-t 9:0.0` if you need a specific window/pane index.
