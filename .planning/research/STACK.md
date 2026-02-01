# Stack Research

**Domain:** Bash-based automation systems with CLI integration
**Researched:** 2026-02-01
**Confidence:** HIGH

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| Bash | 5.0+ | Core automation scripting | Industry standard for Unix automation; strong support for process control, file operations, and tool orchestration. Native to all modern Unix systems. |
| Git Worktrees | 2.5+ | Isolated execution environments | Provides filesystem-level isolation for parallel task execution without repository cloning overhead. Native git feature, no external dependencies. |
| ShellCheck | 0.10.0+ | Static analysis | De facto standard for bash linting; catches common pitfalls and enforces best practices. Integrates seamlessly with CI/CD pipelines. |

### CLI Tool Integration

| Tool | Version | Purpose | When to Use |
|------|---------|---------|-------------|
| GitHub CLI (gh) | 2.40+ | PR creation and GitHub operations | Required for automated PR workflows. Provides authenticated GitHub API access without manual token management. |
| Claude Code CLI | Latest | AI-powered code generation | Primary AI backend for intelligent task processing. Supports headless mode via `-p` flag for non-interactive automation. |
| GitHub Copilot CLI | Latest | Alternative AI backend | Secondary AI backend option. Provides `--allow-all-tools` and `--deny-tool` flags for fine-grained tool control in automation contexts. |

### Supporting Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| ripgrep (rg) | Fast file content searching | 10-100x faster than grep for large codebases; use for .planning/ directory scanning |
| find (GNU) | Filesystem traversal | Use with `-quit` flag for early termination when checking file existence |
| jq | JSON parsing | Essential for parsing CLI tool outputs (gh, copilot, claude) in structured format |

## File System Scanning Strategy

### For GSD Mode Detection (Readiness Checks)

**Recommended:** Built-in bash `test` command with `-e` and `-f` operators
```bash
# Fast, no-fork existence check
if [[ -e ".planning/phases/01-foundation/READY.md" ]]; then
  # Phase is ready
fi
```

**Why:**
- Zero external process spawning (fastest possible)
- Native bash construct (always available)
- Sufficient for simple presence detection
- Confidence: **HIGH** - [Multiple sources](https://linuxize.com/post/bash-check-if-file-exists/) confirm this is the standard approach

**NOT recommended for readiness checks:**
- `find` - Overkill for single file checks; spawns subprocess
- `ls` - Brittle, subject to globbing issues
- Python/external scripts - Defeats "no Claude invocations" constraint

### For .planning/ Directory Scanning (Discovery)

**Recommended:** Bash globbing with `nullglob` option
```bash
shopt -s nullglob
phases=(.planning/phases/*/)
if [[ ${#phases[@]} -eq 0 ]]; then
  # No phases found
fi
```

**Why:**
- Built-in shell feature (no subprocess)
- Handles empty results cleanly with `nullglob`
- Fast for single-directory scans
- Confidence: **HIGH** - [Search results](https://sqlpey.com/bash/robust-shell-glob-checking/) show this is the recommended pattern for 2025

**Alternative for complex/recursive scanning:** `find` with early termination
```bash
# Find any READY.md files (recursive)
find .planning/phases -name "READY.md" -quit
```
- Use when: Recursive search needed, performance still acceptable
- Confidence: **HIGH** - [Multiple sources](https://dmitry-antonyuk.medium.com/zsh-globbing-as-an-alternative-to-find-command-2ebf9da5cffe) confirm find is optimal for recursive cases

## Modular Architecture Patterns

### Library Organization

**Recommended Structure:**
```
lib/
├── config.sh          # Configuration and arg parsing
├── git_utils.sh       # Git operations (worktrees, commits, PRs)
├── ai_backends.sh     # CLI integration (claude, copilot)
├── task_processing.sh # TASKS.md parsing and execution
└── gsd_mode.sh        # NEW: GSD phase detection and execution
```

**Why:**
- Separate concerns by domain (config, git, AI, tasks)
- Each module ≈ 100-200 lines (maintainable size)
- Source with `source "$SCRIPT_DIR/lib/module.sh"`
- Confidence: **HIGH** - Based on [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html) and [modular design patterns](https://www.lost-in-it.com/posts/designing-modular-bash-functions-namespaces-library-patterns/)

### Module Sourcing Pattern

```bash
# Guard against double-sourcing
if [[ -n "${_GSD_MODE_LOADED:-}" ]]; then
  return 0
fi
readonly _GSD_MODE_LOADED=1

# Module code here
```

**Why:**
- Prevents duplicate function definitions
- Idempotent sourcing (safe to call multiple times)
- Confidence: **HIGH** - [Standard pattern](https://medium.com/mkdir-awesome/the-ultimate-guide-to-modularizing-bash-script-code-f4a4d53000c2) for bash libraries

### Naming Conventions

**Functions:**
- `gsd_detect_ready_phases()` - Public API (prefix with module name)
- `_gsd_parse_phase_file()` - Private helpers (prefix with underscore)

**Variables:**
- `CONSTANTS_IN_UPPERCASE` - Readonly values
- `runtime_vars_in_snake_case` - Mutable state
- `local function_vars` - Always use `local` keyword

**Why:**
- Clear public/private distinction
- Prevents namespace collisions
- Confidence: **HIGH** - Consistent across [multiple](https://www.lost-in-it.com/posts/designing-modular-bash-functions-namespaces-library-patterns/) [sources](https://linuxcommand.org/lc3_adv_standards.php)

## Error Handling

### Defensive Scripting Pattern

**Required at script start:**
```bash
set -euo pipefail
```

**What it does:**
- `-e` (errexit): Exit immediately if any command fails
- `-u` (nounset): Treat unset variables as errors
- `-o pipefail`: Fail on any pipe component failure (not just last)

**Why:**
- Prevents cascading failures
- Makes bugs visible early
- Standard practice for production bash
- Confidence: **HIGH** - [Widely documented](https://dev.to/rociogarciavf/how-to-handle-errors-in-bash-scripts-in-2025-3bo) as best practice for 2025

### Cleanup with trap

```bash
cleanup() {
  # Cleanup code
  [[ -n "${temp_file:-}" ]] && rm -f "$temp_file"
}
trap cleanup EXIT ERR
```

**Why:**
- Guarantees cleanup even on error/interrupt
- Essential for temp files, locks, background processes
- Confidence: **HIGH** - [Standard pattern](https://www.linuxbash.sh/post/bash-error-handling-and-exception-management)

## CLI Integration Patterns

### Claude Code CLI (Headless Mode)

**For GSD `/gsd:*` command invocation:**
```bash
claude -p "$(cat phase_prompt.txt)" \
  --allowedTools "Read,Write,Edit,Bash,Grep,Glob" \
  --permission-mode acceptEdits \
  --model claude-sonnet-4-5 \
  --output-format stream-json >> "$phase_log" 2>&1
```

**Key flags for automation:**
- `-p`: Headless prompt (non-interactive)
- `--allowedTools`: Whitelist tools (security)
- `--permission-mode acceptEdits`: Auto-accept file edits
- `--output-format stream-json`: Structured output for parsing

**Why:**
- Designed for CI/CD and automation pipelines
- No interactive prompts (blocks execution)
- Structured output parseable with jq
- Confidence: **HIGH** - [Official documentation](https://code.claude.com/docs/en/cli-reference) from January 2026 update

### GitHub Copilot CLI (Programmatic Mode)

**Alternative backend:**
```bash
copilot --allow-all-tools \
  --deny-tool "shell(rm)" \
  --model gpt-4o \
  < prompt.txt >> "$phase_log" 2>&1
```

**Key flags:**
- `--allow-all-tools`: Enable all capabilities
- `--deny-tool`: Blocklist dangerous operations
- Stdin for prompt (vs `-p` flag)

**Why:**
- Programmatic mode added in 2025 for automation
- History exclusion keeps command history clean
- Tool filtering provides safety guardrails
- Confidence: **HIGH** - [GitHub Changelog](https://github.blog/changelog/2026-01-14-github-copilot-cli-enhanced-agents-context-management-and-new-ways-to-install/) confirms 2026 features

### Tool Availability Checking

```bash
check_cli_tool() {
  local tool="$1"
  if ! command -v "$tool" &> /dev/null; then
    log_error "$tool is not installed"
    return 1
  fi
  log "Found: $tool ($(command -v "$tool"))"
  return 0
}
```

**Why:**
- Early validation prevents mid-execution failures
- Clear error messages for missing dependencies
- Standard `command -v` pattern
- Confidence: **HIGH** - Universal bash pattern

## Mode Switching Architecture

### Detection Pattern

**File-based mode detection:**
```bash
detect_mode() {
  local repo_path="$1"

  # Priority 1: GSD mode if .planning/ exists
  if [[ -d "$repo_path/.planning" ]]; then
    echo "gsd"
    return 0
  fi

  # Priority 2: TASKS mode if TASKS.md exists
  if [[ -f "$repo_path/TASKS.md" ]]; then
    echo "tasks"
    return 0
  fi

  # No mode detected
  echo "none"
  return 1
}
```

**Why:**
- Simple, deterministic file-based detection
- No configuration files or state to manage
- Fast (just filesystem checks)
- Priority ordering prevents ambiguity
- Confidence: **HIGH** - Follows Unix philosophy of filesystem as database

### Mode Dispatcher Pattern

```bash
process_repository() {
  local repo_path="$1"
  local mode=$(detect_mode "$repo_path")

  case "$mode" in
    gsd)
      process_gsd_phases "$repo_path"
      ;;
    tasks)
      process_tasks_md "$repo_path"
      ;;
    none)
      log "Skipping $(basename "$repo_path") - no mode detected"
      ;;
    *)
      log_error "Unknown mode: $mode"
      return 1
      ;;
  esac
}
```

**Why:**
- Clean separation of concerns
- Easy to extend with new modes
- Explicit handling of all cases
- Confidence: **HIGH** - Standard dispatch pattern

## Validation & Testing

### Static Analysis

**ShellCheck integration:**
```bash
# In CI or pre-commit hook
shellcheck -x lib/*.sh run_*.sh
```

**Why:**
- Catches 80% of common bash bugs
- Enforces style consistency
- Free, fast, zero dependencies
- Confidence: **HIGH** - [Industry standard](https://www.shellcheck.net/) for bash quality

### Runtime Validation

**Input validation pattern:**
```bash
validate_phase_dir() {
  local phase_dir="$1"

  # Required files
  local required=("SPEC.md" "READY.md")
  for file in "${required[@]}"; do
    if [[ ! -f "$phase_dir/$file" ]]; then
      log_error "Missing required file: $file"
      return 1
    fi
  done

  return 0
}
```

**Why:**
- Fail fast on invalid inputs
- Clear error messages
- Prevents partial execution
- Confidence: **HIGH** - [Standard validation approach](https://www.mayhemcode.com/2025/09/bash-script-validation-file-testing.html)

## Installation

### Core Requirements
```bash
# Verify Bash version
bash --version | head -1  # Should show 5.0 or higher

# Install ShellCheck
brew install shellcheck  # macOS
apt-get install shellcheck  # Debian/Ubuntu

# Install GitHub CLI
brew install gh  # macOS
# See https://github.com/cli/cli for other platforms

# Install jq
brew install jq  # macOS
apt-get install jq  # Debian/Ubuntu

# Install ripgrep (optional but recommended)
brew install ripgrep  # macOS
apt-get install ripgrep  # Debian/Ubuntu
```

### AI CLI Tools
```bash
# Claude Code CLI
curl -fsSL https://claude.ai/install.sh | bash

# GitHub Copilot CLI (requires GitHub Copilot subscription)
gh extension install github/gh-copilot
```

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| Bash 5.0+ | Python | When complex data structures (beyond arrays) are needed; when extensive JSON manipulation required |
| Git worktrees | Docker containers | When stronger isolation required; when system dependencies conflict across tasks |
| ShellCheck | Custom lint rules | Never - ShellCheck covers all common cases |
| Bash globbing | `find` command | When recursive directory traversal needed; when complex file filtering required |
| `[[ -e file ]]` | Python `os.path.exists()` | When already using Python for other logic; defeats bash-only constraint |
| Claude Code CLI | LangChain/LlamaIndex | When building multi-step reasoning agents; overkill for single-task automation |

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| `ls` for file iteration | Breaks on spaces/special characters; spawns subprocess | Bash globbing: `for file in *.txt` |
| Backticks `` `cmd` `` | Deprecated syntax; nesting is painful | `$(cmd)` syntax |
| `eval` | Security nightmare; hard to debug | Proper quoting and parameter expansion |
| Global variables everywhere | Namespace pollution; hard to reason about | `local` variables in functions; readonly for constants |
| `cd` without error checking | Silently continues in wrong directory if cd fails | `cd "$dir" || return 1` |
| Parsing `ls` output | Fragile; breaks on edge cases | Use `find` with `-print0` or globbing |
| `set -x` in production | Leaks sensitive data to logs | Structured logging with log levels |
| `sleep` for synchronization | Race conditions; arbitrary delays | Proper wait loops with timeouts |
| `source` without guards | Double-loading functions; side effects | Guard variables (`_MODULE_LOADED`) |

**Confidence:** HIGH - All items documented in [BashPitfalls](https://mywiki.wooledge.org/BashPitfalls) and [common mistakes guides](https://www.shell-tips.com/bash/pitfalls/)

## Stack Patterns by Variant

**If running in CI/CD environment:**
- Use `--output-format stream-json` for all CLI tools
- Parse with `jq` for structured error reporting
- Set stricter tool allowlists for security
- Because: CI requires parseable output and stronger security boundaries

**If running locally (developer machine):**
- Allow interactive mode fallback for debugging
- Preserve worktrees for manual inspection (`CLEANUP_WORKTREES=false`)
- Use color output for better readability
- Because: Developers need flexibility and debugging capabilities

**If processing large codebases (>10k files):**
- Use `ripgrep` instead of `grep` for content search
- Implement progress indicators for long-running operations
- Consider parallel phase execution with background jobs
- Because: Performance matters at scale; user feedback prevents timeout anxiety

## Version Compatibility

| Package | Compatible With | Notes |
|---------|-----------------|-------|
| Bash 5.0+ | Git 2.5+ | Git worktrees require Git 2.5; earlier versions lack worktree support |
| Claude CLI (2026) | Bash 4.0+ | Headless flags require recent release; check with `claude --version` |
| GitHub Copilot CLI | gh 2.40+ | Requires `gh` for authentication; older versions may lack programmatic mode |
| ShellCheck 0.10.0 | Bash 5.0 | Full coverage of Bash 5.0 features; older ShellCheck versions miss new syntax |

## Sources

### High Confidence (Official Documentation & Context7)
- [Claude Code CLI Documentation](https://code.claude.com/docs/en/cli-reference) — Headless mode flags, authentication
- [GitHub Copilot CLI Changelog (Jan 2026)](https://github.blog/changelog/2026-01-14-github-copilot-cli-enhanced-agents-context-management-and-new-ways-to-install/) — Programmatic mode, MCP integration
- [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html) — Naming conventions, structure
- [ShellCheck Official Site](https://www.shellcheck.net/) — Static analysis capabilities
- [Bash 5.0 Release Notes](https://lwn.net/Articles/776223/) — New features, compatibility

### Medium Confidence (Expert Blogs & Technical Articles)
- [Designing Modular Bash (Lost in IT, 2025)](https://www.lost-in-it.com/posts/designing-modular-bash-functions-namespaces-library-patterns/) — Module patterns, namespacing
- [Modularizing Bash Script Code (Medium, 2025)](https://medium.com/mkdir-awesome/the-ultimate-guide-to-modularizing-bash-script-code-f4a4d53000c2) — Sourcing patterns, structure
- [Error Handling in Bash 2025 (DEV Community)](https://dev.to/rociogarciavf/how-to-handle-errors-in-bash-scripts-in-2025-3bo) — set -euo pipefail, trap patterns
- [Bash File Existence Checking (Linuxize)](https://linuxize.com/post/bash-check-if-file-exists/) — Test operators, portability
- [Find vs Glob Performance (ZSH Globbing)](https://dmitry-antonyuk.medium.com/zsh-globbing-as-an-alternative-to-find-command-2ebf9da5cffe) — Performance comparison

### Community Wisdom (Cross-Referenced)
- [BashPitfalls (Greg's Wiki)](https://mywiki.wooledge.org/BashPitfalls) — Canonical anti-patterns reference
- [Top 10 Bash Pitfalls (Shell Tips)](https://www.shell-tips.com/bash/pitfalls/) — Common mistakes
- [Common Shell Script Mistakes (Pixelbeat)](http://www.pixelbeat.org/programming/shell_script_mistakes.html) — Historical context
- [Bash Validation Patterns (MayhemCode, Sept 2025)](https://www.mayhemcode.com/2025/09/bash-script-validation-file-testing.html) — Input validation

---
*Stack research for: Bash automation systems with CLI integration*
*Researched: 2026-02-01*
*Focus: GSD mode integration requirements for SnowyOwl*
