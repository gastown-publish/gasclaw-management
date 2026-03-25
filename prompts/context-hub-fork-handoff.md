# Handoff prompt: Fork and extend Context Hub for Gasclaw

Copy everything below the line into a new Claude (or other agent) session.

---

## Role and goal

You are implementing a **fork and extension** of [Context Hub](https://github.com/andrewyng/context-hub) (MIT license) into a **new GitHub repository under `gastown-publish`**. The fork must:

1. **Preserve** upstream behavior: curated markdown content, `chub` CLI (`search`, `get`, `annotate`, `feedback`, `build`, `cache`, `update`), local registry paths, and the existing **content/** and **docs/** that ship with Context Hub.
2. **Rebase all project identity** on our org: change default GitHub URLs, issue links, contribution paths, npm package scope/name, and any hardcoded references to `andrewyng/context-hub` or `@aisuite/chub` where we own the fork.
3. **Add** a **Model Context Protocol (MCP)** server so OpenClaw/Cursor-style agents can call **search**, **get**, and optionally **annotate** without shelling to `chub` (implement in-repo; document install and config).
4. **Rewrite README** (and top-level docs that users see first) for **Gasclaw**: internal use, optional Tailscale-only deployment, how this relates to `gastown-publish/gasclaw-management`, and how agents should use CLI vs MCP.
5. **Optional (document + stub):** a **fifth Gasclaw container** pattern (`gasclaw-context` or similar) whose job is to **maintain** this repo (PRs, content validation, `chub build`), aligned with existing containers (`gasclaw-dev`, `gasclaw-minimax`, `gasclaw-gasskill`, `gasclaw-mgmt`). Provide a short **design note** and example `docker-compose` snippet or pointer—full production wiring can be phase 2.

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

- What Gasclaw is (one paragraph): multi-container AI agent platform; link to `gastown-publish/gasclaw-management`.
- Install: `npm install -g <our-package>` (or `npx`).
- Quickstart: `chub search`, `chub get`, link to **docs/cli-reference.md**.
- **Fork relationship**: “This repo is a fork of [andrewyng/context-hub](https://github.com/andrewyng/context-hub); we extend it with …”
- **MCP** subsection with copy-paste config.
- **Tailscale / private**: how to use `sources:` with `path:` for internal-only registries; never commit secrets.

### Container note (optional stub)

- Short **docs/gasclaw-container.md**: purpose of a dedicated maintainer container, env vars (GitHub token for PRs, path to repo), and that it shares the host’s Gasclaw image patterns. No need to fully implement OpenClaw in this task unless trivial—**design + placeholders** are enough.

## Constraints

- Do not remove MIT license or upstream attribution.
- Do not store API keys or Tailscale keys in the repo.
- Prefer **small, reviewable commits** with clear messages.
- Run **tests/build** that exist upstream; fix breakages from rename.

## Deliverables checklist

- [ ] New repo layout with renamed package and updated links
- [ ] README + CONTRIBUTING + SECURITY aligned with `gastown-publish`
- [ ] MCP package + documentation
- [ ] `NOTICE` file for fork provenance
- [ ] Optional: `docs/gasclaw-container.md` stub
- [ ] Short **CHANGELOG** entry: “Forked from context-hub @ &lt;commit&gt;”

## Verification

- `chub --help` works after install from workspace
- `chub search` / `chub get` against bundled content works
- MCP server starts and tools respond (smoke test)

---

_End of prompt._
