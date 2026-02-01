# Coding Conventions

**Analysis Date:** 2026-02-01

## Language

**Primary:** Bash 4+

All project code is written in Bash. Scripts use the shebang `#!/usr/bin/env bash` and are executed with `set -euo pipefail` for error handling.

## Naming Patterns

**Files:**
- Executables: snake_case with `.sh` extension (e.g., `run_copilot_automation.sh`, `setup.sh`)
- Library modules: snake_case (e.g., `config.sh`, `git_utils.sh`, `task_processing.sh`)
- Configuration: `.toml` format (e.g., `.mise.toml`, `config.env`)

**Functions:**
- snake_case (e.g., `parse_arguments`, `build_task_prompt`, `create_worktree`)
- Prefix with module responsibility: `run_ai_backend`, `create_pr_for_branch`, `extract_task_link`
- Internal helpers use leading underscore conceptually but are documented inline

**Variables:**
- UPPERCASE for global/environment variables (e.g., `ROOT`, `LOG_DIR`, `AI_BACKEND`, `AI_MODEL`)
- UPPERCASE for constants (e.g., `TIMESTAMP`, `BASE_BRANCH`, `WORKTREES_DIR`)
- lowercase for local function variables (e.g., `repo_path`, `task_title`, `worktree_name`, `exit_code`)
- Prefix with module name for module-specific globals (e.g., `CLAUDE_ALLOWED_TOOLS`, `COPILOT_DENY_TOOLS`)

**Examples from codebase:**

See `lib/config.sh` lines 9-32 for global configuration variables.
See `lib/task_processing.sh` lines 235-342 for function naming patterns.
See `lib/git_utils.sh` lines 25-55 for local variable patterns.

## Code Style

**Formatting:**
- No automated formatter currently in use
- Manual style consistency through peer review
- Line length: generally kept under 120 characters for readability
- Indentation: 2 spaces (seen in `.mise.toml` and heredocs in shell functions)

**Shell-specific conventions:**
- Use `[[ ]]` for conditional tests, not `[ ]` (e.g., `lib/config.sh` line 48: `[[ "$AI_BACKEND" != "copilot" ... ]]`)
- Use `$(...)` for command substitution, not backticks (e.g., `lib/task_processing.sh` line 137: `slug=$(echo "$prompt" | llm -m gpt-4o-mini 2>/dev/null || echo "")`)
- Quote all variables: `"$variable"` not `$variable` (e.g., `lib/git_utils.sh` line 31: `local repo_name="$2"`)
- Use long form flags when possible for clarity: `--help` not `-h` in invocations
- Use explicit control flow: avoid side effects in conditional expressions

**Examples:**
```bash
# From lib/config.sh line 36-41: argument parsing pattern
while [[ $# -gt 0 ]]; do
  case $1 in
    -r|--root)
      ROOT="$2"
      shift 2
      ;;
```

## Import Organization

**Module loading order** (see `run_copilot_automation.sh` lines 22-26):
1. config.sh (defines global variables used by all modules)
2. git_utils.sh (git operations)
3. ai_backends.sh (AI integrations)
4. task_processing.sh (must be last, depends on all others)

**Module sourcing pattern:**
```bash
source "$SCRIPT_DIR/lib/config.sh"
source "$SCRIPT_DIR/lib/git_utils.sh"
source "$SCRIPT_DIR/lib/ai_backends.sh"
source "$SCRIPT_DIR/lib/task_processing.sh"
```

No circular dependencies between modules. Each module is self-contained.

## Error Handling

**Pattern:** Exit on error with messaging

- Use `set -euo pipefail` at top of scripts (e.g., `run_copilot_automation.sh` line 17)
- All commands redirect stderr when testing: `command &> /dev/null` or `2>/dev/null`
- Check exit codes explicitly when non-fatal: `if command; then ... fi` (e.g., `lib/task_processing.sh` lines 69-84)
- Return values:
  - `return 0` for success
  - `return 1` for hard failure (exit script)
  - `return 2` for soft failure/fallback (e.g., `lib/ai_backends.sh` line 137: copilot not available, use fallback)

**Error logging:**

Three logging levels (see `lib/config.sh` lines 137-147):

```bash
log()           # [timestamp] message (stdout + log file)
log_error()     # [timestamp] ERROR: message (stderr + log file)
log_success()   # [timestamp] SUCCESS: message (stdout + log file)
```

All errors logged to `$MAIN_LOG` with timestamps.

**Example error handling** (from `lib/task_processing.sh` lines 66-104):
```bash
if ! command -v git &> /dev/null; then
  log_error "git is not installed"
  exit 1
fi

# Soft failure - continues with fallback
if ! command -v llm &> /dev/null; then
  log_error "LLM CLI is not installed..."
  exit 1
fi
```

## Logging

**Framework:** Native bash with `echo` and `tee`

**Pattern** (see `lib/config.sh` lines 137-147):
```bash
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$MAIN_LOG"
}
```

**When to log:**
- Function entry for major operations (see `lib/task_processing.sh` line 244: `log "Task: $task_title"`)
- State changes (branch creation, worktree setup, PR creation)
- Prerequisites validation (see `lib/task_processing.sh` line 67: `log "Checking prerequisites..."`)
- Task completion or errors
- Warnings for recoverable issues (see `lib/task_processing.sh` line 54: `log "Warning: Specification file is large..."`)

**Log locations:**
- Main log: `$LOG_DIR/automation_${TIMESTAMP}.log` (e.g., `logs/automation_20260201_171234.log`)
- Repository-specific log: `$LOG_DIR/${repo_name}_${TIMESTAMP}.log`

**Log file handling:**
- Created in `init_directories()` function (`lib/config.sh` lines 130-134)
- Timestamped for uniqueness: `TIMESTAMP=$(date +%Y%m%d_%H%M%S)` (line 16)
- Old logs cleaned via task: `just clean` removes all but last 10 (see `.mise.toml` lines 54-60)

## Comments

**When to comment:**
- Module headers: explain purpose and dependencies (e.g., `lib/config.sh` lines 2-6)
- Function headers: describe purpose and return value (e.g., `lib/task_processing.sh` lines 27-28)
- Complex logic: explain why, not what (e.g., `lib/task_processing.sh` lines 46-47: path cleaning explained)
- Edge cases and workarounds (e.g., `lib/git_utils.sh` line 74: fallback cleanup comment)

**JSDoc/Comments style:**
```bash
# Extract markdown link from task text
# Returns: "title|path" or "title|" if no link
extract_task_link() {
```

## Function Design

**Size:**
- Keep functions under 50 lines when possible
- Complex operations split into helper functions
- Example: `implement_task()` is 107 lines (large) but handles complex orchestration with clear sections (`lib/task_processing.sh` lines 235-342)

**Parameters:**
- Accept positional arguments only (no named parameters)
- Document with comments above function
- Pass directory paths as first arguments
- Pass mode/flags as later arguments (see `lib/task_processing.sh` line 236: `dry_run`, `repo_log`)

**Return values:**
- Exit codes: 0 for success, 1 for error, 2 for soft failure
- Output via `echo` when needed (e.g., `create_worktree()` returns path via echo line 54)
- Store output in variable: `result=$(function_call)`

**Example function pattern** (from `lib/git_utils.sh` lines 25-55):
```bash
# Create a worktree for a feature branch
# Returns: worktree_path
create_worktree() {
  local repo_path="$1"
  local repo_name="$2"
  local branch_name="$3"
  local base_branch="$4"
  local repo_log="$5"

  # ... validation and work ...

  echo "$worktree_path"  # Return via echo
}

# Usage:
current_worktree=$(create_worktree "$repo_path" "$repo_name" "$branch" "$base" "$log")
```

## Module Design

**Module organization:**
- Each module has one primary responsibility (config, git, AI, tasks)
- No circular dependencies between modules
- Load order enforced: config first, task_processing last
- See `lib/README.md` for dependency documentation

**Exports:**
- All module functions are exported (no encapsulation in bash)
- Functions prefixed with module intent: `run_copilot_backend`, `create_pr_for_branch`
- Global variables UPPERCASE at module level

**Barrel files:**
- No barrel pattern; modules sourced in specific order in main script
- Module loading documented in `lib/README.md` lines 67-73

## Special Patterns

**LLM integration pattern** (see `lib/task_processing.sh` lines 106-157):
```bash
local prompt="Multi-line prompt here..."
local result=$(echo "$prompt" | llm -m gpt-4o-mini 2>/dev/null || echo "")

# Fallback if LLM fails
if [[ -z "$result" ]]; then
  log "LLM parsing failed, falling back to simple regex parsing"
  # Simple regex-based fallback
fi
```

**Conditional feature availability** (see `lib/ai_backends.sh` lines 272-280):
```bash
local backend_available=false
case "$AI_BACKEND" in
  claude)
    command -v claude &> /dev/null && backend_available=true
    ;;
  copilot|*)
    command -v copilot &> /dev/null && backend_available=true
    ;;
esac
```

**Worktree isolation pattern** (see `lib/task_processing.sh` line 254):
```bash
# Change to worktree directory for all operations
cd "$worktree_path"
# All subsequent operations happen in isolated worktree
```

---

*Convention analysis: 2026-02-01*
