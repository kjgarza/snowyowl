# Requirements: SnowyOwl GSD Integration

**Defined:** 2026-02-01
**Core Value:** Enable parallelized overnight execution of planned GSD phases so that extensive daytime planning translates directly into shipped code by morning, without manual intervention.

## v1 Requirements

Requirements for initial release. Each maps to roadmap phases.

### Mode Management

- [ ] **MODE-01**: System detects execution mode via SNOWYOWL_MODE environment variable
- [ ] **MODE-02**: File presence detection determines fallback mode (.planning/ = GSD, TASKS.md = TASKS)
- [ ] **MODE-03**: GSD and TASKS modes operate independently without interference
- [ ] **MODE-04**: Dry-run mode tests readiness detection without executing phases

### Readiness Detection

- [ ] **READY-01**: File system scanner finds repos with .planning/ directories
- [ ] **READY-02**: Readiness logic identifies phases with PLAN.md but no SUMMARY.md
- [ ] **READY-03**: Scanner validates .planning/config.json mode is "yolo"
- [ ] **READY-04**: Sequential ordering enforces phase N+1 only executes after phase N complete
- [ ] **READY-05**: Phase chaining automatically advances to next ready phase after completion

### Phase Execution

- [ ] **EXEC-01**: Phase executor calls /gsd:execute-phase N via Claude Code CLI
- [ ] **EXEC-02**: Executor skips interactive GSD commands (verify-work, discuss-phase, plan-phase)
- [ ] **EXEC-03**: Execution compatible with unattended schedulers (launchd, cron)
- [ ] **EXEC-04**: Graceful failure saves state via /gsd:pause-work on timeout
- [ ] **EXEC-05**: Resume handler checks for .continue-here marker and calls /gsd:resume-work

### Worktree Management

- [ ] **WORK-01**: Worktree creation uses existing git_utils.sh infrastructure
- [ ] **WORK-02**: Unique branch names prevent same-branch-checkout conflicts
- [ ] **WORK-03**: Cleanup traps ensure worktree removal even on error/interrupt
- [ ] **WORK-04**: Worktree pruning removes stale references after cleanup

### Pull Request Creation

- [ ] **PR-01**: PR body includes SUMMARY.md content from executed phases
- [ ] **PR-02**: PR creation reuses existing gh CLI infrastructure
- [ ] **PR-03**: Multi-phase execution creates single PR with all phase summaries

### Logging & Observability

- [ ] **LOG-01**: GSD events logged to dedicated log files
- [ ] **LOG-02**: Phase execution logs include timing and exit codes
- [ ] **LOG-03**: Readiness scanning logs phase discovery and validation results

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### Performance Optimization

- **PERF-01**: Parallel repo execution with bounded concurrency (GSD_MAX_PARALLEL)
- **PERF-02**: Phase limit safety valve prevents runaway execution (GSD_MAX_PHASES_PER_REPO)
- **PERF-03**: File locking prevents race conditions in parallel execution

### Enhanced Robustness

- **ROBUST-01**: Per-repo failure isolation (one repo's failure doesn't stop others)
- **ROBUST-02**: Configurable timeout values per phase complexity
- **ROBUST-03**: Retry logic for transient Claude CLI failures

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| Parallel phase execution within single repo | Violates GSD sequential dependency model; complex to implement safely |
| AI-based readiness detection | Slow and expensive compared to file system signals; non-deterministic |
| Automatic verification via /gsd:verify-work | Verification is interactive and requires human judgment |
| Auto-merge PRs on success | Removes human quality gate; SnowyOwl delivers for review, not deployment |
| Mode switching within single run | Complexity without clear benefit; user selects mode at invocation |
| Real-time progress streaming | Overnight runs don't need live updates; logs sufficient |
| GSD roadmap generation | SnowyOwl only executes pre-planned work; planning remains human task |
| Custom phase selection | Sequential execution is core model; manual phase cherry-picking defeats automation |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| MODE-01 | Phase 1 | Pending |
| MODE-02 | Phase 1 | Pending |
| MODE-03 | Phase 1 | Pending |
| MODE-04 | Phase 1 | Pending |
| LOG-01 | Phase 1 | Pending |
| LOG-02 | Phase 1 | Pending |
| LOG-03 | Phase 1 | Pending |
| WORK-01 | Phase 2 | Pending |
| WORK-02 | Phase 2 | Pending |
| WORK-03 | Phase 2 | Pending |
| WORK-04 | Phase 2 | Pending |
| READY-01 | Phase 3 | Pending |
| READY-02 | Phase 3 | Pending |
| READY-03 | Phase 3 | Pending |
| READY-04 | Phase 3 | Pending |
| READY-05 | Phase 3 | Pending |
| EXEC-01 | Phase 3 | Pending |
| EXEC-02 | Phase 3 | Pending |
| EXEC-03 | Phase 3 | Pending |
| EXEC-04 | Phase 3 | Pending |
| EXEC-05 | Phase 3 | Pending |
| PR-01 | Phase 4 | Pending |
| PR-02 | Phase 4 | Pending |
| PR-03 | Phase 4 | Pending |

**Coverage:**
- v1 requirements: 24 total
- Mapped to phases: 24 (100%)
- Unmapped: 0

---
*Requirements defined: 2026-02-01*
*Last updated: 2026-02-01 after roadmap creation*
