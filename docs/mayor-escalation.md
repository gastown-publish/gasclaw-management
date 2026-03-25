# Mayor escalation — failures → gasclaw-mgmt OpenClaw → Gastown mayor loop

When **forum health**, **gateway**, or **mayor** checks fail, **gasclaw-mgmt** should drive remediation: **inform OpenClaw with details**, have the agent **watch the Gastown mayor** (`gt mayor`), **interact** (diagnose / restart / fix config), and **retest** until green.

## Terms

| Term | Meaning |
|------|--------|
| **Mayor** | Gastown orchestrator: `gt mayor` in each container under `/workspace/gt` (tmux `hq-mayor`). Not a Telegram user. |
| **gasclaw-mgmt** | Docker container for `gastown-publish/gasclaw-management`; OpenClaw bot `@gasclaw_mgmt_bot`, forum topic **921**. |
| **Escalation** | After a failed health run, OpenClaw agent **`infra`** (or `main`) receives a structured message with logs and explicit remediation steps. |

## Desired loop

1. **Detect** — `forum_health.sh` exits non-zero, or watchdog restarts gateway, or `gt mayor status` is not healthy.
2. **Inform OpenClaw** — Host script [`scripts/forum_health_escalate.sh`](../scripts/forum_health_escalate.sh) (optional) sends a message into the mgmt gateway for agent **`infra`** with exit code, timestamp, and log tail.
3. **Watch mayor** — Inside **gasclaw-mgmt** (and affected peers if needed): `cd /workspace/gt && gt mayor status` (and logs if stuck).
4. **Interact** — Fix root cause: Telegram token, `openclaw.json`, gateway process, LiteLLM/model auth, or mayor restart (`gt mayor stop` / `gt mayor start --agent <name>` per [gastown reference](https://github.com/gastown-publish/gasclaw/blob/main/reference/gastown-cli.md)).
5. **Retest** — Re-run `forum_health.sh` (or full [`tests/verify-all.sh`](../tests/verify-all.sh)) until exit **0**; confirm `openclaw channels status --probe` and `gt mayor status`.

Repeat until resolved; document in topic **921** or beads if work spans sessions.

## Enable automatic OpenClaw notification on forum-health failure

On the host that runs Telethon (same crontab as hourly health):

```bash
export GASCLAW_ESCALATE_ON_FAILURE=1
export GASCLAW_MGMT_CONTAINER=gasclaw-mgmt      # default
export GASCLAW_ESCALATE_AGENT=infra             # or main
/path/to/gasclaw-management/scripts/forum_health_escalate.sh >> /tmp/forum-health.log 2>&1
```

Requires:

- `docker` CLI on that host pointing at the GPU machine’s Docker (or same host).
- **gasclaw-mgmt** container running with `openclaw` on `PATH`.
- Agent **`infra`** (or chosen agent) defined in that container’s `openclaw.json`.

If Docker is not available on the health host, keep `GASCLAW_ESCALATE_ON_FAILURE` unset and rely on **manual** escalation using the same message body (copy from `/tmp/forum-health-last-run.log` into Telegram topic 921 or `openclaw agent` by hand).

## Workspace instructions (paste into gasclaw-mgmt)

Copy the snippet in [workspace-AGENTS-mgmt-snippet.md](workspace-AGENTS-mgmt-snippet.md) into `~/.openclaw/workspace/AGENTS.md` on **gasclaw-mgmt** so **`infra` / `main`** consistently escalate mayor issues and retest.

## Related

- [forum-health.md](forum-health.md) — Telethon per-topic checks.
- [HANDOFF.md](../HANDOFF.md) — ports, tokens, containers.
- [scripts/attach-mayor.sh](../scripts/attach-mayor.sh) — interactive `gt mayor attach`.
