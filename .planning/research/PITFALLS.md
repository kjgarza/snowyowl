# Pitfalls Research

**Domain:** Bash automation for CLI integration and git worktree management
**Researched:** 2026-02-01
**Confidence:** HIGH

## Critical Pitfalls

### Pitfall 1: Worktree Reference Leaks from Manual Deletion

**What goes wrong:**
Manually deleting worktree directories (via `rm -rf`) without using `git worktree remove` leaves stale references in `.git/worktrees/`, causing "already exists" errors on subsequent worktree creation attempts and preventing branch checkouts.

**Why it happens:**
Git maintains metadata in `.git/worktrees/` that tracks active worktrees. The directory deletion removes the files but not the git metadata, creating an inconsistent state. Developers instinctively use `rm -rf` for cleanup without realizing git needs to update its internal state.

**How to avoid:**
1. Always use `git worktree remove <path>` before deleting directories
2. Use `--force` flag when removing worktrees with uncommitted changes
3. Implement cleanup functions that call `git worktree prune` after removal
4. Add trap handlers to ensure cleanup runs even on script failure
5. Never rely on manual file deletion for worktree cleanup

**Warning signs:**
- Error: "fatal: '<path>' already exists"
- Error: "fatal: '<branch>' is already checked out at '<path>'"
- `git worktree list` shows paths that don't exist on disk
- Worktree creation succeeds but branch checkout fails

**Phase to address:**
Phase 4: Worktree Management - Implement robust cleanup with prune

**Recovery cost:** LOW - `git worktree prune` removes stale references

**Code pattern:**
```bash
# WRONG
rm -rf "$worktree_path"

# RIGHT
git worktree remove "$worktree_path" --force
git worktree prune
```

---

### Pitfall 2: Same Branch Checkout Across Multiple Worktrees

**What goes wrong:**
Attempting to checkout the same branch in multiple worktrees fails with "already checked out" errors. This breaks GSD integration when multiple phases try to use the same feature branch, or when a previous automation run left a branch checked out.

**Why it happens:**
Git prevents the same branch from being checked out in multiple worktrees simultaneously to avoid conflicting commits. The SnowyOwl GSD integration creates timestamped branches, but if branch creation logic fails or is interrupted, the script may attempt to reuse an existing branch name.

**How to avoid:**
1. Always create unique branch names with timestamps or UUIDs
2. Check if branch exists before creating worktree: `git show-ref --verify refs/heads/<branch>`
3. Force-delete branches before creating worktrees if needed
4. Use `git worktree list` to detect if branch is already checked out
5. Implement branch name collision detection early in workflow

**Warning signs:**
- Error: "fatal: '<branch>' is already checked out at '<path>'"
- Worktree creation succeeds but branch checkout fails
- Same branch appears twice in `git worktree list`

**Phase to address:**
Phase 3: GSD Scanner - Add branch conflict detection before worktree creation

**Recovery cost:** LOW - Remove conflicting worktree or rename branch

**Code pattern:**
```bash
# Check if branch is already checked out
if git worktree list | grep -q "$branch_name"; then
  log_error "Branch $branch_name already checked out in another worktree"
  return 1
fi

# Create unique branch names
branch="snowyowl-gsd-$(date +%Y%m%d-%H%M%S)-$$"
```

---

### Pitfall 3: Race Conditions in Parallel Execution Without File Locking

**What goes wrong:**
When running multiple repository automations in parallel, concurrent access to shared resources (log files, worktree directories, git operations) causes data corruption, duplicate work, or failed operations. Two processes might attempt to create the same worktree simultaneously or write to the same log file.

**Why it happens:**
Bash scripts execute independently without coordination. The GSD plan specifies `GSD_MAX_PARALLEL=2`, meaning two repos can execute simultaneously. Without explicit locking, they can conflict on shared filesystem resources or git operations.

**How to avoid:**
1. Use `flock` (file locking) for all critical sections accessing shared resources
2. Create per-repository lock files before processing: `/tmp/snowyowl-lock-<repo>.lock`
3. Use `-n` (non-blocking) flag with flock to fail fast on lock conflicts
4. Implement timeout mechanisms to prevent deadlocks
5. Ensure worktree paths are unique per repository (current code does this)
6. Use atomic operations where possible (e.g., `mkdir` for lock creation)

**Warning signs:**
- Corrupted or interleaved log file entries
- "Device or resource busy" errors
- Duplicate worktree creation attempts
- Git errors about locked refs
- Processes hanging indefinitely

**Phase to address:**
Phase 5: Parallel Execution - Implement flock-based locking for critical sections

**Recovery cost:** HIGH - Data corruption may require manual investigation

**Code pattern:**
```bash
# Create lock file with flock
exec 200>/tmp/snowyowl-lock-${repo_name}.lock
if ! flock -n 200; then
  log_error "Repository $repo_name is already being processed"
  exit 1
fi
# ... do work ...
flock -u 200
```

---

### Pitfall 4: Unvalidated JSON Parsing Leading to Silent Failures

**What goes wrong:**
The GSD integration relies on `.planning/config.json` for critical settings like `mode: "yolo"`. If JSON is malformed or missing required fields, `jq` may return empty strings or `null`, which bash interprets as success, causing the script to proceed with wrong assumptions (e.g., treating missing mode as interactive mode).

**Why it happens:**
Bash treats empty strings as successful command execution. The existing plan uses `jq -r '.mode // "interactive"'`, but if the JSON file is malformed, `jq` may fail silently or return unexpected values. Bash's weak typing doesn't distinguish between empty string, null, and actual values.

**How to avoid:**
1. Always check `jq` exit codes before using output: `jq ... || return 1`
2. Validate required fields exist and have expected values
3. Use strict error handling: `set -euo pipefail`
4. Explicitly check for required values: `[ "$mode" = "yolo" ] || return 1`
5. Validate JSON schema before processing (use `jq` schema validation)
6. Log what was parsed for debugging

**Warning signs:**
- Scripts proceed when config file is missing
- Variables contain empty strings instead of expected values
- Mode-dependent behavior doesn't trigger
- `jq` errors printed but script continues
- Unexpected fallback values used

**Phase to address:**
Phase 3: GSD Scanner - Add robust JSON validation with error checking

**Recovery cost:** MEDIUM - May execute wrong mode, need to abort and retry

**Code pattern:**
```bash
# WRONG
mode=$(jq -r '.mode // "interactive"' "$config" 2>/dev/null)

# RIGHT
if ! mode=$(jq -r '.mode // empty' "$config" 2>/dev/null); then
  log_error "Failed to parse config.json in $repo"
  return 1
fi

if [ -z "$mode" ]; then
  log_error "Mode not specified in config.json"
  return 1
fi

if [ "$mode" != "yolo" ]; then
  log_warn "GSD mode is '$mode', skipping (must be 'yolo')"
  return 1
fi
```

---

### Pitfall 5: Missing Exit Code Checks for CLI Command Failures

**What goes wrong:**
When invoking external CLI tools like `claude -p "/gsd:execute-phase"`, the script may continue execution even if the command fails, leading to incomplete phase execution, missing SUMMARY.md files, and incorrect "ready" state detection.

**Why it happens:**
Bash continues execution after failed commands unless `set -e` is enabled, and even with `set -e`, commands in pipelines or conditionals may not trigger script termination. The GSD plan shows `claude` commands without explicit exit code checking, which can lead to false positives.

**How to avoid:**
1. Use `set -euo pipefail` at the top of every script
2. Explicitly check exit codes for all critical operations: `command || return 1`
3. Use `if ! command; then` for operations that must succeed
4. Log the exit code for debugging: `exit_code=$?`
5. Distinguish between timeout (resume-able) vs hard failure (abort)
6. Save command output and errors to log files for investigation

**Warning signs:**
- Scripts report success despite visible errors in logs
- SUMMARY.md files missing after "successful" execution
- Phase marked ready when it shouldn't be
- Silent failures during overnight runs
- PRs created with incomplete work

**Phase to address:**
Phase 4: GSD Runner - Add comprehensive exit code checking and error handling

**Recovery cost:** HIGH - Incomplete work requires manual investigation and re-execution

**Code pattern:**
```bash
# WRONG
claude -p "/gsd:execute-phase $phase_num"
# ... continue regardless of outcome ...

# RIGHT
if ! claude -p "/gsd:execute-phase $phase_num" \
    --dangerously-skip-permissions \
    --max-turns "$GSD_MAX_TURNS" >> "$log" 2>&1; then
  exit_code=$?
  log_error "Phase $phase_num failed with exit code $exit_code"

  # Try to save state on timeout (exit code 124)
  if [ $exit_code -eq 124 ]; then
    claude -p "/gsd:pause-work" || true
  fi

  return 1
fi
```

---

### Pitfall 6: File System Scanning Performance on Large Repositories

**What goes wrong:**
Scanning deeply nested repository structures with many files causes significant slowdowns. Using inefficient patterns like `find` without limits, invoking `wc -l` in loops, or repeatedly checking file existence can make the scanner take minutes instead of seconds.

**Why it happens:**
The GSD scanner needs to inspect `.planning/phases/*/` directories for PLAN.md and SUMMARY.md files across all repositories. Without optimization, this involves many filesystem operations. The existing code uses pattern matching and loops that may execute hundreds of file existence checks.

**How to avoid:**
1. Use `find` with `-maxdepth` to limit recursion depth
2. Use `-xdev` flag to avoid crossing filesystem boundaries
3. Batch file operations instead of looping over individual files
4. Cache results of expensive operations (e.g., file counts)
5. Use bash globbing instead of `ls` or `find` where possible
6. Skip hidden directories and node_modules type directories early

**Warning signs:**
- Scanner taking >5 seconds per repository
- High CPU usage during scanning
- Scripts timing out on large codebases
- `find` or `ls` commands appearing in strace output repeatedly

**Phase to address:**
Phase 3: GSD Scanner - Optimize file system traversal patterns

**Recovery cost:** LOW - Performance issue only, no data corruption

**Code pattern:**
```bash
# WRONG - spawns many subshells
for file in $(find "$phase_dir" -name "*-PLAN.md"); do
  count=$((count + 1))
done

# RIGHT - use bash built-ins
shopt -s nullglob
plan_files=("$phase_dir"/*-PLAN.md)
plan_count=${#plan_files[@]}

# BETTER - count efficiently
plan_count=$(find "$phase_dir" -maxdepth 1 -name "*-PLAN.md" -type f | wc -l)
```

---

## Technical Debt Patterns

Shortcuts that seem reasonable but create long-term problems.

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Using `rm -rf` instead of `git worktree remove` | Faster cleanup, fewer lines of code | Stale git references accumulate, future worktree operations fail | Never - always use git commands |
| Skipping file locking for "quick prototypes" | Simpler code, no flock dependencies | Race conditions in parallel execution, data corruption | Only for single-threaded execution |
| Using `set -e` without `set -u` and `set -o pipefail` | Catches some errors | Undefined variables expand to empty strings, pipeline failures ignored | Never - always use full set |
| Parsing JSON without checking jq exit codes | Fewer lines, assumes valid input | Silent failures when JSON malformed, wrong config used | Never in production code |
| Hard-coding timeouts instead of making configurable | Quick to implement | Can't adjust for different workloads without code changes | Early prototypes only, must refactor |
| Using sleep intervals instead of exponential backoff | Simple retry logic | Wastes time on quick transient failures, hammers failing services | Never for external API calls |

## Integration Gotchas

Common mistakes when connecting to external services.

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| `claude` CLI | Not checking if command exists before use | Use `command -v claude &>/dev/null` in prerequisites |
| `gh` CLI | Assuming authentication without checking | Run `gh auth status` in prerequisites, fail early |
| `jq` JSON parsing | Not handling missing/malformed JSON | Check exit codes, validate schema, provide defaults |
| Git operations in worktrees | Running git commands from wrong directory | Always `cd` to worktree before git operations, or use `-C` flag |
| LLM API calls (via `llm` CLI) | Not handling rate limits or failures | Implement retry with exponential backoff, fallback to simpler parsing |
| GitHub PR creation | Creating PR immediately after push | Wait 30 seconds for GitHub to process push (existing code does this) |

## Performance Traps

Patterns that work at small scale but fail as usage grows.

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Spawning subshells in loops | Slow execution, high CPU | Use bash built-ins, arrays, and pipes | >100 iterations |
| Not using `flock -n` (blocking locks) | Scripts hang waiting for locks | Use non-blocking locks, implement timeouts | Concurrent executions |
| Logging every line to same file without buffering | I/O bottleneck, log corruption | Use separate log files per repo, buffer writes | >10 parallel processes |
| Calling external commands in inner loops | Slow execution, many process forks | Move external calls outside loops, batch operations | >50 loop iterations |
| Not pruning old worktrees | Disk space exhaustion | Implement cleanup in trap handlers, periodic pruning | >20 worktrees |
| Rescanning entire directory tree on each check | Slow readiness detection | Cache scan results, only rescan changed directories | >50 repositories |

## Security Mistakes

Domain-specific security issues beyond general web security.

| Mistake | Risk | Prevention |
|---------|------|------------|
| Running `claude` with `--dangerously-skip-permissions` blindly | LLM could access/modify any file | Restrict to worktrees only, use git hooks to validate changes |
| Storing credentials in environment variables | Credential exposure in logs, process lists | Use credential managers, avoid echoing env vars |
| Not validating branch names before git operations | Command injection via branch names | Sanitize branch names, use allow-lists for prefixes |
| Passing unsanitized user input to shell commands | Command injection | Quote all variables, avoid `eval`, validate input |
| World-readable lock files in /tmp | Information disclosure | Use restrictive permissions (600) on lock files |
| Not validating file paths from config | Path traversal attacks | Use absolute paths, validate against allow-list |

## UX Pitfalls

Common user experience mistakes in this domain.

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| No progress indication during long-running operations | User doesn't know if script is hung or working | Log to stderr with timestamps, show phase progress |
| Cryptic error messages without context | User can't debug failures | Include repo name, phase number, file paths in errors |
| Not distinguishing between skipped vs failed repos | User can't tell what needs action | Clear status codes: READY, SKIPPED, FAILED, COMPLETED |
| No dry-run mode for testing | User afraid to run automation | Implement `--dry-run` flag (existing code has this) |
| Logs buried in obscure locations | User can't find error details | Print log file path at start and end of execution |
| No summary report at the end | User must manually inspect each repo | Generate summary table: repo, phases executed, status, PR link |

## "Looks Done But Isn't" Checklist

Things that appear complete but are missing critical pieces.

- [ ] **Phase execution:** Often missing exit code check - verify command succeeded and SUMMARY.md exists
- [ ] **Worktree cleanup:** Often missing prune step - verify `git worktree prune` called after removal
- [ ] **JSON parsing:** Often missing validation - verify jq exit code checked and required fields present
- [ ] **File locking:** Often missing timeout - verify flock has timeout and cleanup in trap handler
- [ ] **Branch creation:** Often missing uniqueness check - verify branch doesn't exist and isn't checked out elsewhere
- [ ] **Log rotation:** Often missing size limits - verify logs don't grow unbounded (implement rotation)
- [ ] **Error recovery:** Often missing pause-work on timeout - verify state saved for resumption
- [ ] **Prerequisites:** Often missing version checks - verify tools are correct versions, not just present

## Recovery Strategies

When pitfalls occur despite prevention, how to recover.

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Stale worktree references | LOW | Run `git worktree prune`, remove stale directories manually |
| Branch checkout conflicts | LOW | List worktrees with `git worktree list`, remove conflicting one |
| Lock file deadlock | LOW | Identify PID in lock file, kill if stale, remove lock file |
| Corrupted JSON config | MEDIUM | Restore from git history or template, validate with jq |
| Incomplete phase execution | HIGH | Check SUMMARY.md exists, if not re-run phase, inspect logs for errors |
| Race condition data corruption | HIGH | Identify affected resources, restore from git, implement locking |
| Failed PR creation | LOW | Manually create PR with `gh pr create`, use SUMMARY.md for body |
| Disk space exhaustion from worktrees | MEDIUM | Prune all worktrees, implement cleanup policy, monitor disk usage |

## Pitfall-to-Phase Mapping

How roadmap phases should address these pitfalls.

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| Worktree reference leaks | Phase 4 (Worktree Management) | Test cleanup leaves no stale refs in `git worktree list` |
| Same branch checkout | Phase 3 (GSD Scanner) | Test scanner detects and prevents branch conflicts |
| Race conditions | Phase 5 (Parallel Execution) | Test concurrent execution with flock, verify no corruption |
| JSON parsing failures | Phase 3 (GSD Scanner) | Test with malformed JSON, verify errors caught early |
| Missing exit code checks | Phase 4 (GSD Runner) | Test with failing commands, verify script aborts |
| File system performance | Phase 3 (GSD Scanner) | Benchmark scanner on large repo (>50 phases), verify <2s |
| Lock file deadlocks | Phase 5 (Parallel Execution) | Test lock timeout, verify cleanup on script interruption |
| Missing SUMMARY.md detection | Phase 6 (Advance Logic) | Test phase marked incomplete when SUMMARY.md missing |

## Sources

**Bash Automation Best Practices:**
- [Bash Scripting: Best Practices And Pitfalls](https://www.paulserban.eu/blog/post/bash-scripting-best-practices/)
- [BashPitfalls - Greg's Wiki](https://mywiki.wooledge.org/BashPitfalls)
- [Top 5 Bash Pitfalls That Newbies Keep Getting Wrong](https://dev.to/beta_shorts_7f1150259405a/top-5-bash-pitfalls-that-newbies-keep-getting-wrong-5337)
- [Common shell script mistakes](http://www.pixelbeat.org/programming/shell_script_mistakes.html)

**Git Worktree Gotchas:**
- [Git Worktree: Pros, Cons, and the Gotchas Worth Knowing](https://joshtune.com/posts/git-worktree-pros-cons/)
- [Escaping Stash and Checkout Hell: The Ultimate Guide to Git Worktree](https://agmazon.com/blog/articles/technology/202601/git-worktree-guide-en.html)
- [Git Worktree Overview](https://gist.github.com/GeorgeLyon/ff5a42cb24c1de09e4139266a7689543)

**File Locking and Race Conditions:**
- [Lock your script (against parallel execution) - Bash Hackers Wiki](https://bash-hackers.gabe565.com/howto/mutex/)
- [Safe locking mechanism in bash](http://wresch.github.io/2013/06/12/bash-safe-locking-mechanism.html)
- [Lock Files in bash](https://grahamwatts.co.uk/blog/2024/10/09/lock-files-in-bash/)
- [Multiprocess Errors in Bash Shell](https://www.johndcook.com/blog/2024/02/12/avoiding-multiprocessing-errors-in-bash-shell/)

**Error Handling and Retry Patterns:**
- [Learn Bash error handling by example](https://www.redhat.com/en/blog/bash-error-handling)
- [12 Bash Scripts to Implement Intelligent Retry, Backoff & Error Recovery](https://medium.com/@obaff/12-bash-scripts-to-implement-intelligent-retry-backoff-error-recovery-a02ab682baae)
- [Writing Bash Scripts Like A Pro - Part 2 - Error Handling](https://dev.to/unfor19/writing-bash-scripts-like-a-pro-part-2-error-handling-46ff)
- [Exponential Backoff in Bash](https://coderwall.com/p/--eiqg/exponential-backoff-in-bash)

**Project-Specific Context:**
- SnowyOwl existing codebase analysis (/Users/kristiangarza/aves/snowyowl/)
- SnowyOwl GSD Integration Plan V3
- Existing worktree management patterns in lib/git_utils.sh
- Existing task processing patterns in lib/task_processing.sh

---
*Pitfalls research for: Bash automation and CLI integration for SnowyOwl GSD*
*Researched: 2026-02-01*
