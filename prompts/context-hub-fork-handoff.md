# Handoff prompt: Fork and extend Context Hub for Gasclaw

**This file (absolute path):** `/home/nic/gasclaw-workspace/gasclaw-management/prompts/context-hub-fork-handoff.md`

Copy everything below the line into a new Claude (or other agent) session.

---

## Role and goal

You are implementing a **fork and extension** of [Context Hub](https://github.com/andrewyng/context-hub) (MIT license) into a **new GitHub repository under `gastown-publish`**. The fork must:

1. **Preserve** upstream behavior: curated markdown content, `chub` CLI (`search`, `get`, `annotate`, `feedback`, `build`, `cache`, `update`), local registry paths, and the existing **content/** and **docs/** that ship with Context Hub.
2. **Rebase all project identity** on our org: change default GitHub URLs, issue links, contribution paths, npm package scope/name, and any hardcoded references to `andrewyng/context-hub` or `@aisuite/chub` where we own the fork.
3. **Add** a **Model Context Protocol (MCP)** server so OpenClaw/Cursor-style agents can call **search**, **get**, and optionally **annotate** without shelling to `chub` (implement in-repo; document install and config).
4. **Rewrite README** (and top-level docs that users see first) for **Gasclaw**: internal use, optional Tailscale-only deployment, how this relates to `gastown-publish/gasclaw-management`, and how agents should use CLI vs MCP.
5. **Optional (document + stub):** a **fifth Gasclaw container** pattern (`gasclaw-context` or similar) whose job is to **maintain** this repo (PRs, content validation, `chub build`), aligned with existing containers (`gasclaw-dev`, `gasclaw-minimax`, `gasclaw-gasskill`, `gasclaw-mgmt`). Provide a short **design note** and example `docker-compose` snippet or pointer—full production wiring can be phase 2.
6. **Gasclaw-managed development (required):** Treat the fork as a repo **owned and operated by the Gasclaw platform**. Document and wire the workflow so ongoing work (issues, PRs, CI, beads, releases) runs **through Gasclaw**, not only manual laptop git. See **“Gasclaw management model”** below.

## Absolute paths and repos on this host (use these in docs you add)

| What | Absolute path or URL |
|------|----------------------|
| Platform / SSOT repo (this machine) | `/home/nic/gasclaw-workspace/gasclaw-management` |
| This handoff prompt | `/home/nic/gasclaw-workspace/gasclaw-management/prompts/context-hub-fork-handoff.md` |
| Suggested local clone of the **fork** while building it | `/home/nic/gasclaw-workspace/context-hub` (create if missing; name may match final repo slug) |
| GitHub platform repo | `https://github.com/gastown-publish/gasclaw-management` |
| Gasclaw **management** container on GPU host | Docker name: `gasclaw-mgmt` |
| Typical Gas Town workspace **inside** `gasclaw-mgmt` | `/workspace/gt` (bind-mount / checkout of `gastown-publish/gasclaw-management`) |
| Optional host path pattern for Gasclaw user data (if referenced in compose) | `/home/gasclaw-mgmt/` (see existing Gasclaw compose on server) |

Adjust only if the operator’s home directory differs; **keep paths absolute** in any **Gasclaw runbook** or **docs/gasclaw-*.md** you add.

## Gasclaw management model (required)

The fork is not a one-off patch: **Gasclaw agents are the primary way we manage this repo** after bootstrap.

- **Platform:** Multiple Docker containers run OpenClaw gateways; each container is tied to a GitHub repo. See `gastown-publish/gasclaw-management` (`CLAUDE.md`, `HANDOFF.md`).
- **Management stack:** Container **`gasclaw-mgmt`**, Telegram bot **`@gasclaw_mgmt_bot`**, gateway (typical port **18798**), repo **`gastown-publish/gasclaw-management`**. Agents (e.g. main / infra / ci-watcher) coordinate infra, CI, and cross-repo concerns.
- **After the fork exists:** Add documentation in the **fork’s** README and a **`docs/gasclaw.md`** (or extend **`docs/gasclaw-container.md`**) that states explicitly:
  - Which **Gasclaw container** checks out **`gastown-publish/<fork-repo>`** (either a **new** container dedicated to Context Hub, or **`gasclaw-mgmt`** with a second workspace—pick one model and document it).
  - That maintainers use **`gt` / OpenClaw** / Telegram **`@gasclaw_mgmt_bot`** (or the fork’s own bot if you add a fifth container) for day-to-day work: branches, PRs, `chub build`, MCP smoke tests, and beads issues filed from **`/home/nic/gasclaw-workspace/gasclaw-management`** when platform-wide.
  - **CI must pass** before merge; align with org rules (`gh pr checks`).
- **Cross-link:** From **`/home/nic/gasclaw-workspace/gasclaw-management`**, add or update a short pointer (e.g. in `README.md` or `docs/`) to the fork repo once created, so operators know Context Hub lives under Gasclaw.

Do **not** put secrets in the fork; use GitHub Actions secrets and env on the host/container as today.

## Upstream reference

- Source: `https://github.com/andrewyng/context-hub`
- Suggested new repo name: **`gastown-publish/context-hub`** (or `gasclaw-context-hub` if naming collision—choose one and use it consistently).
- License: keep **MIT**; retain upstream copyright notices and add a **NOTICE** file listing the fork and link to original.

## Technical requirements

### Git / GitHub

- Create the new repo (or prepare a branch) with **full history** from upstream (`git clone` + add remote, or GitHub “fork” into org if permissions allow).
- Replace **all** user-facing GitHub base URLs:
  - `github.com/andrewyng/context-hub` → `github.com/gastown-publish/<chosen-repo>`
- Update **CONTRIBUTING.md**, **SECURITY.md** (security contact), **package.json** / workspace names, **npm** package name if publishing (e.g. `@gastown/context-hub` or scoped under org—pick one scheme and document).
- CI (`.github/workflows`): fix paths, secrets names, and badges in README.

### Content

- **Keep** the bundled **content/** tree and **docs/** from current upstream so `chub` still has a useful default corpus unless upstream license/docs require attribution blocks—add **Fork notice** in README.
- Ensure **internal** docs explain how to add a **Gasclaw-specific** content pack under `content/` or a separate path + `chub build`.
- Default **registry/CDN** URLs in code and `~/.chub/config.yaml` examples: either **keep** read access to upstream community CDN **and** document our **internal** `path:` source, or mirror—**document the trust model** (public vs private).

### MCP

- Add **`mcp/`** (or `packages/mcp-server/`) with a small Node (or TypeScript) MCP server that:
  - Exposes tools: at minimum `chub_search`, `chub_get` (mirror CLI flags where useful: `--lang`, `--json` behavior).
  - Optionally: `chub_annotate` (if safe for your threat model).
  - Reads the same config as CLI (`~/.chub/config.yaml`) or env overrides for CI/containers.
- Include **README section**: how to register the MCP server in Cursor / Claude Desktop / OpenClaw (whatever is accurate for each).
- Add a **minimal test** or `npm run check` step so MCP starts and lists tools.

### README (must include)

- What Gasclaw is (one paragraph): multi-container AI agent platform; link to `gastown-publish/gasclaw-management` and absolute path **`/home/nic/gasclaw-workspace/gasclaw-management`** for operators on this host.
- **Gasclaw management** subsection: container/bot model, Telegram `@mention` rules, and that this repo is maintained via Gasclaw (see **`docs/gasclaw.md`**).
- Install: `npm install -g <our-package>` (or `npx`).
- Quickstart: `chub search`, `chub get`, link to **docs/cli-reference.md**.
- **Fork relationship**: “This repo is a fork of [andrewyng/context-hub](https://github.com/andrewyng/context-hub); we extend it with …”
- **MCP** subsection with copy-paste config.
- **Tailscale / private**: how to use `sources:` with `path:` for internal-only registries; never commit secrets.

### Container note (optional stub)

- Short **docs/gasclaw-container.md**: purpose of a dedicated maintainer container, env vars (GitHub token for PRs, path to repo), bind-mount of **`/home/nic/gasclaw-workspace/context-hub`** (or final path), and that it shares the host’s Gasclaw image patterns. No need to fully implement OpenClaw in this task unless trivial—**design + placeholders** are enough.

## Constraints

- Do not remove MIT license or upstream attribution.
- Do not store API keys or Tailscale keys in the repo.
- Prefer **small, reviewable commits** with clear messages.
- Run **tests/build** that exist upstream; fix breakages from rename.

## Deliverables checklist

- [ ] New repo layout with renamed package and updated links
- [ ] README + CONTRIBUTING + SECURITY aligned with `gastown-publish`
- [ ] **`docs/gasclaw.md`** (or equivalent): Gasclaw management workflow, absolute paths, container/bot names
- [ ] MCP package + documentation
- [ ] `NOTICE` file for fork provenance
- [ ] Optional: `docs/gasclaw-container.md` stub
- [ ] Short **CHANGELOG** entry: “Forked from context-hub @ &lt;commit&gt;”
- [ ] Pointer from **`/home/nic/gasclaw-workspace/gasclaw-management`** to the new fork (README or `docs/`)

## Verification

- `chub --help` works after install from workspace
- `chub search` / `chub get` against bundled content works
- MCP server starts and tools respond (smoke test)
- **`docs/gasclaw.md`** describes how Gasclaw manages this repo using paths above

---

_End of prompt._
