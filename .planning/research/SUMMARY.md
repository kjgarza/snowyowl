# Project Research Summary

**Project:** SnowyOwl GSD Mode Integration
**Domain:** Bash automation systems with CLI integration for phase-based workflows
**Researched:** 2026-02-01
**Confidence:** HIGH

## Executive Summary

SnowyOwl is a dual-mode automation system that orchestrates AI-powered code changes. It currently supports TASKS mode (simple task execution) and needs GSD mode integration for overnight execution of planned development phases. The research shows that GSD mode should use file-system-based readiness detection (scanning `.planning/` directories for PLAN.md files without SUMMARY.md) rather than AI-powered scanning, enabling fast, deterministic overnight automation without expensive LLM invocations during readiness checks.

The recommended approach follows a modular bash architecture with separate entry points for each mode (`run_gsd_automation.sh` distinct from `run_copilot_automation.sh`), reusing existing battle-tested infrastructure for worktree management, git operations, and PR creation. The core stack remains bash 5.0+ with git worktrees for isolation, Claude Code CLI for phase execution, and GitHub CLI for PR creation. This architecture enables the "lights-out" overnight execution model where SnowyOwl autonomously executes planned phases and creates PRs for morning review.

Critical risks center on worktree management (stale references from manual deletion), parallel execution race conditions (concurrent git operations without file locking), and graceful failure handling (saving state on timeout for resumption). Prevention requires strict use of `git worktree remove` with pruning, `flock`-based locking for parallel execution, and integration with GSD's `/gsd:pause-work` and `/gsd:resume-work` commands for timeout recovery. The recommended phase structure prioritizes foundation (shared utilities extraction) before mode-specific features, ensuring robust infrastructure before complexity.

## Key Findings

### Recommended Stack

The research confirms bash-based automation is the right choice for SnowyOwl's use case. Bash 5.0+ provides native support for git worktree orchestration, process control, and CLI tool integration without introducing language runtime dependencies. Git worktrees (2.5+) deliver filesystem-level isolation for parallel task execution without repository cloning overhead. ShellCheck (0.10.0+) provides static analysis to catch common pitfalls and enforce best practices.

**Core technologies:**
- **Bash 5.0+**: Core automation scripting — industry standard for Unix automation with strong support for process control, file operations, and tool orchestration
- **Git Worktrees 2.5+**: Isolated execution environments — provides filesystem-level isolation for parallel task execution without repository cloning overhead
- **Claude Code CLI (Latest)**: AI-powered phase execution — supports headless mode via `-p` flag with `--dangerously-skip-permissions` for non-interactive automation
- **GitHub CLI 2.40+**: PR creation and GitHub operations — provides authenticated GitHub API access without manual token management
- **ShellCheck 0.10.0+**: Static analysis — catches 80% of common bash bugs and enforces style consistency

**Supporting tools:**
- **jq**: JSON parsing for `.planning/config.json` mode detection and validation
- **ripgrep (optional)**: Fast file content searching (10-100x faster than grep for large codebases)
- **flock**: File locking for parallel execution safety

**Key architectural decision:** Use bash globbing with `nullglob` for `.planning/` directory scanning instead of `find` or external tools. This provides zero-subprocess overhead for readiness detection while remaining deterministic and fast.

### Expected Features

SnowyOwl GSD mode needs a specific feature set focused on unattended overnight execution. Research into RPA systems, CI/CD platforms, and autonomous manufacturing reveals that the "lights-out" automation model requires specific capabilities around mode isolation, readiness detection, and graceful failure handling.

**Must have (table stakes - MVP v1):**
- **Mode switching** — Environment-based mode detection (TASKS vs GSD) using file presence
- **Readiness detection** — File system scanning for PLAN.md without SUMMARY.md (no AI invocation needed)
- **Sequential phase ordering** — Phase N+1 only executes after phase N completes (dependency enforcement)
- **Skip interactive commands** — Only run autonomous GSD commands (`/gsd:execute-phase`, `/gsd:resume-work`, `/gsd:pause-work`)
- **Unattended execution** — Run via launchd/cron without human oversight for overnight automation
- **PR creation** — Reuse existing worktree + PR infrastructure for delivery mechanism
- **Comprehensive logging** — Extend existing logs with GSD events for debugging overnight runs
- **Yolo mode enforcement** — Skip repos not in "yolo" mode to prevent interactive prompts
- **Graceful failure** — Save state on timeout via `/gsd:pause-work` for data loss prevention

**Should have (competitive - v1.x post-validation):**
- **Phase chaining** — Automatically advance to next ready phase after completion (efficiency improvement)
- **Resume interrupted sessions** — Check for `.continue-here` marker and call `/gsd:resume-work` (robustness)
- **Parallel repo execution** — Run multiple repos concurrently with bounded parallelism (throughput)
- **Phase limit safety valve** — `GSD_MAX_PHASES_PER_REPO` config to prevent runaway execution
- **Dry-run for GSD mode** — Test readiness detection without execution (testing tool)

**Defer (v2+ anti-features):**
- **Parallel phase execution** — Run independent phases simultaneously (complex dependency analysis, violates GSD sequential model)
- **AI-based readiness detection** — Use Claude to analyze phase readiness (slow, expensive, non-deterministic vs file system signals)
- **Automatic verification** — Run `/gsd:verify-work` overnight (verification is interactive, requires human judgment)
- **Auto-merge on success** — Merge PR if verification passes (removes human quality gate)

### Architecture Approach

The recommended architecture uses **multiple entry points** (separate scripts per mode) rather than a dispatcher pattern. This keeps each mode's orchestration logic clean and independently evolvable. The existing SnowyOwl codebase already follows this pattern with `run_copilot_automation.sh`, so GSD mode adds `run_gsd_automation.sh` alongside it.

**Major components:**

1. **Entry Point Scripts (run_*.sh)** — Mode-specific orchestration and argument parsing. Each mode has distinct workflows (scan repos vs parse tasks), so dedicated entry scripts keep orchestration clean and testable.

2. **Shared Libraries (lib/config.sh, lib/git_utils.sh, lib/ai_backends.sh)** — Cross-mode utilities sourced by multiple entry points. Common operations (logging, git, AI backends) factored into reusable modules prevent duplication and ensure consistency.

3. **Mode-Specific Libraries (lib/gsd_scanner.sh, lib/gsd_runner.sh, lib/gsd_pr.sh)** — Mode-unique logic stays isolated to prevent feature entanglement. Use namespace prefix (`gsd_*`) to indicate module ownership and prevent naming collisions.

4. **External Tools (git, gh, claude, jq)** — CLI tools for actual work, with fail-fast prerequisite checking before main workflow execution.

**Key patterns:**
- **Source-based module loading** — Use `source` to include libraries at script top, with guard variables to prevent double-sourcing
- **Fail-fast prerequisite checking** — Validate all external dependencies (git, gh, claude, jq) before starting workflow
- **Defensive scripting** — Always use `set -euo pipefail` for early error detection
- **Cleanup with trap** — Guarantee worktree cleanup even on error/interrupt using `trap cleanup EXIT ERR`

**Data flow for GSD mode:**
1. User runs script (or cron job)
2. Parse args, validate prerequisites (git, gh, claude, jq)
3. Scan for repos with `.planning/` directories
4. For each repo: validate config (mode=yolo), check readiness (PLAN.md exists, no SUMMARY.md)
5. If ready: create worktree, execute phases sequentially, push & create PR
6. Cleanup: remove worktree with pruning

### Critical Pitfalls

Research into bash automation and git worktree management reveals specific failure modes that must be addressed during implementation.

1. **Worktree reference leaks from manual deletion** — Using `rm -rf` on worktree directories instead of `git worktree remove` leaves stale references in `.git/worktrees/`, causing "already exists" errors. Always use `git worktree remove --force` followed by `git worktree prune`. Implement cleanup in trap handlers to ensure it runs even on script failure.

2. **Same branch checkout across multiple worktrees** — Attempting to checkout the same branch in multiple worktrees fails with "already checked out" errors. Always create unique branch names with timestamps (`snowyowl-gsd-$(date +%Y%m%d-%H%M%S)-$$`). Check if branch exists before creating worktree using `git show-ref --verify refs/heads/<branch>`.

3. **Race conditions in parallel execution without file locking** — When running multiple repository automations in parallel (`GSD_MAX_PARALLEL=2`), concurrent access to shared resources causes data corruption or failed operations. Use `flock` for critical sections accessing shared resources, with non-blocking locks (`flock -n`) to fail fast on conflicts.

4. **Unvalidated JSON parsing leading to silent failures** — Malformed `.planning/config.json` may cause `jq` to return empty strings or `null`, which bash interprets as success. Always check `jq` exit codes (`jq ... || return 1`), validate required fields exist, and explicitly check for expected values (`[ "$mode" = "yolo" ] || return 1`).

5. **Missing exit code checks for CLI command failures** — Claude CLI commands may fail without triggering script termination if `set -e` isn't used or commands are in pipelines. Always use `set -euo pipefail`, explicitly check exit codes for critical operations (`if ! claude -p ...; then`), and distinguish between timeout (resumable via `/gsd:pause-work`) vs hard failure (abort).

6. **File system scanning performance on large repositories** — Scanning deeply nested repository structures without optimization causes slowdowns. Use `find` with `-maxdepth` to limit recursion, prefer bash globbing over spawning subshells in loops, and cache results of expensive operations.

## Implications for Roadmap

Based on research, the recommended phase structure prioritizes **foundation before features** and **shared infrastructure before mode-specific complexity**. This approach ensures robust utilities are in place before tackling GSD-specific scanning and execution logic.

### Phase 1: Foundation & Shared Utilities
**Rationale:** Extract and harden shared utilities before building mode-specific features. The existing codebase has config.sh, git_utils.sh, and ai_backends.sh, but they need to be fully shared (currently some TASKS-mode assumptions exist). Building GSD on solid foundation prevents rework.

**Delivers:**
- Verified shared library structure (config.sh, git_utils.sh, ai_backends.sh are mode-agnostic)
- Enhanced error handling (`set -euo pipefail`, trap handlers)
- Prerequisite checking pattern extracted for reuse
- Logging infrastructure supports multiple modes

**Addresses:**
- Mode isolation (FEATURES.md table stakes)
- Defensive scripting pattern (STACK.md error handling)
- Shared infrastructure reuse (ARCHITECTURE.md component boundaries)

**Avoids:**
- Global state mutation without clear ownership (PITFALLS.md anti-pattern 3)
- Sourcing mode-specific modules in shared modules (PITFALLS.md anti-pattern 2)

**Research flag:** Skip research — Standard bash patterns with established best practices.

---

### Phase 2: Worktree Management Hardening
**Rationale:** GSD mode will create/destroy worktrees during overnight runs. The existing worktree utilities work but lack critical features needed for unattended execution: cleanup in trap handlers, automatic pruning, and branch conflict detection. Must be bulletproof before GSD uses it.

**Delivers:**
- `git worktree remove --force` always followed by `git worktree prune`
- Cleanup trap handlers ensure worktrees removed even on error/interrupt
- Branch uniqueness validation before worktree creation
- Worktree-specific logging for debugging

**Addresses:**
- Graceful failure handling (FEATURES.md table stakes)
- Comprehensive logging (FEATURES.md table stakes)

**Avoids:**
- Worktree reference leaks (PITFALLS.md critical #1)
- Same branch checkout conflicts (PITFALLS.md critical #2)

**Research flag:** Skip research — Git worktree patterns well-documented, existing code provides foundation.

---

### Phase 3: GSD Scanner (Readiness Detection)
**Rationale:** This is the core differentiator of GSD mode. Must be fast (no LLM invocations), deterministic (file-system based), and accurate (correctly identifies ready phases). Sequential ordering depends on scanner accuracy.

**Delivers:**
- File system scanning for `.planning/` directories
- Readiness logic: PLAN.md exists AND no SUMMARY.md AND previous phase complete
- Yolo mode validation via `jq` parsing of `.planning/config.json`
- Robust JSON validation with error checking
- Performance optimization (bash globbing, `-maxdepth` limits)

**Uses:**
- Bash globbing with `nullglob` (STACK.md file system scanning strategy)
- jq for JSON parsing with exit code checks (STACK.md CLI integration)

**Addresses:**
- Readiness detection (FEATURES.md table stakes)
- Yolo mode enforcement (FEATURES.md table stakes)
- Sequential phase ordering foundation (FEATURES.md table stakes)

**Avoids:**
- Unvalidated JSON parsing (PITFALLS.md critical #4)
- File system performance traps (PITFALLS.md critical #6)

**Research flag:** Skip research — File system patterns established, existing plan provides specification.

---

### Phase 4: GSD Runner (Phase Execution)
**Rationale:** Phase execution is the most complex component. Must integrate with Claude Code CLI's headless mode, handle timeouts gracefully via `/gsd:pause-work`, and validate execution success by checking for SUMMARY.md.

**Delivers:**
- Claude Code CLI integration with `-p` flag and `--dangerously-skip-permissions`
- Exit code checking for all commands
- Timeout detection and state saving via `/gsd:pause-work`
- SUMMARY.md validation after execution
- Execution logging to phase-specific log files

**Uses:**
- Claude Code CLI headless mode (STACK.md CLI integration patterns)
- Error handling with trap (STACK.md defensive scripting)

**Addresses:**
- Unattended execution (FEATURES.md table stakes)
- Graceful failure handling (FEATURES.md table stakes)
- Skip interactive commands (FEATURES.md table stakes)

**Avoids:**
- Missing exit code checks (PITFALLS.md critical #5)
- Silent failures during overnight runs (PITFALLS.md UX pitfall)

**Research flag:** **NEEDS RESEARCH** — Claude Code CLI headless mode flags, timeout handling specifics, integration with GSD command error codes require validation.

---

### Phase 5: GSD PR Generation
**Rationale:** PR creation already exists for TASKS mode, but GSD requires extracting SUMMARY.md content from completed phases and formatting it into PR body. Must handle multiple phases completed in single run.

**Delivers:**
- Extract SUMMARY.md files from completed phases
- Format PR body with phase summaries and metadata
- Reuse existing `gh pr create` infrastructure
- Handle multi-phase execution (all summaries in one PR)

**Uses:**
- Existing git_utils.sh PR creation pattern (ARCHITECTURE.md shared infrastructure)
- GitHub CLI (STACK.md CLI integration)

**Addresses:**
- PR creation (FEATURES.md table stakes)
- Shared infrastructure reuse (ARCHITECTURE.md component boundaries)

**Avoids:**
- Code duplication between modes (ARCHITECTURE.md anti-pattern 1)

**Research flag:** Skip research — Extends existing PR creation pattern with file parsing.

---

### Phase 6: Phase Chaining & Sequential Advancement
**Rationale:** After executing one phase, scanner must re-run to detect if next phase is now ready. This enables "automatic phase chaining" where multiple planned phases execute overnight sequentially.

**Delivers:**
- Re-scan after each phase completion
- Advance to next ready phase automatically
- Stop when next phase needs human input (no PLAN.md or mode != yolo)
- Safety limit: `GSD_MAX_PHASES_PER_REPO` to prevent runaway execution

**Addresses:**
- Sequential phase ordering (FEATURES.md table stakes)
- Phase chaining (FEATURES.md differentiator)
- Phase limit safety valve (FEATURES.md differentiator)

**Avoids:**
- Runaway execution (FEATURES.md anti-feature concern)

**Research flag:** Skip research — Builds on established scanner patterns from Phase 3.

---

### Phase 7: Entry Point & Integration
**Rationale:** Wire all components together into `run_gsd_automation.sh`. This is where mode switching, orchestration, and end-to-end workflow come together.

**Delivers:**
- `run_gsd_automation.sh` entry point with argument parsing
- Mode detection via file presence (`.planning/` exists = GSD mode)
- Orchestration: scan → execute → PR creation → cleanup
- Dry-run mode support
- Summary report generation

**Addresses:**
- Mode switching (FEATURES.md table stakes)
- Dry-run mode (FEATURES.md v1.x feature)
- Comprehensive logging (FEATURES.md table stakes)

**Avoids:**
- Complex mode switching logic (ARCHITECTURE.md anti-pattern 1)

**Research flag:** Skip research — Orchestration pattern follows existing run_copilot_automation.sh.

---

### Phase 8: Parallel Repo Execution (Post-MVP)
**Rationale:** Once sequential execution proven, add bounded parallelism across repositories (not phases). This is complex due to locking requirements and output interleaving, so defer until core functionality validated.

**Delivers:**
- Background job spawning with `GSD_MAX_PARALLEL` limit
- `flock`-based locking for shared resources
- Per-repository log files to prevent interleaving
- Job control and cleanup coordination

**Addresses:**
- Parallel repo execution (FEATURES.md differentiator)
- Phase limit safety valve (FEATURES.md differentiator)

**Avoids:**
- Race conditions (PITFALLS.md critical #3)
- Lock file deadlocks (PITFALLS.md performance trap)

**Research flag:** **NEEDS RESEARCH** — File locking patterns, background job management, and cleanup coordination with parallel execution need validation.

---

### Phase 9: Resume Interrupted Sessions (Post-MVP)
**Rationale:** Final robustness feature. Check for `.continue-here` marker files and automatically resume via `/gsd:resume-work` before executing phases. Deferred to late phase because it requires Phase 4 (runner) working first.

**Delivers:**
- `.continue-here` marker detection
- Automatic `/gsd:resume-work` invocation before phase execution
- Resume logging and error handling

**Addresses:**
- Resume interrupted sessions (FEATURES.md differentiator)

**Avoids:**
- Data loss from timeouts (PITFALLS.md critical #5)

**Research flag:** Skip research — GSD resume commands already documented.

---

### Phase Ordering Rationale

The phase structure follows **dependency ordering** and **risk mitigation**:

1. **Foundation first (Phase 1-2):** Extract shared utilities and harden worktree management before building GSD-specific features. This prevents rework and ensures robust infrastructure.

2. **Core GSD features sequentially (Phase 3-5):** Scanner → Runner → PR generation follows the actual execution flow and allows incremental testing. Each phase produces a testable artifact.

3. **Enhancement features after core (Phase 6-9):** Phase chaining, parallel execution, and resume logic build on proven core functionality. These are complex features that benefit from stable foundation.

4. **Research phases early:** Phase 4 (Runner) flagged for research because Claude CLI headless mode integration needs validation. Phase 8 (Parallel Execution) flagged because file locking patterns need investigation. Both researched before implementation to avoid rework.

### Research Flags

**Phases needing deeper research during planning:**

- **Phase 4 (GSD Runner):** Claude Code CLI headless mode flags (`--dangerously-skip-permissions`, `--max-turns`), timeout handling specifics, error code interpretation for distinguishing timeout vs failure, integration testing approach for AI CLI tools.

- **Phase 8 (Parallel Repo Execution):** File locking best practices with `flock`, non-blocking lock patterns, background job management in bash, cleanup coordination with multiple processes, log file handling to prevent interleaving.

**Phases with standard patterns (skip research-phase):**

- **Phase 1 (Foundation):** Standard bash library extraction and modularization patterns.
- **Phase 2 (Worktree Management):** Git worktree API well-documented, existing code provides foundation.
- **Phase 3 (GSD Scanner):** File system scanning patterns established in STACK.md.
- **Phase 5 (PR Generation):** Extends existing pattern, no new concepts.
- **Phase 6 (Phase Chaining):** Builds on established scanner patterns.
- **Phase 7 (Entry Point):** Follows existing orchestration pattern from TASKS mode.
- **Phase 9 (Resume Sessions):** GSD resume commands already specified.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Official documentation for Claude CLI, gh CLI, git worktrees. Multiple cross-referenced sources for bash patterns. ShellCheck widely adopted. |
| Features | HIGH | Feature landscape derived from RPA systems, CI/CD platforms, and autonomous manufacturing patterns. Anti-features validated against common mistakes. |
| Architecture | HIGH | Modular bash architecture patterns from Google Shell Style Guide and expert blogs. Existing SnowyOwl codebase provides validation of approach. |
| Pitfalls | HIGH | Git worktree gotchas well-documented in multiple sources. Bash error handling patterns canonical. File locking and race condition patterns cross-referenced. |

**Overall confidence:** HIGH

All research areas have multiple high-quality sources. Stack recommendations come from official documentation (Claude CLI, GitHub CLI, git) and established style guides (Google Shell Style Guide). Feature landscape validated against industry patterns (RPA, CI/CD, manufacturing automation). Architecture patterns cross-referenced across multiple expert blogs and confirmed against existing SnowyOwl codebase. Pitfalls derived from canonical sources (BashPitfalls wiki, git worktree guides) and project-specific analysis.

### Gaps to Address

Minor gaps requiring validation during implementation:

- **Claude Code CLI timeout behavior:** Research shows CLI supports timeouts via system limits, but specific exit codes for timeout vs failure need validation during Phase 4 implementation. Can test empirically with timeout command wrapper.

- **GSD command error codes:** Documentation shows `/gsd:pause-work` and `/gsd:resume-work` commands exist, but error code semantics (when to retry vs abort) need validation during Phase 4. Can test against sample phases.

- **Parallel execution scaling:** Research shows `flock` patterns, but optimal `GSD_MAX_PARALLEL` value and resource limits need empirical testing during Phase 8. Start with `GSD_MAX_PARALLEL=2`, tune based on observation.

- **File system performance at scale:** Research shows bash globbing is fast, but actual performance on repositories with >50 phases needs benchmark during Phase 3. If slow, fall back to `find` with `-maxdepth`.

These are all **validation gaps** (need empirical testing) rather than **knowledge gaps** (missing information). The research provides clear approaches for handling each during implementation.

## Sources

### Primary (HIGH confidence)

**Official Documentation:**
- [Claude Code CLI Documentation](https://code.claude.com/docs/en/cli-reference) — Headless mode flags, authentication, output formats
- [GitHub Copilot CLI Changelog (Jan 2026)](https://github.blog/changelog/2026-01-14-github-copilot-cli-enhanced-agents-context-management-and-new-ways-to-install/) — Programmatic mode, tool filtering
- [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html) — Naming conventions, structure, best practices
- [ShellCheck Official Site](https://www.shellcheck.net/) — Static analysis capabilities
- [Bash 5.0 Release Notes](https://lwn.net/Articles/776223/) — New features, compatibility

**Canonical References:**
- [BashPitfalls (Greg's Wiki)](https://mywiki.wooledge.org/BashPitfalls) — Anti-patterns reference
- [Git Worktree Documentation](https://git-scm.com/docs/git-worktree) — Worktree management, pruning

### Secondary (MEDIUM confidence)

**Expert Blogs & Technical Articles:**
- [Designing Modular Bash (Lost in IT, 2025)](https://www.lost-in-it.com/posts/designing-modular-bash-functions-namespaces-library-patterns/) — Module patterns, namespacing
- [Modularizing Bash Script Code (Medium, 2025)](https://medium.com/mkdir-awesome/the-ultimate-guide-to-modularizing-bash-script-code-f4a4d53000c2) — Sourcing patterns, structure
- [Error Handling in Bash 2025 (DEV Community)](https://dev.to/rociogarciavf/how-to-handle-errors-in-bash-scripts-in-2025-3bo) — set -euo pipefail, trap patterns
- [Git Worktree: Pros, Cons, and Gotchas (Josh Tune)](https://joshtune.com/posts/git-worktree-pros-cons/) — Common mistakes, best practices
- [Lock Files in Bash (Graham Watts)](https://grahamwatts.co.uk/blog/2024/10/09/lock-files-in-bash/) — File locking patterns

**Industry Patterns:**
- [SS&C Blue Prism: Attended vs Unattended RPA](https://www.blueprism.com/resources/blog/attended-vs-unattended-rpa/) — Set-and-forget automation patterns
- [Nected: Sequential Workflows](https://www.nected.ai/blog/automate-your-projects-with-sequential-workflows) — Task completion ordering
- [GitHub Actions Parallel/Sequential (Medium)](https://medium.com/@nickjabs/running-github-actions-in-parallel-and-sequentially-b338e4a46bf5) — Job dependencies

### Project-Specific

**SnowyOwl Codebase:**
- `/Users/kristiangarza/aves/snowyowl/.planning/PROJECT.md` — Core requirements, mode specifications
- `/Users/kristiangarza/aves/snowyowl/SnowyOwl-GSD-Plan-V3.md` — Integration strategy, readiness rules
- `/Users/kristiangarza/aves/snowyowl/.planning/codebase/ARCHITECTURE.md` — Existing modular architecture
- `run_copilot_automation.sh` — Existing entry point pattern
- `lib/*.sh` — Existing shared utilities

---
*Research completed: 2026-02-01*
*Ready for roadmap: yes*
