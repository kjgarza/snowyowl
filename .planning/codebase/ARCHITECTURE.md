# Architecture

**Analysis Date:** 2026-02-01

## Pattern Overview

**Overall:** Modular bash-based automation orchestrator with plugin-style AI backend routing

**Key Characteristics:**
- Multi-stage pipeline: repository scanning → task parsing → worktree creation → AI-driven implementation → git operations
- Pluggable AI backend system supporting GitHub Copilot and Anthropic Claude
- Git worktree isolation for parallel, safe task implementation
- LLM-driven intelligent task parsing and conventional commit generation
- Local-first design with optional GitHub integration

## Layers

**Orchestration Layer:**
- Purpose: Main workflow control and repository iteration
- Location: `run_copilot_automation.sh` (main entry point)
- Contains: Repository discovery, task batching, worktree lifecycle management, PR workflow
- Depends on: Configuration module, all utility modules
- Used by: Direct CLI invocation or via just/mise task runners

**Configuration & Setup Layer:**
- Purpose: Environment initialization, argument parsing, logging infrastructure
- Location: `lib/config.sh`
- Contains: Defaults, CLI argument parsing, directory initialization, standardized logging functions
- Depends on: Bash stdlib only
- Used by: All other modules via sourcing

**Task Processing Layer:**
- Purpose: Parse tasks, load specifications, coordinate implementation and git operations
- Location: `lib/task_processing.sh`
- Contains: TASKS.md parsing (via LLM), specification loading, prerequisite checking, task implementation coordination, PR creation workflow
- Depends on: Configuration module, AI backends module, Git utilities module, LLM CLI external tool
- Used by: Orchestration layer for task execution

**Git Management Layer:**
- Purpose: Isolated working environments and version control operations
- Location: `lib/git_utils.sh`
- Contains: Worktree creation/removal, cleanup operations, GitHub remote detection, branch pruning
- Depends on: Configuration module
- Used by: Task processing layer, orchestration layer

**AI Backend Layer:**
- Purpose: Interface with external AI coding assistants in programmatic mode
- Location: `lib/ai_backends.sh`
- Contains: Backend-specific command construction (Copilot CLI, Claude Code CLI), prompt building, backend availability checking, dispatch routing
- Depends on: Configuration module
- Used by: Task processing layer for task implementation

## Data Flow

**Main Automation Workflow:**

1. **Initialization Phase**
   - Parse command-line arguments → populate configuration
   - Validate prerequisites (git, gh, llm, AI backend)
   - Initialize log directories and worktrees directory

2. **Repository Discovery Phase**
   - Scan `$ROOT` directory (default: `~/aves`)
   - Identify directories with `TASKS.md` files and `.git` folders
   - For each matching repository, proceed to task processing

3. **Task Parsing Phase**
   - Read `TASKS.md` from repository
   - Use LLM CLI (gpt-4o-mini) to intelligently parse markdown checkboxes
   - Extract tasks and preserve hierarchy (top-level vs subtasks)
   - Fallback to regex parsing if LLM fails
   - For each task, extract markdown links to specification files

4. **Worktree Creation Phase (per top-level task)**
   - Generate branch slug using LLM (conventional format: `feat/name`, `fix/name`)
   - Append timestamp to create unique branch: `{slug}-{timestamp}`
   - Create isolated git worktree via `git worktree add -b`
   - Worktree rooted at `$WORKTREES_DIR/{repo_name}-{branch_name}`

5. **Task Implementation Phase (per task)**
   - Load specification file if task has markdown link
   - Build comprehensive prompt with repository context and specification
   - Route to AI backend (Copilot or Claude) based on configuration
   - AI backend makes code changes directly in worktree
   - If AI backend unavailable, create `.pending_tasks/` marker files
   - Stage changes and commit with conventional commit message (LLM-generated)

6. **Push & PR Phase (per worktree/branch)**
   - Check if repository has GitHub remote
   - If PR creation disabled: log branch to local, optionally cleanup worktree
   - If PR creation enabled: push branch to origin, wait 30s, create PR via `gh pr create`
   - PR title from first task, body includes all tasks from branch
   - Cleanup worktree if `CLEANUP_WORKTREES=true`

**State Management:**

- **In-memory state**: Current branch, current worktree path, accumulated task list (per top-level task)
- **Filesystem state**: Git worktrees (isolated working directories), log files (main + per-repo), created commits
- **Remote state**: GitHub branches and pull requests (if `--create-pr` enabled)
- **Stateless operations**: LLM calls (no context between calls), AI backend invocations

## Key Abstractions

**AI Backend Interface:**
- Purpose: Unified abstraction over multiple AI coding assistants
- Examples: `run_copilot_backend()`, `run_claude_backend()`, `run_ai_backend()` in `lib/ai_backends.sh`
- Pattern: Backend-specific functions wrap CLI invocations; dispatcher function routes based on `$AI_BACKEND` env var

**Task Specification System:**
- Purpose: Link TASKS.md to detailed markdown specifications for complex requirements
- Examples: `[Task Name](./specs/spec.md)` markdown link syntax in TASKS.md
- Pattern: Extract link with regex, load content with `load_task_specification()`, pass to prompt builder

**Worktree Isolation Pattern:**
- Purpose: Safely implement multiple tasks in parallel without branch-switching in main repo
- Examples: Each top-level task gets its own worktree, changes committed in worktree, pushed from worktree
- Pattern: Create worktree with `git worktree add`, cd into it for implementation, cleanup with `git worktree remove`

**Conventional Commit Generation:**
- Purpose: Produce standardized commit messages
- Examples: LLM transforms task title to "feat: description" or "fix: description"
- Pattern: LLM prompt with examples and fallback regex sanitization

**Hierarchical Task Structure:**
- Purpose: Group related subtasks under parent tasks (same branch/PR)
- Examples: Top-level task creates worktree; indented subtasks (2 spaces) commit into same worktree
- Pattern: Check indentation level; new branch only for non-indented tasks; accumulate all tasks per worktree

## Entry Points

**CLI Entry Point:**
- Location: `run_copilot_automation.sh` (root script)
- Triggers: Direct shell execution or via `just automate`, `mise run automate`
- Responsibilities: Parse args, source modules, call `main()` function, coordinate entire pipeline

**Task Runners (just/mise):**
- Location: `justfile` (just recipes) and `.mise.toml` (mise tasks)
- Triggers: `just automate`, `mise run automate`, `mise run automate:claude`, etc.
- Responsibilities: Invoke main script with preset options; provide user-friendly shortcuts

**Setup & Verification:**
- Location: `setup.sh` (setup wizard), `verify_installation.sh` (dependency check)
- Triggers: `just setup`, `just verify` or direct execution
- Responsibilities: Guide installation, check prerequisites before running automation

## Error Handling

**Strategy:** Fail-fast at prerequisites; graceful fallback for optional features (AI backends); detailed logging for debugging

**Patterns:**

- **Prerequisites check** (`check_prerequisites()` in `lib/task_processing.sh`): Exit with code 1 if git, gh, or llm unavailable. Exit code 0 if AI backend available, code 2 if soft-fail (Copilot CLI not found but in fallback mode)
- **LLM fallback**: If LLM parsing fails (network error, rate limit), fall back to simple regex parsing
- **Worktree creation failure**: Log error, skip task, continue with remaining tasks
- **AI backend unavailable**: Create `.pending_tasks/` marker file instead of failing
- **Push/PR failure**: Log error, exit task with code 1 (do not continue to next task)
- **Dry-run mode**: Prevent commits, pushes, and PR creation; log `[DRY RUN]` prefix on would-be operations

**Logging:**
- All operations logged to `$MAIN_LOG` (timestamped file in `logs/`)
- Additionally logged to per-repository log file: `logs/{repo_name}_{timestamp}.log`
- Log functions: `log()` (info), `log_error()` (error), `log_success()` (success)
- Each function call writes to log via `tee -a`

## Cross-Cutting Concerns

**Logging:** All modules use `lib/config.sh` logging functions; all invocations piped through `tee -a $MAIN_LOG` and per-repo logs

**Validation:** Task format validated by LLM parser and regex fallback; branch names validated against git conventions; file paths sanitized in specification loading

**Authentication:** GitHub CLI authentication checked at startup (`gh auth status`). LLM API key configured separately by user. AI backend auth delegated to respective CLIs (Copilot: gh extension, Claude: system installation)

**Isolation:** Git worktrees provide filesystem isolation; each worktree has independent working directory, staging area, and branch history; cleanup only after PR creation/local commit

**Configuration:** Centralized in `lib/config.sh` with defaults; environment variable overrides (e.g., `SNOWYOWL_BACKEND`, `SNOWYOWL_MODEL`); command-line flags override all

---

*Architecture analysis: 2026-02-01*
