# Branching Strategy

This document describes the TDD workflow for the gasclaw-management repository.

## Branches

| Branch | Purpose | Protection |
|--------|---------|------------|
| `main` | Production-ready code | Requires 1 PR review, no direct pushes |
| `dev` | Development integration | Protected, PRs from feature branches |
| `feature/*` | New features | Temporary, squash-merged to dev |
| `fix/*` | Bug fixes | Temporary, squash-merged to dev |

## Workflow

### 1. Start a new feature/fix
```bash
git checkout dev
git pull origin dev
git checkout -b feature/my-feature
```

### 2. Develop with TDD
- Write tests first
- Implement code
- Run tests locally before pushing

### 3. Create PR to dev
```bash
git push -u origin feature/my-feature
# Create PR via GitHub UI or gh CLI
```

### 4. CI Pipeline (tdd.yml)
The TDD pipeline runs on every push and PR:
- **Linting**: ruff check on `src/`
- **Unit tests**: pytest on `tests/unit/`
- **Integration tests**: Telegram bot tests (PR only)

### 5. Merge to main
Once CI passes and review is approved:
- Squash merge feature branch to dev
- Create PR from dev to main
- After main PR approval, merge

## Rules

1. **Never push directly to main** - branch protection enforced
2. **Always branch from dev** - start from latest dev
3. **Keep PRs small** - easier to review
4. **Tests must pass** - CI must be green before merge
5. **Require review** - at least 1 approval for main

## Quick Commands

```bash
# Start new feature
git checkout dev && git pull && git checkout -b feature/name

# Sync with dev
git fetch origin && git rebase origin/dev

# Create PR
gh pr create --base dev --head feature/name --title "Feature: name"
```