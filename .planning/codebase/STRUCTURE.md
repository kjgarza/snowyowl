# Codebase Structure

**Analysis Date:** 2026-02-01

## Directory Layout

```
snowyowl/
├── run_copilot_automation.sh      # Main automation script (entry point)
├── setup.sh                        # Setup wizard for initial configuration
├── verify_installation.sh          # Prerequisites verification script
├── copilot_integration.sh          # GitHub Copilot CLI integration helpers
├── config.env                      # Runtime configuration (env vars)
├── justfile                        # Just task runner recipes
├── .mise.toml                      # Mise task runner configuration
├── TASKS.md                        # Specification document (auto-generated or manual)
├── README.md                       # Main documentation and usage guide
├── CHANGELOG.md                    # Version history and changes
├── LICENSE                         # MIT License
├── CITATION.cff                    # Citation metadata
├── STRUCTURE.txt                   # Legacy structure reference
│
├── lib/                            # Core library modules (sourced by main script)
│   ├── config.sh                   # Configuration, env setup, argument parsing, logging
│   ├── git_utils.sh                # Git operations (worktrees, cleanup)
│   ├── ai_backends.sh              # AI backend integrations (Copilot, Claude)
│   ├── task_processing.sh          # Task parsing, specification loading, implementation
│   └── README.md                   # Library documentation
│
├── templates/                      # Template files for new repositories
│   ├── TASKS.template.md           # Template for TASKS.md in new projects
│   └── TASK_SPEC.template.md       # Template for detailed task specifications
│
├── examples/                       # Example task files for reference
│   ├── linked-tasks-example.md     # Example using linked specifications
│   ├── python-library-tasks.md     # Example: Python library project
│   ├── react-app-tasks.md          # Example: React application
│   ├── web-app-tasks.md            # Example: Web application
│   └── specs/                      # Example specification files
│
├── logs/                           # Automation execution logs (auto-created)
│   ├── automation_YYYYMMDD_HHMMSS.log  # Main run log
│   └── {repo}_YYYYMMDD_HHMMSS.log      # Per-repository logs
│
├── docs/                           # Extended documentation
│   └── [various markdown files]    # Architecture, integration guides, etc.
│
├── .planning/                      # GSD planning documents (auto-created)
│   └── codebase/                   # Codebase analysis documents
│       ├── ARCHITECTURE.md         # Architecture analysis
│       ├── STRUCTURE.md            # Structure analysis (this file)
│       ├── CONVENTIONS.md          # Coding conventions (if quality focus)
│       ├── TESTING.md              # Testing patterns (if quality focus)
│       ├── STACK.md                # Technology stack (if tech focus)
│       ├── INTEGRATIONS.md         # External integrations (if tech focus)
│       └── CONCERNS.md             # Technical debt (if concerns focus)
│
├── .claude/                        # Claude Code CLI state (auto-created)
│   └── [internal state files]      # Managed by Claude Code
│
└── worktrees/                      # Git worktrees (auto-created at runtime)
    └── {repo}-{branch}-*/          # One worktree per active task branch
        ├── .git                    # Worktree git metadata
        └── [project files]         # Isolated working directory
```

## Directory Purposes

**Root Directory:**
- Purpose: Entry points, main scripts, configuration
- Contains: Executable scripts, config files, task runners, documentation
- Key files: `run_copilot_automation.sh`, `config.env`, `justfile`

**lib/ (Library Modules):**
- Purpose: Reusable shell modules sourced by main script
- Contains: Pure shell functions organized by concern (configuration, git, AI, tasks)
- Key files: `config.sh`, `git_utils.sh`, `ai_backends.sh`, `task_processing.sh`
- Architectural pattern: Each module focuses on one concern; no cross-module dependencies except through main script sourcing

**templates/:**
- Purpose: Boilerplate files for new repositories
- Contains: TASKS.md template (basic and advanced), task specification template
- Key files: `TASKS.template.md`, `TASK_SPEC.template.md`
- Usage: Copy to new repositories as starting point

**examples/:**
- Purpose: Reference implementations and use cases
- Contains: Sample TASKS.md files for different project types, example specifications
- Key files: `react-app-tasks.md`, `python-library-tasks.md`, `linked-tasks-example.md`
- Usage: Show users how to structure their own task files

**logs/ (Auto-created):**
- Purpose: Audit trail and debugging
- Contains: Timestamped log files from each automation run
- Key files: `automation_YYYYMMDD_HHMMSS.log` (main), `{repo}_YYYYMMDD_HHMMSS.log` (per-repo)
- Lifecycle: Created at runtime; user responsible for cleanup

**docs/:**
- Purpose: Extended documentation beyond README
- Contains: Architecture docs, integration guides, API references
- Key files: Various markdown files for different aspects
- Usage: Reference documentation for developers

**.planning/codebase/ (Auto-created by GSD):**
- Purpose: Codebase analysis documents for future planning
- Contains: Architecture analysis, structure maps, conventions, testing patterns, concerns
- Key files: ARCHITECTURE.md, STRUCTURE.md, CONVENTIONS.md, TESTING.md, STACK.md, INTEGRATIONS.md, CONCERNS.md
- Lifecycle: Generated by GSD mapping commands; used by GSD planning/execution

**worktrees/ (Auto-created at runtime):**
- Purpose: Isolated working directories for parallel task implementation
- Contains: One directory per active feature branch
- Naming: `{repo_name}-{branch_name}` (e.g., `myapp-feat-add-auth-1704067890`)
- Lifecycle: Created when processing task; cleaned up after PR creation (unless `--cleanup-worktrees=false`)

## Key File Locations

**Entry Points:**
- `run_copilot_automation.sh`: Main automation script; called directly or via task runners
- `setup.sh`: Setup wizard; called once during initial installation
- `verify_installation.sh`: Prerequisites checker; called before running automation
- `justfile`: Just recipe definitions; invoked via `just <recipe>`
- `.mise.toml`: Mise task definitions; invoked via `mise run <task>`

**Configuration:**
- `config.env`: Runtime environment variables (backend, model, PR creation, cleanup)
- `lib/config.sh`: Hard-coded defaults, argument parsing, logging setup
- `justfile`: Task runner configuration (just)
- `.mise.toml`: Task runner configuration (mise)

**Core Logic:**
- `lib/task_processing.sh`: Task parsing, implementation coordination, PR workflow
- `lib/ai_backends.sh`: AI backend abstraction (Copilot, Claude routing)
- `lib/git_utils.sh`: Git worktree and remote operations
- `lib/config.sh`: Configuration and logging infrastructure

**Documentation & Examples:**
- `README.md`: Main documentation, usage guide, installation instructions
- `templates/TASKS.template.md`: Boilerplate for TASKS.md in new repos
- `examples/linked-tasks-example.md`: Example with markdown-linked specifications
- `examples/react-app-tasks.md`: Example for React projects
- `examples/python-library-tasks.md`: Example for Python projects

**Testing & Verification:**
- `verify_installation.sh`: Checks prerequisites before running
- `setup.sh`: Guided setup and configuration

## Naming Conventions

**Files:**
- Shell scripts: lowercase with hyphens, `.sh` extension (e.g., `run_copilot_automation.sh`)
- Configuration: lowercase with `.env` suffix or `.toml` for task runners (e.g., `config.env`, `.mise.toml`)
- Library modules: lowercase with hyphens, prefix describing domain (e.g., `git_utils.sh`, `ai_backends.sh`)
- Documentation: UPPERCASE for primary docs (README.md, TASKS.md, CHANGELOG.md), lowercase for topic-specific (tasks/specs in docs/)
- Logs: `automation_YYYYMMDD_HHMMSS.log` (main), `{repo_name}_YYYYMMDD_HHMMSS.log` (per-repo)
- Templates: `NAME.template.md` suffix to indicate boilerplate

**Directories:**
- Core: lowercase (lib, logs, docs, examples, templates, worktrees)
- Task runners: root level (justfile, .mise.toml)
- Hidden: dot-prefix for system files (.git, .planning, .claude, .gitignore)
- Runtime: auto-created directories named for their content (logs, worktrees)

**Functions (Shell):**
- Public functions: verb_noun pattern (e.g., `create_worktree`, `parse_tasks`, `check_prerequisites`)
- Private functions (called internally): same pattern, considered private by convention (no prefix)
- Logging functions: `log`, `log_error`, `log_success`
- Backend-specific: `run_{backend}_backend` (e.g., `run_copilot_backend`, `run_claude_backend`)

**Variables:**
- Environment variables: UPPERCASE_WITH_UNDERSCORES (e.g., `ROOT`, `AI_BACKEND`, `MAIN_LOG`)
- Local variables (in functions): lowercase_with_underscores (e.g., `repo_path`, `branch_name`, `task_title`)
- Constants: UPPERCASE (e.g., `SCRIPT_DIR`, `LOG_DIR`)

## Where to Add New Code

**New Feature in Core Workflow:**
- Primary code: Add function to appropriate module in `lib/` based on concern:
  - Git operations → `lib/git_utils.sh`
  - AI backend logic → `lib/ai_backends.sh`
  - Task parsing/implementation → `lib/task_processing.sh`
  - Configuration/logging → `lib/config.sh`
- Integration point: Call from `run_copilot_automation.sh` or existing function
- Tests: Add test cases to verification scripts

**New Task Runner Recipe (just):**
- Primary code: Add recipe to `justfile`
- Pattern: Follow existing recipe structure; use `@echo` for output, conditionals for installation
- Call: `just <recipe-name>`

**New Task Runner Task (mise):**
- Primary code: Add task to `.mise.toml`
- Pattern: Follow existing task structure; reference shell commands or scripts
- Call: `mise run <task-name>`

**New AI Backend Support:**
- Primary code:
  - Add backend detection in `lib/ai_backends.sh`: `check_ai_backend()` function
  - Add backend runner function: `run_{backend}_backend()` in `lib/ai_backends.sh`
  - Add dispatch case in `run_ai_backend()` dispatcher
  - Add to config options: `lib/config.sh` backend validation
- Integration: Updated prompt building in `lib/ai_backends.sh`: `build_task_prompt()`
- Configuration: Add env vars and defaults in `lib/config.sh`

**New LLM-Powered Feature:**
- Primary code: Call LLM CLI with prompt and model:
  - Parse tasks: `lib/task_processing.sh` in `parse_tasks()`
  - Generate branch slugs: `lib/task_processing.sh` in `generate_branch_slug()`
  - Generate commit messages: `lib/task_processing.sh` in `generate_commit_message()`
- Pattern: Use `echo "$prompt" | llm -m gpt-4o-mini` with fallback regex
- Model: Hardcoded to `gpt-4o-mini` for lightweight operations; customizable via similar pattern to AI backend model

**New Repository Configuration:**
- Copy: `templates/TASKS.template.md` to new repo as `TASKS.md`
- Customize: Edit TASKS.md with project-specific tasks
- Link: Reference specification files with markdown links: `[Task](./specs/spec.md)`
- Create: Specification files in `./specs/` using `templates/TASK_SPEC.template.md` as starting point

**Documentation & Examples:**
- README updates: `README.md` (root level)
- New example project: Create `.md` file in `examples/` showing TASKS.md structure for specific project type
- Architecture/design docs: Add to `docs/` directory

## Special Directories

**logs/:**
- Purpose: Runtime logs
- Generated: Yes, auto-created on first run
- Committed: No, typically gitignored
- Cleanup: User responsible; old logs can be deleted manually or via `just clean`
- Location: `$LOG_DIR` variable (default: `~/aves/snowyowl/logs`)

**worktrees/:**
- Purpose: Git worktrees for isolated task implementation
- Generated: Yes, auto-created when processing tasks
- Committed: No, separate from main repository
- Cleanup: Automatic if `CLEANUP_WORKTREES=true`; manual cleanup via `git worktree remove` if disabled
- Location: `$WORKTREES_DIR` variable (default: `~/aves/worktrees`)

**.planning/codebase/:**
- Purpose: GSD codebase analysis documents
- Generated: Yes, auto-created by GSD mapping commands
- Committed: Yes, version-controlled (not in .gitignore)
- Lifecycle: Regenerated by GSD when mapping focus changes
- Location: `.planning/codebase/` relative to repo root

**.claude/:**
- Purpose: Claude Code CLI internal state
- Generated: Yes, auto-created by Claude Code
- Committed: No, managed by Claude CLI
- Cleanup: Can be safely deleted; Claude CLI will recreate
- Location: `.claude/` hidden directory

---

*Structure analysis: 2026-02-01*
