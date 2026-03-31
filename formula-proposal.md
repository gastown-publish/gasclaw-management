# Formula Proposal: 3 New Formulas for Gas Town

## Overview

After reviewing all 42 existing formulas, I've identified gaps and propose 3 new formulas to improve Gas Town operations.

---

## Proposed Formula 1: `mol-code-review`

**Purpose**: Crew code review workflow - systematic PR/branch review with structured feedback

**Why needed**:
- Only `mol-polecat-code-review` exists (for polecats)
- No dedicated crew workflow for reviewing external PRs
- Gas Town has many repos needing review coverage

**What it does**:
1. Accepts PR URL or branch reference
2. Clones and analyzes code changes
3. Runs static analysis (if configured)
4. Generates structured review checklist
5. Files review bead with findings
6. Posts review comments to GitHub

**Variables**:
- `repo` (required): Repository owner/repo
- `pr` (required): PR number
- `reviewer` (optional): Specific crew member
- `focus` (optional): areas to prioritize (security, perf, docs)

---

## Proposed Formula 2: `mol-knowledge-capture`

**Purpose**: Capture and organize institutional knowledge from sessions

**Why needed**:
- No formula for capturing decisions, patterns, or learnings
- Knowledge lives in session context only
- Seance is query-based, not capture-based

**What it does**:
1. Prompts for key decision/pattern discovered
2. Categorizes (architecture, bug, workflow, tool, decision)
3. Creates structured knowledge bead in gastown beads
4. Updates relevant index/manifest
5. Can trigger notification to relevant crew

**Variables**:
- `topic` (required): What was learned
- `category` (required): architecture | bug | workflow | tool | decision
- `context` (optional): Where discovered
- `tags` (optional): Additional categorization

---

## Proposed Formula 3: `mol-incident-response`

**Purpose**: Structured incident response for system failures

**Why needed**:
- No formula for handling outages or critical issues
- Escalation exists but no follow-through workflow
- Need consistent incident lifecycle

**What it does**:
1. Creates incident bead with severity
2. Runs diagnostic molecule (mol-dog-doctor equivalent)
3. Notifies relevant crew/rig
4. Tracks response timeline
5. Generates post-mortem template on resolution
6. Files learnings as knowledge bead

**Variables**:
- `severity` (required): critical | high | medium
- `system` (required): Which system affected
- `symptoms` (required): Observed symptoms
- `investigators` (optional): Who to involve
- `oncall` (optional): Override oncall rotation

---

## Alternatives Considered

1. **Testing/QA automation** - Could add but each repo has different test setups
2. **Cross-rig dependency graph** - Too complex, depends on bead metadata
3. **Agent performance metrics** - Interesting but requires instrumentation first

---

## Recommendation

Implement in order: `mol-code-review` → `mol-knowledge-capture` → `mol-incendient-response`

`mol-code-review` is most immediately useful for the overseer's PR review workflow.