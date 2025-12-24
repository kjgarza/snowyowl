# SnowyOwl Library Modules

This directory contains modular components for the SnowyOwl automation system.

## Module Overview

### config.sh (140 lines)
**Purpose:** Configuration, environment setup, and logging

**Key Functions:**
- `parse_arguments()` - Parse command-line flags
- `show_help()` - Display help message
- `set_default_model()` - Set AI model defaults
- `init_directories()` - Create log and worktree directories
- `log()`, `log_error()`, `log_success()` - Logging functions

**Variables Defined:**
- `ROOT`, `BASE_BRANCH`, `DRY_RUN`, `CREATE_PR`
- `LOG_DIR`, `WORKTREES_DIR`, `TIMESTAMP`
- `AI_BACKEND`, `AI_MODEL`
- `CLAUDE_*`, `COPILOT_*` settings

### git_utils.sh (109 lines)
**Purpose:** Git worktree operations

**Key Functions:**
- `has_github_remote()` - Check if repo has GitHub remote
- `create_worktree()` - Create isolated worktree for a branch
- `remove_worktree()` - Clean up worktree and optionally branch
- `cleanup_repo_worktrees()` - Bulk cleanup of all worktrees

**Dependencies:**
- Uses `$WORKTREES_DIR` from config.sh
- Uses `log()` functions from config.sh

### ai_backends.sh (149 lines)
**Purpose:** AI coding assistant integrations

**Key Functions:**
- `build_task_prompt()` - Construct prompts with specifications
- `run_copilot_backend()` - Execute GitHub Copilot CLI
- `run_claude_backend()` - Execute Claude Code CLI
- `run_ai_backend()` - Backend dispatcher
- `check_ai_backend()` - Validate backend availability

**Dependencies:**
- Uses `$AI_BACKEND`, `$AI_MODEL` from config.sh
- Uses `log()` functions from config.sh

### task_processing.sh (364 lines)
**Purpose:** Task parsing, implementation, and PR creation

**Key Functions:**
- `extract_task_link()` - Extract markdown links from tasks
- `load_task_specification()` - Load specification files
- `check_prerequisites()` - Validate dependencies
- `parse_tasks()` - Parse TASKS.md with LLM
- `implement_task()` - Execute AI-powered task implementation
- `create_pr_for_branch()` - Create pull requests

**Dependencies:**
- Uses functions from all other modules
- Uses `has_github_remote()`, `remove_worktree()` from git_utils.sh
- Uses `build_task_prompt()`, `run_ai_backend()` from ai_backends.sh

## Module Loading Order

The main script (`run_copilot_automation.sh`) loads modules in this order:

1. **config.sh** - Must be first (defines variables used by all others)
2. **git_utils.sh** - Git operations
3. **ai_backends.sh** - AI backend integrations
4. **task_processing.sh** - Must be last (depends on all others)

## Design Principles

- **KISS**: Simple sourcing, no complex dependencies between modules
- **Single Responsibility**: Each module has one clear purpose
- **No Cross-Dependencies**: Modules don't source each other
- **Backward Compatible**: All functionality preserved from monolithic script

## Usage

These modules are automatically sourced by the main script. Do not run them directly.

```bash
# Correct usage
./run_copilot_automation.sh [OPTIONS]

# Not intended for direct use
# ./lib/config.sh  # Don't do this
```

## Extending

To add new functionality:

1. **New AI Backend**: Add functions to `ai_backends.sh`
2. **New Git Operations**: Add functions to `git_utils.sh`
3. **New Configuration**: Add variables/parsing to `config.sh`
4. **New Task Features**: Add functions to `task_processing.sh`

Keep functions focused and maintain the KISS principle.

