# Architecture Research

**Domain:** Modular Bash Automation Systems
**Researched:** 2026-02-01
**Confidence:** HIGH

## Standard Architecture

### System Overview

```
┌──────────────────────────────────────────────────────────────────┐
│                      Entry Point Layer                            │
├──────────────────────────────────────────────────────────────────┤
│  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐      │
│  │ run_copilot    │  │ run_gsd        │  │ Future modes   │      │
│  │ automation.sh  │  │ automation.sh  │  │                │      │
│  └────────┬───────┘  └────────┬───────┘  └────────┬───────┘      │
│           │                   │                   │              │
│           └───────────────────┴───────────────────┘              │
│                               │                                  │
├───────────────────────────────┼──────────────────────────────────┤
│                      Library Layer                                │
├──────────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐  │
│  │ config.sh   │  │ git_utils.sh│  │ ai_backends.sh          │  │
│  │ (shared)    │  │ (shared)    │  │ (shared)                │  │
│  └─────────────┘  └─────────────┘  └─────────────────────────┘  │
│                                                                  │
│  ┌─────────────────────────────┐  ┌──────────────────────────┐  │
│  │ task_processing.sh          │  │ gsd_scanner.sh           │  │
│  │ (copilot mode specific)     │  │ (gsd mode specific)      │  │
│  └─────────────────────────────┘  └──────────────────────────┘  │
│                                                                  │
│  ┌─────────────────────────────┐  ┌──────────────────────────┐  │
│  │ gsd_runner.sh               │  │ gsd_pr.sh                │  │
│  │ (gsd mode specific)         │  │ (gsd mode specific)      │  │
│  └─────────────────────────────┘  └──────────────────────────┘  │
├──────────────────────────────────────────────────────────────────┤
│                      External Tools                               │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐         │
│  │   git    │  │    gh    │  │  claude  │  │  copilot │         │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘         │
└──────────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

| Component | Responsibility | Typical Implementation |
|-----------|----------------|------------------------|
| Entry Point Scripts | Mode-specific orchestration, argument parsing, main execution flow | Separate bash scripts (run_*.sh) |
| Shared Libraries | Cross-mode utilities (logging, git ops, config) | Sourced bash modules in lib/ |
| Mode-Specific Libraries | Mode-unique operations (task parsing vs GSD scanning) | Sourced bash modules in lib/ |
| External Tools | CLI tools for actual work (git, AI, PRs) | System-installed binaries |

## Recommended Project Structure

```
snowyowl/
├── run_copilot_automation.sh    # Entry point: Tasks mode
├── run_gsd_automation.sh        # Entry point: GSD mode
├── lib/
│   ├── config.sh                # Shared: Logging, env vars, argument parsing
│   ├── git_utils.sh             # Shared: Worktree management, remote checks
│   ├── ai_backends.sh           # Shared: AI provider abstraction
│   ├── task_processing.sh       # Copilot mode: TASKS.md parsing
│   ├── gsd_scanner.sh           # GSD mode: Readiness detection
│   ├── gsd_runner.sh            # GSD mode: Claude command execution
│   └── gsd_pr.sh                # GSD mode: PR body generation
├── config.env                   # Environment configuration
├── .mise.toml                   # Task shortcuts
├── templates/
│   └── TASKS.template.md
└── examples/
    └── gsd-workflow.md
```

### Structure Rationale

- **Separate entry points:** Each mode has distinct workflows (scan repos vs parse tasks), so dedicated entry scripts keep orchestration clean and testable.
- **Shared lib/ modules:** Common operations (logging, git, AI backends) are factored into reusable modules, sourced by multiple entry points.
- **Mode-specific lib/ modules:** Mode-unique logic (task parsing vs readiness scanning) stays isolated, preventing feature entanglement.
- **Flat lib/ structure:** All library files live at lib/*.sh with descriptive names. Namespacing via filename (gsd_*.sh) rather than subdirectories keeps sourcing simple.

## Architectural Patterns

### Pattern 1: Multiple Entry Points (Not Dispatcher)

**What:** Separate executable scripts for each mode, rather than a single dispatcher with subcommands.

**When to use:** When modes have fundamentally different workflows and argument structures.

**Trade-offs:**
- **Pros:** Simpler implementation, easier testing, clear separation of concerns, no complex routing logic.
- **Cons:** More scripts in root directory, mode selection happens at script choice (not argument).

**Example:**
```bash
# Copilot mode entry point
./run_copilot_automation.sh --root ~/aves --backend copilot

# GSD mode entry point
./run_gsd_automation.sh --scan-only

# Not a dispatcher pattern like:
# ./snowyowl.sh copilot --root ~/aves
# ./snowyowl.sh gsd --scan-only
```

**Rationale for SnowyOwl:** The existing codebase already uses this pattern (run_copilot_automation.sh). GSD mode has completely different preconditions (scanning .planning/ directories vs parsing TASKS.md), different outputs (phase execution vs task implementation), and different scheduling needs. A separate entry point keeps each mode's logic clear and independently evolvable.

### Pattern 2: Namespace Prefix for Mode-Specific Modules

**What:** Use consistent filename prefixes (gsd_*.sh) to indicate module ownership and prevent naming collisions.

**When to use:** When library directory contains modules for multiple modes.

**Trade-offs:**
- **Pros:** Self-documenting module purpose, prevents naming conflicts, easy to identify dependencies.
- **Cons:** Slightly longer filenames.

**Example:**
```bash
lib/
├── config.sh           # Shared (no prefix)
├── git_utils.sh        # Shared (no prefix)
├── ai_backends.sh      # Shared (no prefix)
├── task_processing.sh  # Copilot mode (implicit prefix from context)
├── gsd_scanner.sh      # GSD mode (explicit prefix)
├── gsd_runner.sh       # GSD mode (explicit prefix)
└── gsd_pr.sh           # GSD mode (explicit prefix)
```

This follows the [Designing Modular Bash](https://www.lost-in-it.com/posts/designing-modular-bash-functions-namespaces-library-patterns/) recommendation: "Choose a short, unique prefix for your library and use it consistently."

### Pattern 3: Source-Based Module Loading (Not Importing)

**What:** Use `source` to include library modules at the top of entry scripts.

**When to use:** Always in bash. There's no import system.

**Trade-offs:**
- **Pros:** Simple, standard bash practice, explicit dependencies.
- **Cons:** Must maintain source order for dependencies, no automatic dependency resolution.

**Example:**
```bash
#!/usr/bin/env bash
set -euo pipefail

# Get script directory for sourcing modules
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source all library modules (order matters if modules depend on each other)
source "$SCRIPT_DIR/lib/config.sh"
source "$SCRIPT_DIR/lib/git_utils.sh"
source "$SCRIPT_DIR/lib/ai_backends.sh"
source "$SCRIPT_DIR/lib/gsd_scanner.sh"
source "$SCRIPT_DIR/lib/gsd_runner.sh"
source "$SCRIPT_DIR/lib/gsd_pr.sh"

# Main execution
main() {
  parse_arguments "$@"
  # ...
}

main "$@"
```

**Current SnowyOwl implementation:** Already follows this pattern in run_copilot_automation.sh (lines 19-26).

### Pattern 4: Mode Detection via Entry Point (Not Environment Variable)

**What:** Mode is determined by which script you run, not by checking environment variables or arguments.

**When to use:** When modes are operationally distinct (different cron schedules, different use cases).

**Trade-offs:**
- **Pros:** Explicit mode selection, simpler logic, no mode validation needed.
- **Cons:** Cannot dynamically switch modes within a single script execution.

**Example:**
```bash
# Copilot mode: user explicitly runs copilot entry point
./run_copilot_automation.sh

# GSD mode: user explicitly runs GSD entry point
./run_gsd_automation.sh

# Not environment-variable-driven mode switching:
# SNOWYOWL_MODE=gsd ./run_automation.sh
```

**Rationale:** The two modes serve different purposes:
- Copilot mode: Manual/scheduled task execution based on TASKS.md
- GSD mode: Overnight phase execution based on .planning/ readiness

They will likely run on different schedules (GSD nightly, copilot on-demand) and have different prerequisites. Separate entry points match this operational reality.

### Pattern 5: Fail-Fast Prerequisite Checking

**What:** Check all external dependencies (git, gh, claude, etc.) before starting main workflow.

**When to use:** Always in automation scripts.

**Trade-offs:**
- **Pros:** Clear error messages, prevents partial execution, fails early.
- **Cons:** Adds startup time (minimal for command existence checks).

**Example:**
```bash
check_prerequisites() {
  log "Checking prerequisites..."

  if ! command -v git &> /dev/null; then
    log_error "git is not installed"
    exit 1
  fi

  if ! command -v gh &> /dev/null; then
    log_error "GitHub CLI (gh) is not installed"
    exit 1
  fi

  # Mode-specific checks
  case "$MODE" in
    gsd)
      if ! command -v claude &> /dev/null; then
        log_error "Claude Code CLI is not installed"
        exit 1
      fi
      ;;
  esac

  log_success "Prerequisites check passed"
}
```

**Current SnowyOwl implementation:** Already follows this pattern in lib/task_processing.sh (check_prerequisites function, lines 65-104).

## Data Flow

### Copilot Mode Flow (Existing)

```
User runs script
    ↓
[Config] → Parse args, set env vars
    ↓
[Prerequisites] → Check git, gh, copilot/claude
    ↓
[Scan] → Find repos with TASKS.md
    ↓
For each repo:
    ↓
[Parse Tasks] → Extract from TASKS.md using LLM
    ↓
For each task:
    ↓
[Create Worktree] → git worktree add -b branch
    ↓
[Implement] → Call AI backend (copilot/claude)
    ↓
[Commit] → git add . && git commit
    ↓
[Push & PR] → git push + gh pr create
    ↓
[Cleanup] → Optional: git worktree remove
```

### GSD Mode Flow (Proposed)

```
User runs script (or cron job)
    ↓
[Config] → Parse args, set env vars
    ↓
[Prerequisites] → Check git, gh, claude, jq
    ↓
[Scan] → Find repos with .planning/ directories
    ↓
For each repo:
    ↓
[Validate Config] → Check .planning/config.json (mode=yolo)
    ↓
[Check Readiness] → Find phases with PLAN.md but no SUMMARY.md
    ↓
If ready phases found:
    ↓
[Create Worktree] → git worktree add -b snowyowl-gsd-*
    ↓
For each ready phase (sequential):
    ↓
[Resume if needed] → /gsd:resume-work (if .continue-here exists)
    ↓
[Execute Phase] → claude -p "/gsd:execute-phase N"
    ↓
[Check Next] → Re-scan for next ready phase
    ↓
[Advance or Stop] → Continue if next ready, else stop
    ↓
[Push & PR] → git push + gh pr create (with SUMMARY.md content)
    ↓
[Cleanup] → git worktree remove
```

### Key Data Flows

1. **Configuration Flow:** Environment variables → config.sh functions → global bash variables used by all modules.
2. **Logging Flow:** All modules call log()/log_error()/log_success() defined in config.sh, which tee to both stdout and log file.
3. **Git Operations Flow:** Entry scripts call git_utils.sh functions (create_worktree, remove_worktree, has_github_remote).
4. **AI Backend Flow:** Entry scripts build prompts → ai_backends.sh dispatcher routes to copilot/claude → external CLI tools execute.

## Scaling Considerations

| Scale | Architecture Adjustments |
|-------|--------------------------|
| 1-5 repos | Current architecture sufficient — sequential processing fine |
| 5-20 repos | Add parallelization: use background jobs with wait/job control |
| 20+ repos | Consider job queue (GNU parallel, task queue service) |

### Scaling Priorities

1. **First bottleneck:** Sequential repo processing. GSD mode already anticipates this with `GSD_MAX_PARALLEL` config (from plan V3). Implement using:
   ```bash
   for repo in "${repos[@]}"; do
     process_repo "$repo" &
     # Wait if we've hit max parallel
     while [ $(jobs -r | wc -l) -ge "$MAX_PARALLEL" ]; do
       sleep 1
     done
   done
   wait  # Wait for all background jobs to finish
   ```

2. **Second bottleneck:** Worktree disk space. Cleanup is already optional (CLEANUP_WORKTREES). For many parallel executions, use /tmp or tmpfs: `WORKTREES_DIR="/tmp/snowyowl"`.

## Anti-Patterns

### Anti-Pattern 1: Complex Mode Switching Logic

**What people do:** Build a single entry script with complex if/case statements to route between modes.

**Why it's wrong:** As modes grow different, shared entry script becomes tangled with mode-specific logic. Testing becomes harder (must mock out unused branches).

**Do this instead:** Separate entry scripts. Share code via library modules, not via conditional execution paths.

**Example:**
```bash
# ANTI-PATTERN: Single dispatcher with mode argument
./run_automation.sh --mode copilot --root ~/aves
./run_automation.sh --mode gsd --scan-only

# BETTER: Separate entry points
./run_copilot_automation.sh --root ~/aves
./run_gsd_automation.sh --scan-only
```

### Anti-Pattern 2: Sourcing Mode-Specific Modules in Shared Modules

**What people do:** Shared modules (config.sh, git_utils.sh) source mode-specific modules (gsd_scanner.sh).

**Why it's wrong:** Creates circular dependencies and prevents reuse. Shared module becomes tied to specific mode.

**Do this instead:** Only entry scripts source modules. Shared modules should have no source statements, only function definitions. If shared module needs mode-specific behavior, use function arguments or callbacks.

**Example:**
```bash
# ANTI-PATTERN: config.sh sources gsd_scanner.sh
# lib/config.sh
source "$SCRIPT_DIR/lib/gsd_scanner.sh"  # BAD

# BETTER: Entry script sources both
# run_gsd_automation.sh
source "$SCRIPT_DIR/lib/config.sh"
source "$SCRIPT_DIR/lib/gsd_scanner.sh"
```

### Anti-Pattern 3: Global State Mutation Without Clear Ownership

**What people do:** Multiple modules modify the same global variables without clear ownership.

**Why it's wrong:** Creates hidden dependencies and makes debugging difficult. Hard to trace where values are set.

**Do this instead:**
- Config module owns configuration globals (set once at startup).
- Other modules read globals but don't modify them.
- Pass state via function arguments and return values.

**Example:**
```bash
# ANTI-PATTERN: Multiple modules modifying LOG_DIR
# lib/config.sh
LOG_DIR="${HOME}/logs"
# lib/gsd_scanner.sh
LOG_DIR="/tmp/gsd-logs"  # COLLISION!

# BETTER: Config owns it, others read it
# lib/config.sh
LOG_DIR="${SNOWYOWL_LOG_DIR:-${HOME}/aves/snowyowl/logs}"
init_directories() {
  mkdir -p "$LOG_DIR"
  readonly LOG_DIR  # Prevent modification after init
}
```

## Integration Points

### External Services

| Service | Integration Pattern | Notes |
|---------|---------------------|-------|
| git | Direct CLI calls via git_utils.sh | Worktree operations require git 2.15+ |
| GitHub CLI (gh) | Direct CLI calls for PR creation | Must be authenticated (gh auth status) |
| Claude Code | Direct CLI calls with -p flag | GSD mode: --dangerously-skip-permissions |
| GitHub Copilot | Direct CLI calls with --allow-all-tools | Copilot mode: --deny-tool for safety |
| LLM CLI | Direct CLI calls for task parsing | Uses gpt-4o-mini for branch slugs, commit messages |
| jq | Direct CLI calls for JSON parsing | GSD mode: Parse .planning/config.json |

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| Entry Point ↔ Shared Libs | Function calls (after source) | Entry scripts source shared libs, call functions |
| Entry Point ↔ Mode Libs | Function calls (after source) | Entry scripts source mode-specific libs, call functions |
| Shared Lib ↔ Shared Lib | Function calls (no source) | Assume both sourced by entry script |
| Mode Lib ↔ Mode Lib | Function calls (no source) | Assume both sourced by entry script |
| Shared Lib ↔ Mode Lib | Avoid | Shared should not know about mode-specific |

**Key Principle:** Source dependencies flow one direction only (entry → libs), while function call dependencies can flow between libs at the same level (both sourced by entry).

## Component Boundaries

### What's Shared vs Mode-Specific

| Component | Shared | Copilot Mode | GSD Mode |
|-----------|--------|--------------|----------|
| Logging (log, log_error, log_success) | ✓ | | |
| Argument parsing framework | ✓ | Mode-specific args | Mode-specific args |
| Worktree creation/removal | ✓ | | |
| GitHub remote detection | ✓ | | |
| AI backend dispatcher | ✓ | | |
| PR creation (gh pr create) | ✓ | Simple task list | GSD SUMMARY.md parsing |
| Task parsing | | ✓ | |
| TASKS.md file detection | | ✓ | |
| Readiness scanning | | | ✓ |
| .planning/ validation | | | ✓ |
| Phase execution loop | | | ✓ |
| Resume/pause logic | | | ✓ |

### Build Order (Suggested)

For implementing GSD mode integration:

1. **Extract shared utilities (lib/config.sh)** — If not already fully extracted, ensure logging, directory init, and base config parsing are in config.sh and reusable.

2. **Create lib/gsd_scanner.sh** — File-system-based readiness detection. This is pure bash (no AI calls), so it's testable independently:
   ```bash
   ./lib/gsd_scanner.sh ~/aves  # Should print ready repos/phases
   ```

3. **Create lib/gsd_runner.sh** — Simple wrapper around `claude -p "/gsd:execute-phase N"`. Test on a single repo with one ready phase.

4. **Create lib/gsd_pr.sh** — PR body generation from SUMMARY.md files. Testable with mock directories.

5. **Create run_gsd_automation.sh** — Wire everything together:
   - Load config
   - Call scanner
   - Create worktrees
   - Call runner
   - Call PR creator
   - Cleanup

6. **Update config.env** — Add GSD-specific settings (GSD_ROOT, GSD_MAX_PARALLEL, etc.).

7. **Update .mise.toml** — Add gsd, gsd:dry, gsd:scan task shortcuts.

8. **Test end-to-end** — Run on a test repo with prepared .planning/ structure.

Each step produces a testable artifact before integration.

## Sources

- [Designing Modular Bash: Functions, Namespaces, and Library Patterns](https://www.lost-in-it.com/posts/designing-modular-bash-functions-namespaces-library-patterns/)
- [The Ultimate Guide to Modularizing Bash Script Code](https://medium.com/mkdir-awesome/the-ultimate-guide-to-modularizing-bash-script-code-f4a4d53000c2)
- [Shell script patterns for bash](https://barro.github.io/2016/02/shell-script-patterns-for-bash/)
- [Command Dispatcher Pattern | Paramore Brighter Documentation](https://brightercommand.gitbook.io/paramore-brighter-documentation/command-processors-and-dispatchers-1/commandscommanddispatcherandprocessor)
- [The command dispatcher pattern](https://olvlvl.com/2018-04-command-dispatcher-pattern.html)
- [GitHub - wpalmer/dispatch.sh](https://github.com/wpalmer/dispatch.sh)
- Existing SnowyOwl codebase analysis (run_copilot_automation.sh, lib/*.sh)
- SnowyOwl GSD Plan V3 (SnowyOwl-GSD-Plan-V3.md)

---
*Architecture research for: Modular Bash Automation Systems*
*Researched: 2026-02-01*
