# Roadmap: SnowyOwl GSD Integration

## Overview

Transform SnowyOwl from a task-based automation system into a dual-mode framework that executes both markdown tasks (TASKS mode) and planned GSD phases (GSD mode) overnight. The journey moves from establishing shared infrastructure and mode switching, through hardened worktree management, to full GSD scanner/executor integration with automated PR creation.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [ ] **Phase 1: Foundation & Mode Management** - Shared utilities, mode detection, logging infrastructure
- [ ] **Phase 2: Worktree Infrastructure** - Hardened worktree management for unattended execution
- [ ] **Phase 3: GSD Scanner & Executor** - Readiness detection and phase execution via Claude CLI
- [ ] **Phase 4: Integration & PR Creation** - Wire components together, automated PR generation with SUMMARY.md

## Phase Details

### Phase 1: Foundation & Mode Management
**Goal**: SnowyOwl can detect execution mode and route to appropriate automation workflow with comprehensive logging
**Depends on**: Nothing (first phase)
**Requirements**: MODE-01, MODE-02, MODE-03, MODE-04, LOG-01, LOG-02, LOG-03
**Success Criteria** (what must be TRUE):
  1. User can run SnowyOwl with SNOWYOWL_MODE=gsd and it selects GSD workflow
  2. User can run SnowyOwl with SNOWYOWL_MODE=tasks and it selects TASKS workflow
  3. System falls back to appropriate mode when environment variable not set (file presence detection)
  4. Dry-run mode tests readiness detection without executing phases
  5. GSD events logged to dedicated log files with timestamps and exit codes
**Plans:** 1 plan

Plans:
- [ ] 01-01-PLAN.md — Mode detection, GSD logging, and dry-run infrastructure in lib/config.sh

### Phase 2: Worktree Infrastructure
**Goal**: Git worktrees can be safely created, used, and cleaned up even under error/timeout conditions
**Depends on**: Phase 1
**Requirements**: WORK-01, WORK-02, WORK-03, WORK-04
**Success Criteria** (what must be TRUE):
  1. Worktree creation reuses existing git_utils.sh infrastructure
  2. Branch names include timestamps to prevent same-branch-checkout conflicts
  3. Worktrees removed via cleanup traps even when script interrupted or errors
  4. Stale worktree references pruned after cleanup completes
**Plans**: TBD

Plans:
- [ ] 02-01: TBD during phase planning

### Phase 3: GSD Scanner & Executor
**Goal**: SnowyOwl can discover GSD-ready phases and execute them via Claude Code CLI in unattended mode
**Depends on**: Phase 2
**Requirements**: READY-01, READY-02, READY-03, READY-04, READY-05, EXEC-01, EXEC-02, EXEC-03, EXEC-04, EXEC-05
**Success Criteria** (what must be TRUE):
  1. Scanner finds all repos with .planning/ directories in configured root
  2. Scanner identifies phases with PLAN.md but no SUMMARY.md as ready
  3. Scanner validates .planning/config.json mode is "yolo" before marking ready
  4. Sequential ordering enforced (phase N+1 only executes after N complete)
  5. Phase executor calls /gsd:execute-phase N via Claude Code CLI headless mode
  6. Executor skips interactive commands (verify-work, discuss-phase, plan-phase)
  7. Execution compatible with unattended schedulers (launchd, cron)
  8. Timeout triggers graceful state save via /gsd:pause-work
  9. System checks for .continue-here marker and resumes via /gsd:resume-work
  10. Phase chaining automatically advances to next ready phase after completion
**Plans**: TBD

Plans:
- [ ] 03-01: TBD during phase planning

### Phase 4: Integration & PR Creation
**Goal**: Complete GSD mode workflow from scanning to PR creation with SUMMARY.md content
**Depends on**: Phase 3
**Requirements**: PR-01, PR-02, PR-03
**Success Criteria** (what must be TRUE):
  1. PR body includes SUMMARY.md content from executed phases
  2. PR creation reuses existing gh CLI infrastructure from TASKS mode
  3. Multi-phase execution creates single PR with all phase summaries concatenated
  4. End-to-end workflow runs from run_gsd_automation.sh entry point
**Plans**: TBD

Plans:
- [ ] 04-01: TBD during phase planning

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Foundation & Mode Management | 0/1 | Planned | - |
| 2. Worktree Infrastructure | 0/TBD | Not started | - |
| 3. GSD Scanner & Executor | 0/TBD | Not started | - |
| 4. Integration & PR Creation | 0/TBD | Not started | - |
