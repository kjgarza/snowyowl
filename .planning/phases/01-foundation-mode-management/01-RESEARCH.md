# Phase 1: Foundation & Mode Management - Research

**Researched:** 2026-02-02
**Domain:** Bash mode detection, environment variables, logging infrastructure
**Confidence:** HIGH

## Summary

Phase 1 establishes the foundation for SnowyOwl's dual-mode system by implementing mode detection via the `SNOWYOWL_MODE` environment variable with file-presence fallback, and extending the logging infrastructure to support GSD-specific events. The existing codebase provides solid infrastructure in `lib/config.sh` that can be extended rather than replaced.

The recommended approach uses a cascading detection pattern: environment variable takes precedence, then file presence detection (`.planning/` = GSD, `TASKS.md` = TASKS). This aligns with bash best practices for configuration: explicit overrides via environment, sensible defaults via file system state. The dry-run mode should use the existing pattern in the codebase (`$DRY_RUN` flag checked before mutating operations) extended to cover GSD-specific actions.

For logging, the existing `log()`, `log_error()`, and `log_success()` functions in `lib/config.sh` provide the foundation. GSD mode needs additional context: phase numbers, timing information, and exit codes from Claude CLI calls. Rather than replacing the logging system, extend it with a `log_gsd()` function that wraps the existing `log()` with GSD-specific metadata.

**Primary recommendation:** Extend existing `lib/config.sh` with mode detection functions and GSD logging helpers, keeping the module shared across both entry points.

## Standard Stack

The established libraries/tools for this domain:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Bash | 5.0+ | Core scripting | Already used; provides `${VAR:-default}` expansion, `[[ ]]` conditionals |
| set -euo pipefail | N/A | Error handling | Industry standard for fail-fast scripts; already in codebase |
| date | System | Timestamps | POSIX standard; consistent across macOS/Linux |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| tee | System | Log to stdout and file | Already used in existing `log()` functions |
| mkdir -p | System | Create log directories | Already used in `init_directories()` |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Custom log functions | bashlog or tinylogger | External dependency; overkill for this use case |
| Environment variable mode | Config file mode | Environment variable is simpler, matches existing patterns |
| JSON structured logging | Plain text with timestamps | JSON requires jq for parsing; plain text sufficient for debugging |

**Installation:**
No additional packages required. Phase 1 uses only built-in bash capabilities.

## Architecture Patterns

### Recommended Project Structure
```
snowyowl/
├── run_copilot_automation.sh    # Entry point: TASKS mode (existing)
├── run_gsd_automation.sh        # Entry point: GSD mode (new in later phase)
├── lib/
│   ├── config.sh                # Shared: Extended with mode detection + GSD logging
│   ├── git_utils.sh             # Shared: Unchanged
│   ├── ai_backends.sh           # Shared: Unchanged
│   └── task_processing.sh       # TASKS mode specific: Unchanged
├── config.env                   # Extended with GSD settings
└── logs/
    ├── automation_*.log         # Existing TASKS mode logs
    └── gsd_*.log                # New GSD mode logs
```

### Pattern 1: Cascading Mode Detection
**What:** Check environment variable first, fall back to file presence, default to a sensible mode.
**When to use:** When mode selection should be explicit but also work automatically.
**Example:**
```bash
# Source: Bash best practices, existing SnowyOwl patterns
detect_execution_mode() {
  # Priority 1: Explicit environment variable
  if [[ -n "${SNOWYOWL_MODE:-}" ]]; then
    case "${SNOWYOWL_MODE}" in
      gsd|GSD)
        echo "gsd"
        return 0
        ;;
      tasks|TASKS)
        echo "tasks"
        return 0
        ;;
      *)
        log_error "Invalid SNOWYOWL_MODE: ${SNOWYOWL_MODE}. Must be 'gsd' or 'tasks'"
        return 1
        ;;
    esac
  fi

  # Priority 2: File presence detection for current directory context
  # Note: This is for single-repo mode detection, not scanning
  local target_dir="${1:-.}"

  if [[ -d "${target_dir}/.planning" ]]; then
    echo "gsd"
    return 0
  fi

  if [[ -f "${target_dir}/TASKS.md" ]]; then
    echo "tasks"
    return 0
  fi

  # Priority 3: Default (prefer TASKS as existing behavior)
  echo "tasks"
  return 0
}
```

### Pattern 2: Mode Validation with Fail-Fast
**What:** Validate mode early and exit with clear error if invalid.
**When to use:** At script startup, before any work begins.
**Example:**
```bash
# Source: Bash best practices for fail-fast
validate_mode() {
  local mode="$1"
  case "$mode" in
    gsd|tasks)
      return 0
      ;;
    *)
      log_error "Unknown mode: $mode"
      exit 1
      ;;
  esac
}

# In main():
EXECUTION_MODE=$(detect_execution_mode)
validate_mode "$EXECUTION_MODE"
```

### Pattern 3: GSD-Aware Logging
**What:** Extend existing log functions with GSD-specific context (phase, timing, exit codes).
**When to use:** When logging GSD phase execution events.
**Example:**
```bash
# Source: Existing lib/config.sh pattern extended
# GSD-specific log file (separate from main TASKS log)
GSD_LOG=""

init_gsd_logging() {
  GSD_LOG="$LOG_DIR/gsd_${TIMESTAMP}.log"
  touch "$GSD_LOG"
}

# Log with phase context
log_gsd() {
  local phase="${1:-}"
  local message="${2:-}"
  local level="${3:-INFO}"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] [Phase $phase] $message" | tee -a "$GSD_LOG"
}

# Log phase execution with timing
log_phase_start() {
  local phase="$1"
  local repo="$2"
  log_gsd "$phase" "Starting execution in $repo" "INFO"
  # Store start time for duration calculation
  PHASE_START_TIME=$(date +%s)
}

log_phase_end() {
  local phase="$1"
  local exit_code="$2"
  local end_time=$(date +%s)
  local duration=$((end_time - PHASE_START_TIME))
  log_gsd "$phase" "Completed with exit code $exit_code (duration: ${duration}s)" "INFO"
}
```

### Pattern 4: Dry-Run Guard Pattern
**What:** Wrap mutating operations with dry-run checks that log what would happen.
**When to use:** For any operation that modifies state (git, file writes, CLI calls).
**Example:**
```bash
# Source: Existing SnowyOwl dry-run pattern extended
# Execute command or log it in dry-run mode
execute_or_log() {
  local description="$1"
  shift
  local cmd=("$@")

  if [[ "$DRY_RUN" == true ]]; then
    log "[DRY RUN] Would: $description"
    log "[DRY RUN] Command: ${cmd[*]}"
    return 0
  else
    log "Executing: $description"
    "${cmd[@]}"
    return $?
  fi
}

# Usage:
execute_or_log "create worktree" git worktree add -b "$branch" "$path" "$base"
```

### Anti-Patterns to Avoid
- **Multiple mode checks scattered in code:** Detect mode once at startup, store in global, reference everywhere.
- **Different logging formats per mode:** Keep log format consistent; add mode-specific metadata, not different formats.
- **Mode-specific logic in shared libraries:** Keep config.sh mode-agnostic; entry scripts handle mode-specific orchestration.
- **Silent fallback without logging:** Always log which mode was detected and why (helps debugging).

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Timestamp generation | Custom date formatting | `date '+%Y-%m-%d %H:%M:%S'` | POSIX standard, consistent behavior |
| Log file rotation | Custom rotation logic | External logrotate or just keep recent logs | Rotation is complex; existing `just clean` handles old logs |
| Config file parsing | Custom INI/YAML parser | Environment variables + `source config.env` | Bash has no built-in parser; sourcing env files is simpler |
| Mode detection | Complex state machine | Simple if/elif/else cascade | Mode is binary (gsd/tasks); complexity is unnecessary |

**Key insight:** The existing SnowyOwl codebase already has working patterns for logging, configuration, and dry-run. Phase 1 extends these patterns rather than replacing them.

## Common Pitfalls

### Pitfall 1: Unquoted Variable Expansion
**What goes wrong:** `if [[ $SNOWYOWL_MODE == gsd ]]` fails when variable is empty or contains spaces.
**Why it happens:** Bash word splitting on unquoted variables.
**How to avoid:** Always quote: `if [[ "${SNOWYOWL_MODE:-}" == "gsd" ]]`
**Warning signs:** "unary operator expected" or "binary operator expected" errors.

### Pitfall 2: Missing Default Values
**What goes wrong:** Script fails with "unbound variable" when `set -u` is set and env var not defined.
**Why it happens:** `$SNOWYOWL_MODE` fails if variable doesn't exist with `set -u`.
**How to avoid:** Use `${SNOWYOWL_MODE:-}` for optional or `${SNOWYOWL_MODE:?Required}` for required.
**Warning signs:** Script exits immediately with no useful error message.

### Pitfall 3: Log File Path Race Condition
**What goes wrong:** Multiple processes write to same log file, causing interleaved output.
**Why it happens:** Parallel execution without unique log paths.
**How to avoid:** Include PID or unique identifier in log filename: `gsd_${TIMESTAMP}_$$.log`
**Warning signs:** Corrupted or interleaved log entries.

### Pitfall 4: Mode Detection at Wrong Scope
**What goes wrong:** Mode detected per-repo when it should be global, or vice versa.
**Why it happens:** Unclear whether mode is "how to run SnowyOwl" vs "how to process this repo".
**How to avoid:** Distinguish:
  - Global mode: SNOWYOWL_MODE env var - set once, applies to whole run
  - Per-repo context: File presence - checked per repository during scanning
**Warning signs:** Inconsistent behavior between repos in same run.

### Pitfall 5: Dry-Run Inconsistency
**What goes wrong:** Some operations respect dry-run, others don't.
**Why it happens:** Forgetting to add dry-run checks to new code paths.
**How to avoid:** Use consistent guard pattern (execute_or_log helper); audit all git/file operations.
**Warning signs:** Dry-run mode makes unexpected changes.

## Code Examples

Verified patterns from official sources and existing codebase:

### Mode Detection Implementation
```bash
# Source: Existing lib/config.sh pattern, extended
# Location: lib/config.sh

# Execution mode: gsd or tasks
EXECUTION_MODE=""

# Detect execution mode from environment or file presence
# Arguments:
#   $1 - Optional: target directory for file presence check (default: current dir)
# Returns: Sets EXECUTION_MODE global, returns 0 on success, 1 on error
detect_execution_mode() {
  local target_dir="${1:-.}"

  # Priority 1: Explicit environment variable
  if [[ -n "${SNOWYOWL_MODE:-}" ]]; then
    local normalized_mode
    normalized_mode=$(echo "${SNOWYOWL_MODE}" | tr '[:upper:]' '[:lower:]')
    case "${normalized_mode}" in
      gsd)
        EXECUTION_MODE="gsd"
        log "Mode detected: gsd (from SNOWYOWL_MODE environment variable)"
        return 0
        ;;
      tasks)
        EXECUTION_MODE="tasks"
        log "Mode detected: tasks (from SNOWYOWL_MODE environment variable)"
        return 0
        ;;
      *)
        log_error "Invalid SNOWYOWL_MODE: ${SNOWYOWL_MODE}. Must be 'gsd' or 'tasks'"
        return 1
        ;;
    esac
  fi

  # Priority 2: File presence detection
  if [[ -d "${target_dir}/.planning" ]]; then
    EXECUTION_MODE="gsd"
    log "Mode detected: gsd (from .planning/ directory presence)"
    return 0
  fi

  if [[ -f "${target_dir}/TASKS.md" ]]; then
    EXECUTION_MODE="tasks"
    log "Mode detected: tasks (from TASKS.md file presence)"
    return 0
  fi

  # Priority 3: Default to tasks (backward compatible)
  EXECUTION_MODE="tasks"
  log "Mode detected: tasks (default - no indicators found)"
  return 0
}
```

### GSD Logging Functions
```bash
# Source: Extended from existing lib/config.sh
# Location: lib/config.sh (additions)

# GSD-specific log file
GSD_LOG=""
PHASE_START_TIME=0

# Initialize GSD logging
# Must be called after init_directories()
init_gsd_logging() {
  if [[ "$EXECUTION_MODE" == "gsd" ]]; then
    GSD_LOG="$LOG_DIR/gsd_${TIMESTAMP}.log"
    touch "$GSD_LOG"
    log "GSD log file: $GSD_LOG"
  fi
}

# Log GSD-specific event with phase context
# Arguments:
#   $1 - Phase number (or "scan" for scanning phase)
#   $2 - Message
#   $3 - Optional: Level (INFO, WARN, ERROR) - default INFO
log_gsd() {
  local phase="${1:-N/A}"
  local message="${2:-}"
  local level="${3:-INFO}"

  if [[ -z "$GSD_LOG" ]]; then
    # Fallback to main log if GSD log not initialized
    log "[$level] [Phase $phase] $message"
    return
  fi

  local timestamp
  timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  echo "[$timestamp] [$level] [Phase $phase] $message" | tee -a "$GSD_LOG" "$MAIN_LOG"
}

# Log phase execution start with timing
log_phase_start() {
  local phase="$1"
  local repo="${2:-}"
  PHASE_START_TIME=$(date +%s)
  log_gsd "$phase" "=== Phase execution started ===" "INFO"
  if [[ -n "$repo" ]]; then
    log_gsd "$phase" "Repository: $repo" "INFO"
  fi
}

# Log phase execution end with duration and exit code
log_phase_end() {
  local phase="$1"
  local exit_code="${2:-0}"
  local end_time
  end_time=$(date +%s)
  local duration=$((end_time - PHASE_START_TIME))

  local level="INFO"
  if [[ "$exit_code" -ne 0 ]]; then
    level="ERROR"
  fi

  log_gsd "$phase" "=== Phase execution completed ===" "$level"
  log_gsd "$phase" "Exit code: $exit_code, Duration: ${duration}s" "$level"
}

# Log readiness scan results
log_scan_result() {
  local repo="$1"
  local ready_phases="$2"
  local reason="${3:-}"

  if [[ -n "$ready_phases" ]]; then
    log_gsd "scan" "Repository $repo: ready phases: $ready_phases" "INFO"
  else
    log_gsd "scan" "Repository $repo: not ready - $reason" "INFO"
  fi
}
```

### Dry-Run Mode Extension
```bash
# Source: Existing pattern from lib/task_processing.sh, generalized
# Location: lib/config.sh (additions)

# Execute a command or log it in dry-run mode
# Arguments:
#   $1 - Human-readable description of the action
#   $@ - Command and arguments to execute
# Returns: Command exit code, or 0 in dry-run mode
execute_or_dry_run() {
  local description="$1"
  shift

  if [[ "$DRY_RUN" == true ]]; then
    log "[DRY RUN] Would: $description"
    log "[DRY RUN] Command: $*"
    return 0
  else
    "$@"
    return $?
  fi
}

# Check if we should skip execution (dry-run helper)
# Usage: if should_execute; then <do_thing>; fi
should_execute() {
  [[ "$DRY_RUN" != true ]]
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Single dispatcher script | Multiple entry points | 2024+ | Cleaner separation, easier testing |
| Complex config files | Environment variables + sourced .env | Ongoing | Simpler, CI/CD compatible |
| Ad-hoc logging | Structured log functions | Bash best practices codified | Consistent debugging experience |

**Deprecated/outdated:**
- Using `[ ]` instead of `[[ ]]`: Modern bash uses `[[ ]]` for safer string comparisons
- Using backticks for command substitution: `$(...)` is the modern standard
- Unquoted variables: Always quote `"$var"` to prevent word splitting

## Open Questions

Things that couldn't be fully resolved:

1. **Should mode be re-detected per repository or once globally?**
   - What we know: Environment variable mode is clearly global. File presence could be per-repo.
   - What's unclear: When scanning multiple repos, should each repo's mode be independent?
   - Recommendation: Global mode from env var; file presence is fallback for single-repo context. When scanning, filter repos by what matches the global mode.

2. **Log file naming with parallel execution**
   - What we know: Current timestamp-based naming works for sequential execution.
   - What's unclear: When parallel execution is added (Phase 8), how to handle per-repo logs.
   - Recommendation: Add repo name to log filename now: `gsd_${repo_name}_${TIMESTAMP}.log`. Prepares for parallelization.

## Sources

### Primary (HIGH confidence)
- Existing SnowyOwl codebase: `lib/config.sh`, `run_copilot_automation.sh` - verified working patterns
- [Bash Best Practices Cheat Sheet](https://bertvv.github.io/cheat-sheets/Bash.html) - error handling, variable expansion
- [GNU Bash Manual - Pattern Matching](https://www.gnu.org/software/bash/manual/html_node/Pattern-Matching.html) - file detection patterns
- [Greg's Wiki BashGuide/Patterns](https://mywiki.wooledge.org/BashGuide/Patterns) - glob patterns, file tests

### Secondary (MEDIUM confidence)
- [Structured Logging in Shell Scripting (Picus Security)](https://medium.com/picus-security-engineering/structured-logging-in-shell-scripting-dd657970cd5d) - logging patterns
- [Logging in Bash Scripts (Graham Watts)](https://grahamwatts.co.uk/bash-logging/) - timestamp and level patterns
- [A Shell --dry-run Trick (Jens Rantil)](https://jensrantil.github.io/posts/a-shell-dry-run-trick/) - dry-run implementation patterns
- [10 Bash Script Logging Best Practices (CLIMB)](https://climbtheladder.com/10-bash-script-logging-best-practices/) - log levels, rotation
- [Environment Variables Guide (Hostinger)](https://www.hostinger.com/tutorials/linux-environment-variables) - 2026 bash variable practices

### Tertiary (LOW confidence)
- N/A - All findings verified against existing codebase or official documentation

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Uses only built-in bash; no external dependencies
- Architecture: HIGH - Extends existing proven patterns in codebase
- Pitfalls: HIGH - Verified against bash documentation and existing code

**Research date:** 2026-02-02
**Valid until:** 2026-03-02 (30 days - stable domain, low churn)
