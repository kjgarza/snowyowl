# SnowyOwl GSD Integration

## What This Is

A dual-mode automation system that executes software development work overnight. TASKS mode (existing) processes markdown task lists using AI backends. GSD mode (new) integrates with the Get Shit Done workflow framework, detecting ready implementation phases across multiple repositories and executing them autonomously in isolated worktrees.

## Core Value

Enable parallelized overnight execution of planned GSD phases so that extensive daytime planning translates directly into shipped code by morning, without manual intervention.

## Requirements

### Validated

<!-- Existing SnowyOwl TASKS mode functionality -->

- ✓ Repository scanning and discovery — existing
- ✓ Git worktree isolation for safe parallel execution — existing
- ✓ AI backend routing (GitHub Copilot CLI, Claude Code CLI) — existing
- ✓ Pull request creation workflow — existing
- ✓ Hierarchical task processing — existing
- ✓ Conventional commit generation — existing
- ✓ Dry-run mode for testing — existing
- ✓ Comprehensive logging infrastructure — existing

### Active

<!-- GSD mode requirements -->

- [ ] **GSD-01**: Mode selection via environment variable (SNOWYOWL_MODE)
- [ ] **GSD-02**: Scan directory for repos with `.planning/` directories
- [ ] **GSD-03**: Detect GSD-ready phases using file system signals (PLAN.md exists, no SUMMARY.md, yolo mode)
- [ ] **GSD-04**: Execute ready phases via `/gsd:execute-phase N` command
- [ ] **GSD-05**: Create worktrees for GSD phase execution
- [ ] **GSD-06**: Create PRs with GSD SUMMARY.md content in PR body
- [ ] **GSD-07**: Respect sequential phase ordering (phase N+1 only after phase N complete)
- [ ] **GSD-08**: Skip interactive GSD commands (verify-work, discuss-phase, plan-phase)

### Out of Scope

- Resume/pause handling — defer to future iteration after MVP validation
- Parallel phase execution within single repo — sequential execution simpler and safer
- Interactive verification in headless mode — verification remains human task
- GSD roadmap or requirements generation — SnowyOwl only executes pre-planned work
- Replacing TASKS mode — both modes coexist indefinitely

## Context

**Existing SnowyOwl Architecture:**
- Bash-based modular system with lib/ directory containing config.sh, git_utils.sh, ai_backends.sh, task_processing.sh
- Main entry point: run_copilot_automation.sh
- Uses LLM CLI for intelligent task parsing
- Worktree pattern: create isolated workspace → execute → commit → push → PR → cleanup
- Fail-fast on prerequisites, graceful fallback for optional features
- Comprehensive logging to logs/ directory

**GSD Workflow Context:**
- GSD is a structured software development framework with planning artifacts in `.planning/`
- Readiness determined by file system state, not AI analysis
- Phase execution is delegated to `/gsd:execute-phase` which handles planning, subagents, commits
- Config must be in "yolo" mode (`.planning/config.json`) for headless execution
- Human workflow: plan during day → SnowyOwl executes overnight → human verifies in morning

**Integration Strategy:**
- Add GSD mode alongside existing TASKS mode (not replacement)
- Reuse existing worktree management and PR creation infrastructure
- Add new gsd_scanner.sh module for readiness detection
- Add new run_gsd_automation.sh entry point for GSD mode
- Extend config.env with GSD-specific settings (GSD_ROOT, SNOWYOWL_MODE)

## Constraints

- **Tech stack**: Bash 5.0+, must integrate with existing SnowyOwl architecture — Maintain compatibility with existing TASKS mode
- **Execution environment**: GSD requires Claude Code CLI with `/gsd:*` skills available — SnowyOwl must verify GSD prerequisites separately from TASKS mode
- **Mode isolation**: TASKS and GSD modes use different scanning logic — Environment variable switch must be clean
- **Sequential execution**: GSD phases have dependencies — Must respect phase ordering within each repo
- **Performance**: File system scanning only, no Claude invocations for readiness detection — Keep startup cost low

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Dual-mode system (TASKS + GSD) rather than replacement | Existing TASKS mode is functional and used; GSD serves different workflow; both have value | — Pending |
| Environment variable mode switching | Simplest switching mechanism; aligns with existing config.env pattern; no config file changes needed | — Pending |
| Reuse existing worktree and PR infrastructure | DRY principle; worktree isolation pattern identical; avoids duplicating tested code | — Pending |
| Delegate to `/gsd:execute-phase` rather than custom prompts | GSD commands encapsulate complex orchestration (subagents, waves, state); reimplementing would duplicate logic and miss updates | — Pending |
| File system scanning for readiness (no Claude) | Readiness is deterministic based on file presence; scanning hundreds of repos with Claude would be slow and expensive | — Pending |
| Skip verification in headless mode | `/gsd:verify-work` is inherently interactive; user acceptance testing requires human; better to defer to morning PR review | — Pending |

---
*Last updated: 2026-02-01 after initialization*
