# Codebase Concerns

**Analysis Date:** 2026-02-01

## Tech Debt

**Unvalidated LLM API Calls:**
- Issue: Task parsing and branch slug generation rely on external LLM API calls (OpenAI) without input validation or rate limiting
- Files: `lib/task_processing.sh` (lines 107-157, 161-197)
- Impact: External API failures silently fallback to simple regex parsing, which may miss indented subtasks or produce malformed slugs. No timeout handling or retry logic.
- Fix approach: Implement timeout management (e.g., `timeout 30s llm ...`), add explicit error handling with user-facing messages, validate LLM output before use, add fallback logging

**Temporary File Cleanup:**
- Issue: `mktemp` creates files in system temp without guarantee of cleanup on script failure
- Files: `lib/ai_backends.sh` (line 77)
- Impact: Orphaned temporary prompt files may accumulate in `/tmp` if script exits abnormally
- Fix approach: Use trap to cleanup temp files on exit, or use automatic deletion temp file patterns

**Missing Error Recovery in Git Operations:**
- Issue: Git worktree operations use `--force` flag which can mask underlying problems
- Files: `lib/git_utils.sh` (line 70)
- Impact: Forced removal may delete valid work if worktree state becomes corrupted
- Fix approach: Add pre-flight checks before forcing removal, log reason for force flag usage, warn user before destructive operations

**Hardcoded Timeouts and Delays:**
- Issue: 30-second sleep between branch push and PR creation is hardcoded with no explanation
- Files: `lib/task_processing.sh` (line 405)
- Impact: GitHub API may not have synced branch by then, causing PR creation failures. Not configurable.
- Fix approach: Make timeout configurable via environment variable, add exponential backoff with max retries instead of fixed sleep, check branch existence before PR creation

## Known Bugs

**Subtask Indentation Inconsistency:**
- Symptoms: Mixed indentation handling - LLM parsing uses 2 spaces but indentation detection uses variable whitespace
- Files: `lib/task_processing.sh` (line 155), `run_copilot_automation.sh` (line 112)
- Trigger: Task files with 4-space indentation for subtasks may not be recognized as subtasks
- Workaround: Ensure TASKS.md uses consistent 2-space indentation for subtasks

**Empty Task Title Handling:**
- Symptoms: If extract_task_link returns a title with only pipes, branch slug generation produces invalid git branch names
- Files: `lib/task_processing.sh` (line 17-24, 186-193)
- Trigger: Markdown links with empty text `[](file.md)` or tasks that are pure whitespace
- Workaround: Validate task titles before passing to generate_branch_slug

**PR Creation Fails Silently in Some Cases:**
- Symptoms: PR creation may fail but script continues without clear indication
- Files: `lib/task_processing.sh` (line 437-444)
- Trigger: gh command network issues, invalid PR titles with special characters, branch already has PR
- Workaround: Check gh output and retry once

## Security Considerations

**Unquoted Variable Expansion in shell(rm) Deny:**
- Risk: `COPILOT_DENY_TOOLS` variable is passed unquoted to copilot, could cause injection if var contains special characters
- Files: `lib/ai_backends.sh` (line 82), `config.env` (line 40)
- Current mitigation: Hardcoded value "shell(rm)" limits exposure
- Recommendations: Quote the variable: `--deny-tool "$COPILOT_DENY_TOOLS"` and validate var value matches expected pattern

**AI Backend Prompt Injection:**
- Risk: Task titles and repo paths are embedded in prompts without escaping, could be exploited if task names contain prompt injection payloads
- Files: `lib/ai_backends.sh` (lines 17-68)
- Current mitigation: None - user-controlled task titles are passed directly to LLM
- Recommendations: Sanitize/escape task titles before embedding in prompts, add validation that task_title doesn't contain newlines or suspicious patterns

**Repository Path Traversal:**
- Risk: Task specification file paths loaded from TASKS.md could use `../` to escape repo bounds
- Files: `lib/task_processing.sh` (lines 29-63)
- Current mitigation: Full path resolution normalizes path but doesn't validate it stays within repo
- Recommendations: Validate resolved path is within repo root: `if [[ ! "$full_path" == "$repo_path"/* ]]`

**Cleartext Sensitive Data in Logs:**
- Risk: Repository names, branch names, task titles, and worktree paths are written to logs in cleartext
- Files: All modules write to `$repo_log` without filtering
- Current mitigation: Logs written to local filesystem only
- Recommendations: Add log sanitization, allow users to exclude sensitive patterns, consider symmetric encryption for sensitive logs

**No Authentication for Task Specifications:**
- Risk: Specification files are loaded and executed (via AI backend) without integrity verification
- Files: `lib/task_processing.sh` (lines 50-57)
- Current mitigation: File must exist and be readable, size-limited to 100KB
- Recommendations: Add checksum verification, sign specification files, validate file age

## Performance Bottlenecks

**Single Repository Sequential Processing:**
- Problem: Repositories and tasks are processed sequentially in main loop, no parallelization
- Files: `run_copilot_automation.sh` (lines 204-212)
- Cause: Bash script structure doesn't leverage multiple cores or background jobs
- Improvement path: Use GNU Parallel or job background processing, add `--max-parallel` flag, monitor resource usage to prevent system overload

**LLM API Latency:**
- Problem: Each task triggers 2-3 LLM API calls (parse_tasks, generate_branch_slug, generate_commit_message)
- Files: `lib/task_processing.sh` (lines 107-233)
- Cause: Multiple independent API calls instead of batching or single call
- Improvement path: Batch LLM calls where possible, cache results, use faster models for non-critical tasks (e.g., gpt-4o-mini for slug generation)

**Full Repository Scan:**
- Problem: Script scans all directories in ROOT looking for TASKS.md without filtering
- Files: `run_copilot_automation.sh` (lines 204-212)
- Cause: No `.gitignore` awareness or pattern filtering
- Improvement path: Add `--include-repos` and `--exclude-repos` patterns, cache metadata file list, skip hidden directories

**No Caching Between Runs:**
- Problem: Each run re-parses TASKS.md, regenerates slugs/commit messages for same tasks
- Files: `lib/task_processing.sh` (entire module)
- Cause: Stateless script design, no task cache
- Improvement path: Add optional task cache with `--use-cache` flag, invalidate on file mtime change

## Fragile Areas

**Task Parsing Pipeline:**
- Files: `lib/task_processing.sh` (lines 107-157)
- Why fragile: Depends on LLM output format, falls back to regex if LLM fails, regex may miss edge cases (nested subtasks, special characters in titles)
- Safe modification: Add comprehensive test suite for various TASKS.md formats, make regex patterns explicit and testable
- Test coverage: No unit tests for parsing logic, only integration via full script run

**Worktree Lifecycle Management:**
- Files: `lib/git_utils.sh` (lines 25-87), `run_copilot_automation.sh` (lines 115-161)
- Why fragile: Complex state machine (create → implement → commit → cleanup), force removal flags, branch deletion logic assumes push state
- Safe modification: Add explicit state tracking, avoid mixing worktree and branch state management, test cleanup scenarios thoroughly
- Test coverage: No tests for edge cases (network failure during push, cleanup when branch exists, concurrent worktree operations)

**AI Backend Dispatch Logic:**
- Files: `lib/ai_backends.sh` (lines 108-147), `lib/task_processing.sh` (lines 272-319)
- Why fragile: Backend availability checked in multiple places, different fallback behaviors (copilot soft-fails, claude hard-fails)
- Safe modification: Centralize backend availability checks, make fallback behavior consistent, add explicit logging when fallbacks occur
- Test coverage: No mock backends for testing, manual testing required

**PR Creation with Task List:**
- Files: `lib/task_processing.sh` (lines 345-458)
- Why fragile: Builds PR body from task array that may be incomplete or corrupted, gh command failures not retried, 30s sleep may be insufficient
- Safe modification: Validate task list non-empty before PR creation, add retry logic with exponential backoff, remove hardcoded sleep
- Test coverage: No tests for PR creation scenarios, only tested manually

## Scaling Limits

**Repository Limit:**
- Current capacity: Script handles unlimited repos but becomes slow after ~50 due to sequential processing
- Limit: Exceeds practical use when scanning >100 repos without parallelization
- Scaling path: Add parallel job support, limit max repos per run, implement progress tracking

**Task Limit Per Repository:**
- Current capacity: Can theoretically process unlimited tasks per repo, but LLM API rate limiting may kick in
- Limit: ~10-20 tasks practical limit before hitting OpenAI/LLM rate limits
- Scaling path: Add batching support, implement request queuing, respect API quotas, make task limit configurable

**Worktree Count:**
- Current capacity: One worktree per top-level task
- Limit: Storage space for cloned repos in `$WORKTREES_DIR`, disk I/O during concurrent worktree operations
- Scaling path: Cleanup worktrees aggressively, compress/archive old worktrees, add disk space checks

**Log File Growth:**
- Current capacity: One main log + per-repo logs per run
- Limit: Logs directory not pruned, grows unbounded over time
- Scaling path: Implement log rotation, add `--max-logs` with automatic cleanup, compress old logs

## Dependencies at Risk

**External LLM API Dependency (OpenAI GPT-4o-mini):**
- Risk: Task parsing and slug generation depend on external OpenAI API, no fallback provider
- Impact: API downtime or rate limiting breaks task parsing, branch slug generation produces invalid names
- Migration plan: Add pluggable LLM backend interface, support local LLMs (ollama), cache critical operations

**GitHub Copilot CLI Soft Requirement:**
- Risk: When copilot unavailable, creates task marker files instead of implementing changes
- Impact: Silent degradation - script succeeds but no actual work done, user may not notice
- Migration plan: Make hard requirement or add explicit mode switching, add warning when fallback occurs

**GitHub CLI (gh) Hard Requirement:**
- Risk: PR creation impossible without gh, no alternative provider
- Impact: Script fails if gh not authenticated or unavailable
- Migration plan: Add curl-based fallback for GitHub API, document authentication requirements upfront

## Missing Critical Features

**No Dry-Run Validation:**
- Problem: `--dry-run` flag skips actual worktree creation and AI backend invocation, doesn't test full workflow
- Blocks: Can't validate that all changes would succeed before running real automation
- Improvement: Implement full dry-run that creates worktrees and runs AI but doesn't commit/push

**No Task Filtering:**
- Problem: Script processes all tasks in TASKS.md, no ability to skip or prioritize specific tasks
- Blocks: Can't re-run single failed task or prioritize critical tasks
- Improvement: Add `--task-filter` pattern matching, `--skip-task` exclusion, `--task-priority` reordering

**No Rollback Mechanism:**
- Problem: Once changes are committed, no easy way to revert if implementation was incorrect
- Blocks: Failed implementations create orphaned branches that need manual cleanup
- Improvement: Add rollback branch reference, implement `--undo-last-run`, add change review before committing

**No Hook Support:**
- Problem: No way to run custom validation or post-processing after AI implementation
- Blocks: Can't validate generated code, run linters, or execute tests before committing
- Improvement: Add pre-commit hooks (linting, testing), post-commit hooks (notifications)

**No Task Status Tracking:**
- Problem: TASKS.md format doesn't distinguish between "in progress", "implemented but not reviewed", "failed"
- Blocks: Can't distinguish which tasks need human attention
- Improvement: Add metadata file tracking task implementation state, update TASKS.md with completion status

## Test Coverage Gaps

**Task Parsing:**
- What's not tested: Parsing of complex TASKS.md with edge cases (empty tasks, special chars, deeply nested subtasks, mixed indentation)
- Files: `lib/task_processing.sh` (lines 107-157)
- Risk: Parser silently produces incorrect results for non-standard TASKS.md formats
- Priority: High - affects all downstream processing

**Git Worktree Operations:**
- What's not tested: Worktree creation when branch exists, force removal error recovery, concurrent worktree operations, cleanup on network failure
- Files: `lib/git_utils.sh` (entire module)
- Risk: Corrupt worktree state, lost work, dangling git references
- Priority: High - affects data integrity

**AI Backend Invocation:**
- What's not tested: Backend unavailability handling, prompt injection, timeout handling, partial output handling
- Files: `lib/ai_backends.sh` (entire module)
- Risk: Unhandled errors, security vulnerabilities, incomplete code generation
- Priority: Medium - tests can use mock backends

**PR Creation Workflow:**
- What's not tested: PR creation with large task lists, duplicate PR detection, branch naming conflicts
- Files: `lib/task_processing.sh` (lines 344-458)
- Risk: Duplicate PRs created, PR creation fails without retry
- Priority: Medium - requires GitHub API integration testing

**Configuration Validation:**
- What's not tested: Invalid config values, missing required env vars, path validation
- Files: `lib/config.sh` (entire module)
- Risk: Silent failures with bad configuration
- Priority: Low - covered by manual testing

---

*Concerns audit: 2026-02-01*
