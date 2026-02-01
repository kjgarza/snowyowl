# External Integrations

**Analysis Date:** 2026-02-01

## APIs & External Services

**GitHub API:**
- Service: GitHub REST API v3 / GraphQL
- What it's used for: Repository operations, PR creation, authentication
  - SDK/Client: GitHub CLI (`gh`)
  - Auth: GitHub OAuth token via `gh auth login`
  - Configuration in `config.env`: `SNOWYOWL_GH_TIMEOUT=300`

**AI Coding Services:**

**GitHub Copilot CLI:**
- Service: GitHub Copilot AI code generation
- What it's used for: Automated code implementation
  - CLI: `copilot` (GitHub extension)
  - Installation: `gh extension install github/gh-copilot`
  - Auth: Uses GitHub OAuth token from GitHub CLI
  - Model: Configurable via `SNOWYOWL_MODEL` (default: gpt-4o)
  - Configuration: `COPILOT_DENY_TOOLS="shell(rm)"` for safety

**Claude Code CLI:**
- Service: Anthropic Claude agentic coding tool
- What it's used for: Automated code implementation (alternative to Copilot)
  - CLI: `claude` command-line tool
  - Installation: `curl -fsSL https://claude.ai/install.sh | bash`
  - Auth: CLAUDE_API_KEY environment variable
  - Model: Configurable via `SNOWYOWL_MODEL` (default: claude-sonnet-4-5)
  - Configuration:
    - `CLAUDE_ALLOWED_TOOLS="Read,Write,Edit,Bash,Grep,Glob"`
    - `CLAUDE_PERMISSION_MODE="acceptEdits"`
    - Runs in headless mode with: `claude -p "prompt" --allowedTools ... --permission-mode ...`

**LLM CLI (OpenAI):**
- Service: OpenAI API for task parsing
- What it's used for: Intelligent parsing of task structures and requirements
  - CLI: `llm` command-line tool
  - Installation: `pip install llm` or `pipx install llm`
  - Auth: OpenAI API key via `llm keys set openai`
  - Implementation: Integrated with task parsing logic in `lib/task_processing.sh`

## Data Storage

**Databases:**
- Not used - SnowyOwl is a stateless automation tool
- Uses filesystem-based task definitions (TASKS.md files)

**File Storage:**
- Local filesystem only
- Repositories: Scanned from `SNOWYOWL_ROOT` directory (default: `$HOME/aves`)
- Logs: Written to `SNOWYOWL_LOG_DIR` directory
- Worktrees: Created in `SNOWYOWL_WORKTREES_DIR` directory
- Configuration: `config.env` (local file)

**Caching:**
- None - each run reads fresh from filesystem

## Authentication & Identity

**Auth Provider:**
- GitHub OAuth (primary)
  - Implementation: Via GitHub CLI (`gh auth login`)
  - Credentials stored by GitHub CLI in platform-specific secure storage
  - Used for: PR creation, repository operations, API access

- OpenAI API Key (secondary, for task parsing)
  - Implementation: Via LLM CLI (`llm keys set openai`)
  - Used for: Intelligent task parsing via OpenAI models

- Claude API Key (optional, for Claude backend)
  - Implementation: CLAUDE_API_KEY environment variable
  - Used for: Claude Code CLI authentication

## Monitoring & Observability

**Error Tracking:**
- None - no external error tracking service
- Error reporting is local only

**Logs:**
- Approach: File-based logging to `SNOWYOWL_LOG_DIR`
- Log files: `automation_YYYYMMDD_HHMMSS.log` (main) and `{repo}_YYYYMMDD_HHMMSS.log` (per-repo)
- Cleanup: Old logs kept, can be manually cleaned with `just clean` or `mise run clean`
- Log functions in `lib/config.sh`:
  - `log()` - Standard info messages
  - `log_error()` - Error messages
  - `log_success()` - Success messages

**Observability Features:**
- Comprehensive logging of all major operations
- Timestamps for each log entry
- Both stdout and file logging
- Repository-specific logging for parallelization

## CI/CD & Deployment

**Hosting:**
- GitHub - Primary repository hosting and API provider

**CI Pipeline:**
- No built-in CI configuration
- Can be triggered from external CI/CD systems (GitHub Actions, GitLab CI, etc.)
- Can be scheduled via:
  - Cron jobs: `0 2 * * * ./run_copilot_automation.sh`
  - launchd (macOS): `com.snowyowl.automation.plist`
  - tmux/screen for persistent sessions

**Deployment Integration:**
- Repositories must be local clones
- No remote deployment capability
- Works with repositories in `SNOWYOWL_ROOT` directory

## Environment Configuration

**Required env vars for operation:**
- `SNOWYOWL_ROOT` - Root directory containing repositories
- `SNOWYOWL_BACKEND` - AI backend (copilot or claude)
- `SNOWYOWL_BASE_BRANCH` - Base branch for PRs

**Optional env vars:**
- `SNOWYOWL_MODEL` - Specific AI model to use
- `SNOWYOWL_CREATE_PR` - Enable PR creation (default: false)
- `SNOWYOWL_LOG_DIR` - Custom log directory
- `SNOWYOWL_WORKTREES_DIR` - Custom worktree location
- `CLAUDE_ALLOWED_TOOLS` - Tools for Claude
- `CLAUDE_PERMISSION_MODE` - Claude behavior
- `COPILOT_DENY_TOOLS` - Tools to deny Copilot

**Secrets location:**
- GitHub credentials: Managed by `gh` CLI (platform-specific secure storage)
- OpenAI API key: Managed by `llm` CLI (secure storage)
- Claude API key: Environment variable `CLAUDE_API_KEY` (user's shell environment)

## Webhooks & Callbacks

**Incoming:**
- None - SnowyOwl does not receive webhooks

**Outgoing:**
- GitHub PR creation: Push to GitHub, create PR via `gh pr create`
- Git operations: Commits and branch pushes to remote
- No external webhook callbacks

## GitHub Integration Details

**Repository Operations:**
- Create feature branches: `git worktree add -b <branch> <path> <base>`
- Commit changes: `git commit -m "message"`
- Push branches: `git push origin <branch>`
- Create PRs: `gh pr create --title "..." --body "..."`

**PR Workflow:**
- Branch naming: `snowyowl-ai-<task>-<timestamp>`
- PR labels: `snowyowl-automation` (configurable via `SNOWYOWL_PR_LABEL`)
- Draft PRs: Can be enabled via `SNOWYOWL_PR_DRAFT=true`
- Auto-merge: Can be enabled via `SNOWYOWL_PR_AUTO_MERGE=true`

**Configuration Variables (config.env):**
```bash
SNOWYOWL_PR_LABEL="snowyowl-automation"
SNOWYOWL_PR_DRAFT=false
SNOWYOWL_PR_AUTO_MERGE=false
SNOWYOWL_CREATE_PR=false      # Default: commit locally only
```

## Task Specification System

**Task Definition Format:**
- Location: `TASKS.md` in each target repository
- Format: Markdown checkbox lists
- Optional specification links: `- [ ] [Title](spec.md)` format
- Specification loading: `lib/task_processing.sh:load_task_specification()`
- Max specification size: 100KB (truncated if larger)

## Workflow Integration Points

**1. Task Discovery:**
- Scans `SNOWYOWL_ROOT` for TASKS.md files
- Parses tasks using LLM CLI intelligent processing
- Loads linked specifications from markdown files

**2. AI Backend Dispatch:**
- Routes to Copilot CLI or Claude Code CLI based on `SNOWYOWL_BACKEND`
- Passes task context and repository information
- Captures output in per-repo log files

**3. Git Worktree Operations:**
- Creates isolated worktrees for each task
- Makes commits in worktrees
- Pushes branches if `SNOWYOWL_CREATE_PR=true`

**4. PR Creation:**
- Optional PR creation via GitHub CLI
- PR titles and bodies generated from task context
- Labeled with `SNOWYOWL_PR_LABEL`

---

*Integration audit: 2026-02-01*
