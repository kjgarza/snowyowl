# Technology Stack

**Analysis Date:** 2026-02-01

## Languages

**Primary:**
- Bash (5.0+) - Main automation scripts, configuration, and git operations
- Shell scripts - All executable files use bash interpreter

**Secondary:**
- Markdown - Task specifications and documentation format

## Runtime

**Environment:**
- Bash 5.0+ (required by script shebang: `#!/usr/bin/env bash`)
- macOS / Linux / Unix-like systems

**Package Manager:**
- None (no package dependencies in traditional sense)
- Relies on system-level command-line tools

## Frameworks

**Core:**
- Git 2.0+ - Version control and worktree management
- GitHub CLI (gh) - GitHub API interactions and PR creation
- LLM CLI - Task parsing and intelligent processing

**Build/Dev:**
- just - Command runner for recipes (optional but recommended)
- mise - Task runner and environment manager (optional alternative to just)

**AI Backends:**
- GitHub Copilot CLI - AI code generation via Copilot
- Claude Code CLI - AI code generation via Claude (Anthropic)

## Key Dependencies

**Critical System Commands:**
- `git` - Version control system
- `gh` - GitHub CLI for authentication and PR operations
- `llm` - LLM CLI for task parsing (Python-based)

**Infrastructure:**
- GitHub - Repository hosting and CI/CD integration
- GitHub OAuth - Authentication mechanism via `gh auth login`

**Development Tools (Optional but Recommended):**
- `just` - Command runner (https://just.systems)
- `mise` - Task runner (https://mise.jdx.dev)
- `brew` - Package manager for macOS

**AI Coding Assistants (Choose One or Both):**
- GitHub Copilot CLI - GitHub extension for programmatic AI access
- Claude Code CLI - Anthropic's Claude Code agentic tool

## Configuration

**Environment:**
- Variables defined in `config.env`:
  - `SNOWYOWL_ROOT` - Root directory for repositories (default: `$HOME/aves`)
  - `SNOWYOWL_BASE_BRANCH` - Base branch for PRs (default: `main`)
  - `SNOWYOWL_LOG_DIR` - Log file directory
  - `SNOWYOWL_WORKTREES_DIR` - Worktree storage location
  - `SNOWYOWL_BACKEND` - AI backend selection (copilot or claude)
  - `SNOWYOWL_MODEL` - AI model selection
  - `SNOWYOWL_CREATE_PR` - Enable PR creation (default: false)
  - `CLAUDE_ALLOWED_TOOLS` - Tools available to Claude
  - `CLAUDE_PERMISSION_MODE` - Claude permission behavior
  - `COPILOT_DENY_TOOLS` - Tools denied to Copilot

**Build:**
- `justfile` - Just recipe configuration (optional)
- `.mise.toml` - Mise task configuration (optional)
- No traditional build system or compilation needed

**Task Definition Format:**
- `TASKS.md` files in target repositories
- Checkbox markdown format: `- [ ] Task description`
- Optional specification links: `- [ ] [Title](path/to/spec.md)`

## Platform Requirements

**Development:**
- Bash 5.0+ shell
- Git 2.0+ with worktree support
- GitHub CLI (gh) with authentication capability
- Python 3.7+ (for llm CLI)
- Write access to git repositories
- SSH or HTTPS access to GitHub

**Production:**
- Deployment target: Local machine or CI/CD environment
- Can be scheduled via cron, launchd (macOS), or CI/CD pipeline
- No server infrastructure required
- Operates on filesystem-based repositories

## Installation Paths

**Core Tools Installation:**
```bash
# GitHub CLI
brew install gh              # macOS
curl -sS https://webi.sh/gh | sh  # Linux

# LLM CLI
pip install llm              # Python-based

# GitHub Copilot CLI (requires gh)
gh extension install github/gh-copilot

# Claude Code CLI
curl -fsSL https://claude.ai/install.sh | bash

# Just (optional)
brew install just            # macOS
cargo install just           # Linux/other

# Mise (optional)
# Installation varies - see https://mise.jdx.dev
```

## Authentication & Credentials

**GitHub:**
- Managed by GitHub CLI: `gh auth login`
- Credentials stored by gh in platform-specific secure storage
- Used for PR creation and repository operations

**LLM/OpenAI:**
- Set via: `llm keys set openai`
- Stored by llm CLI (secure storage)
- Used for task parsing via OpenAI models

**AI Backends:**
- Copilot: Uses GitHub CLI authentication
- Claude: Requires API credentials (typically CLAUDE_API_KEY environment variable)

## Directory Structure

```
snowyowl/
├── run_copilot_automation.sh    # Main automation entry point
├── setup.sh                      # Installation wizard
├── verify_installation.sh        # Dependency verification
├── config.env                    # Configuration defaults
├── justfile                      # Just recipe definitions (optional)
├── .mise.toml                    # Mise task definitions (optional)
├── lib/                          # Core library modules
│   ├── config.sh                # Configuration and argument parsing
│   ├── git_utils.sh             # Git and worktree operations
│   ├── ai_backends.sh           # AI backend integrations
│   └── task_processing.sh       # Task parsing and processing
├── logs/                         # Auto-generated execution logs
├── templates/                    # Task markdown templates
└── examples/                     # Example TASKS.md files
```

## Version Information

**Current Versions Supported:**
- Git: 2.0+ (for worktree support)
- GitHub CLI: Latest (no specific version pinned)
- LLM CLI: Latest
- Bash: 5.0+ (for associative arrays and modern features)
- Python: 3.7+ (for llm dependency)

---

*Stack analysis: 2026-02-01*
