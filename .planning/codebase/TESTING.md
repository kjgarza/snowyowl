# Testing Patterns

**Analysis Date:** 2026-02-01

## Test Framework

**Status:** Not currently implemented in codebase

No automated test framework is configured. The project uses:
- Manual verification scripts
- Dry-run mode for validation
- Log-based verification

**Test infrastructure:**
- Dry-run mode: `--dry-run` flag prevents commits and PRs (`lib/config.sh` lines 62-64)
- Verification script: `verify_installation.sh` validates dependencies
- Integration testing via: `just test` - runs automation on test repositories

## Manual Verification Approach

**Dry-run mode** (primary testing mechanism):

```bash
./run_copilot_automation.sh --dry-run
# or via justfile:
just automate:dry
```

The `--dry-run` flag is passed through the system and checked at commit points:

See `lib/task_processing.sh` lines 321-341:
```bash
if [[ "$dry_run" == false ]]; then
  git add .
  if git diff --cached --quiet; then
    log "No changes to commit for task: $task_title"
    return 0
  else
    # Generate conventional commit message
    local commit_msg=$(generate_commit_message "$task_title")
    if ! git commit -m "$commit_msg" 2>&1 | tee -a "$repo_log"; then
      log_error "Failed to commit changes"
      return 1
    fi
```

Dry-run also prevents:
- Branch pushing (see `lib/task_processing.sh` line 396: `if [[ "$dry_run" == false ]]; then`)
- PR creation (see `lib/task_processing.sh` lines 395-395)
- Worktree cleanup (see `lib/task_processing.sh` lines 366-371)

**Output in dry-run:**
```bash
log "[DRY RUN] Would commit: $task_title"
log "[DRY RUN] Would push branch: $feature_branch"
log "[DRY RUN] Would create PR with ${#tasks[@]} task(s)"
```

## Verification Script

**Location:** `verify_installation.sh`

**Purpose:** Validates that all prerequisites are installed before running automation

**Run:**
```bash
./verify_installation.sh
# or via justfile:
just verify
```

**What it checks:**
- Git installation and configuration
- GitHub CLI installation and authentication
- LLM CLI installation
- AI backend availability (GitHub Copilot or Claude)
- Proper permissions on scripts

See `.mise.toml` line 137 for test task definition:
```toml
[tasks.test]
description = "Run a test automation on the snowyowl repository itself"
run = "./run_copilot_automation.sh --root /Users/kristiangarza/aves/labs --dry-run"
```

## Test Execution

**Available test commands:**

```bash
# Run verification
just verify

# Run test automation (dry-run on labs directory)
just test

# Run automation with copilot backend in dry-run
just automate:copilot:dry

# Run automation with claude backend in dry-run
just automate:claude:dry

# Run custom automation with specific directory
just automate:custom
```

## Log-Based Verification

**Log files** are the primary source of verification:

```bash
# View latest log
just logs

# Search for errors in logs
just logs:errors
```

All operations log to:
- Main log: `logs/automation_${TIMESTAMP}.log`
- Repository log: `logs/${repo_name}_${TIMESTAMP}.log`

**Log content includes:**
- Operation timestamps
- Function entry/exit points
- State changes (branch creation, worktree setup)
- Error messages with context
- Success confirmations

See `lib/config.sh` lines 137-147 for logging functions:
```bash
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$MAIN_LOG"
}

log_error() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $*" | tee -a "$MAIN_LOG" >&2
}

log_success() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] SUCCESS: $*" | tee -a "$MAIN_LOG"
}
```

## Prerequisites Check Pattern

**Location:** `lib/task_processing.sh` lines 66-104

**Pattern:**
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

  # Check if gh is authenticated
  if ! gh auth status &> /dev/null; then
    log_error "GitHub CLI is not authenticated. Run: gh auth login"
    exit 1
  fi

  # ... more checks ...

  log_success "Prerequisites check passed"
}
```

**What's tested:**
- Git installed and usable
- GitHub CLI installed and authenticated
- LLM CLI installed
- AI backend available (Copilot or Claude)

**Return codes:**
- Exit 1: Hard failure (missing required tool)
- Return 0: Success (all prerequisites met)
- Return 2: Soft failure (backend not available, fallback to markers)

## Backend Availability Testing

**Pattern** (see `lib/ai_backends.sh` lines 124-148):

```bash
check_ai_backend() {
  case "$AI_BACKEND" in
    claude)
      if ! command -v claude &> /dev/null; then
        log_error "Claude Code CLI is not installed"
        return 1
      fi
      log "AI Backend: Claude Code CLI (model: $AI_MODEL)"
      ;;
    copilot)
      if ! command -v copilot &> /dev/null; then
        log "Copilot CLI not available - will create task markers for manual implementation"
        return 2  # Return 2 to indicate "soft" failure (fallback mode)
      fi
      log "AI Backend: GitHub Copilot CLI (model: $AI_MODEL)"
      ;;
    *)
      log_error "Unknown AI backend: $AI_BACKEND"
      return 1
      ;;
  esac
  return 0
}
```

Return codes:
- 0 = backend available
- 1 = backend required but missing (hard failure)
- 2 = copilot not available but copilot mode (soft failure, create markers)

## Fallback Testing

**LLM parsing fallback** (see `lib/task_processing.sh` lines 135-157):

If LLM service fails, falls back to regex parsing:
```bash
local parsed_tasks=$(echo "$prompt" | llm -m gpt-4o-mini 2>/dev/null || echo "")

# Fallback to simple parsing if LLM fails
if [[ -z "$parsed_tasks" ]]; then
  log "LLM parsing failed, falling back to simple regex parsing"
  local tasks=()
  while IFS= read -r line; do
    if [[ "$line" =~ ^([[:space:]]*)-[[:space:]]\[[[:space:]]\] ]]; then
      local indent="${BASH_REMATCH[1]}"
      local content=$(echo "$line" | sed -E 's/^[[:space:]]*-[[:space:]]\[[[:space:]]\][[:space:]]*//')
      if [[ -n "$content" ]]; then
        tasks+=("${indent}${content}")
      fi
    fi
  done < "$tasks_file"
  printf '%s\n' "${tasks[@]}"
fi
```

## Test Coverage Gaps

**Areas without explicit testing:**

1. **Worktree operations:** No test for `create_worktree()` or `remove_worktree()` isolation
   - Files: `lib/git_utils.sh` lines 25-87
   - Risk: Worktree corruption on system crash
   - Current mitigation: Manual verification, fallback cleanup in `remove_worktree()`

2. **Git operations:** No test for:
   - Branch creation and deletion
   - Remote detection
   - Commit message generation
   - Files: `lib/git_utils.sh`, `lib/task_processing.sh` lines 200-233

3. **AI backend integration:** No test for:
   - Copilot CLI behavior with various flags
   - Claude CLI with different permission modes
   - Prompt template correctness
   - Files: `lib/ai_backends.sh`, `lib/task_processing.sh` lines 286-296

4. **PR creation:** No test for:
   - GitHub API connectivity
   - PR body formatting
   - Task list rendering in PR description
   - Files: `lib/task_processing.sh` lines 345-458

5. **Specification loading:** No test for:
   - Large file truncation (100KB limit)
   - Path resolution (absolute, relative, ./)
   - Missing file handling
   - Files: `lib/task_processing.sh` lines 27-63

## Test Configuration

**Dry-run flag location:**
- `lib/config.sh` line 12: `DRY_RUN=false` default
- `lib/config.sh` lines 62-64: argument parsing for `--dry-run`

**Test execution flags:**
- `--dry-run`: Enable dry-run mode
- `--backend copilot|claude`: Select AI backend for testing
- `--root DIR`: Specify test repository directory

**Example commands:**
```bash
# Test with copilot backend
./run_copilot_automation.sh --backend copilot --dry-run

# Test with claude backend
./run_copilot_automation.sh --backend claude --dry-run

# Test on specific directory
./run_copilot_automation.sh --root /path/to/test/repo --dry-run
```

## Log Cleanup

**Command:**
```bash
just clean
```

**What it does** (see `.mise.toml` lines 54-60):
```bash
cd logs
ls -t automation_*.log 2>/dev/null | tail -n +11 | xargs rm -f
```

Keeps last 10 log files, removes older ones.

## Manual Workflow Testing

**Recommended test sequence:**

1. Run verification:
   ```bash
   just verify
   ```

2. Run dry-run test on your own repository:
   ```bash
   ./run_copilot_automation.sh --dry-run --backend copilot
   ```

3. Check logs for errors:
   ```bash
   just logs:errors
   ```

4. Review log output:
   ```bash
   just logs
   ```

5. If successful, run full workflow without dry-run:
   ```bash
   ./run_copilot_automation.sh --backend copilot --create-pr
   ```

## Integration Points

**External service testing:**

GitHub CLI authentication:
```bash
gh auth status
```

LLM CLI availability:
```bash
llm --version
```

AI backend availability:
```bash
copilot --version  # GitHub Copilot
claude --version   # Claude Code CLI
```

---

*Testing analysis: 2026-02-01*
