# 🦉 SnowyOwl - AI-Powered Automation Workflow

An automated overnight workflow system that uses AI coding assistants to autonomously read tasks, implement code changes, and create pull requests.

## 📋 Overview

SnowyOwl automates the complete software development workflow using AI coding assistants in programmatic mode. It supports multiple AI backends:

- **GitHub Copilot CLI** - GitHub's AI coding assistant
- **Claude Code CLI** - Anthropic's agentic coding tool

The workflow:

1. **Read** - Scans repositories for `TASKS.md` files
2. **Plan** - Generates implementation plans for each task
3. **Worktree** - Creates isolated git worktrees for parallel work
4. **Implement** - Makes code changes automatically in worktrees
5. **Commit** - Creates clean, descriptive commits
6. **Push** - (Optional) Pushes changes to GitHub
7. **PR** - (Optional) Opens pull requests for review
8. **Cleanup** - Removes worktrees after completion

### Key Features

- **Git Worktrees**: Uses git worktrees for isolated, parallel development
- **Safe Defaults**: Commits locally by default (no automatic pushes/PRs)
- **Multiple AI Models**: Choose from various models for each backend
- **Intelligent Task Parsing**: Uses LLM to understand task structure
- **Task Specifications**: Link to detailed markdown specs for complex tasks

## 🚀 Quick Start

### Prerequisites

**Required:**
- **Git** - Version control
- **GitHub CLI (gh)** - For PR creation and GitHub integration
- **LLM CLI** - For intelligent task parsing ([simonw/llm](https://github.com/simonw/llm))


**AI Backend (choose one or both):**
- **GitHub Copilot CLI** - GitHub's AI coding assistant (requires Copilot subscription)
- **Claude Code CLI** - Anthropic's agentic coding tool ([docs](https://docs.anthropic.com/en/docs/claude-code))
- **just** - Command runner (optional, but recommended) ([casey/just](https://github.com/casey/just))
- **mise** - Task runner and environment manager (optional, alternative to just) ([jdx/mise](https://github.com/jdx/mise))


### Installation

#### Quick Start with just (Recommended)

If you have [just](https://just.systems) installed, setup is simple:

```bash
# Install all dependencies and set up
just quickstart

# Authenticate with GitHub
just auth

# Configure LLM with your OpenAI API key
just config-llm

# Verify installation
just verify
```

#### Manual Installation

1. **Install just (optional but recommended):**
   ```bash
   # macOS
   brew install just

   # Linux
   cargo install just
   # or
   curl --proto '=https' --tlsv1.2 -sSf https://just.systems/install.sh | bash -s -- --to /usr/local/bin
   ```

2. **Install GitHub CLI:**
   ```bash
   # macOS
   brew install gh

   # Linux
   curl -sS https://webi.sh/gh | sh

   # Or use just
   just install
   ```

3. **Authenticate GitHub CLI:**
   ```bash
   gh auth login
   # Or use just
   just auth
   ```

4. **Install LLM CLI:**
   ```bash
   # Using pip
   pip install llm

   # Or using pipx
   pipx install llm

   # Configure with your OpenAI API key
   llm keys set openai
   # Or use just
   just config-llm
   ```

4. **Install AI Backend(s):**

   **Option A: GitHub Copilot CLI**
   ```bash
   gh extension install github/gh-copilot
   ```

   **Option B: Claude Code CLI**
   ```bash
   curl -fsSL https://claude.ai/install.sh | bash
   ```

5. **Make the script executable:**
   ```bash
   chmod +x run_copilot_automation.sh
   ```

## 📝 Usage

### Using just (Recommended)

If you have [just](https://just.systems) installed, you can use convenient command shortcuts:

```bash
# View all available commands
just --list
# or
just help

# Quick start - full setup from scratch
just quickstart

# Verify installation
just verify

# Run automation
just automate

# Dry run (no commits or PRs)
just automate-dry

# Run with custom root directory
just automate-custom ~/projects

# Show latest logs
just logs

# Search for errors in logs
just logs-errors

# Show git status
just status

# Clean old log files
just clean
```

### Using mise (Alternative)

If you prefer [mise](https://mise.jdx.dev/), you can use these task shortcuts:

```bash
# Quick start - run setup wizard
mise run setup

# Verify installation
mise run verify

# Run automation (uses default backend)
mise run automate

# Run with specific AI backend
mise run automate:copilot    # Use GitHub Copilot CLI
mise run automate:claude     # Use Claude Code CLI

# Dry run (no commits or PRs)
mise run automate:dry
mise run automate:copilot:dry
mise run automate:claude:dry

# View all available tasks
mise tasks ls

# Show latest logs
mise run logs

# Check for errors in logs
mise run logs:errors
```

### Basic Usage (without just/mise)

```bash
./run_copilot_automation.sh
```

This will:
- Scan all repositories in `~/aves`
- Process repositories with `TASKS.md` files
- Create git worktrees in `~/aves/worktrees/` for isolated work
- Create feature branches named `snowyowl-ai-<task>-<timestamp>`
- Implement tasks using AI in the worktrees
- Commit changes per task
- Clean up worktrees after completion
- Keep branches locally (no push/PR by default)

### Advanced Usage

```bash
# Specify custom root directory
./run_copilot_automation.sh --root /path/to/repos

# Use different base branch
./run_copilot_automation.sh --base-branch develop

# Select AI backend
./run_copilot_automation.sh --backend claude   # Use Claude Code
./run_copilot_automation.sh --backend copilot  # Use GitHub Copilot (default)

# Select AI model (defaults: gpt-4o for copilot, claude-sonnet-4-5-20250514 for claude)
./run_copilot_automation.sh --model gpt-4-turbo          # Use GPT-4 Turbo with Copilot
./run_copilot_automation.sh --backend claude --model claude-3-opus-20240229  # Use Claude Opus

# Enable PR creation (default: only commits locally)
./run_copilot_automation.sh --create-pr

# Dry run (no commits or PRs)
./run_copilot_automation.sh --dry-run

# Combine options
./run_copilot_automation.sh --root ~/projects --backend claude --model claude-sonnet-4-5-20250514 --create-pr

# Use environment variables
SNOWYOWL_BACKEND=claude SNOWYOWL_MODEL=claude-sonnet-4-5-20250514 SNOWYOWL_CREATE_PR=true ./run_copilot_automation.sh
```

### Options

| Option | Description | Default |
|--------|-------------|---------|
| `-r, --root DIR` | Root directory containing repositories | `$HOME/aves` |
| `-b, --base-branch` | Base branch for PRs | `main` |
| `-B, --backend NAME` | AI backend: `copilot` or `claude` | `copilot` |
| `-m, --model NAME` | AI model to use | `gpt-4o` (copilot) / `claude-sonnet-4-5-20250514` (claude) |
| `-p, --create-pr` | Enable PR creation (push to GitHub and create PR) | `false` |
| `-d, --dry-run` | Test mode - no commits or PRs | `false` |
| `-h, --help` | Show help message | - |

**Available Models:**

For GitHub Copilot (`--backend copilot`):
- `gpt-4o` (default) - Latest GPT-4 Omni model
- `gpt-4-turbo` - GPT-4 Turbo
- `gpt-4` - Standard GPT-4
- `gpt-3.5-turbo` - Faster, less expensive
- `o1-preview` - OpenAI o1 preview
- `o1-mini` - Smaller o1 variant

For Claude Code (`--backend claude`):
- `claude-sonnet-4-5-20250514` (default) - Latest Claude Sonnet 4.5
- `claude-3-5-sonnet-20241022` - Claude 3.5 Sonnet (Oct 2024)
- `claude-3-opus-20240229` - Claude 3 Opus (most capable)

## 📄 TASKS.md Format

Create a `TASKS.md` file in each repository you want to automate:

```markdown
- [ ] Implement user authentication feature
    - [ ] Add login form component
    - [ ] Implement JWT token handling
    - [ ] Add password reset functionality
- [ ] Add unit tests for authentication
- [ ] Update API documentation
```

**Format rules:**
- Tasks start with `- [ ]` (checkbox format)
- Subtasks are indented with 4 spaces
- Each task should be clear and actionable
- Tasks can be nested (parent tasks with subtasks)

## 🔧 AI Backend Integration

SnowyOwl supports multiple AI backends, each with their own CLI interface and capabilities.

### GitHub Copilot CLI

Uses programmatic mode with tool permissions:

```bash
copilot --allow-all-tools --deny-tool 'shell(rm)' < prompt.txt
```

| Flag | Purpose |
|------|---------|
| `--allow-all-tools` | Enable all tools for non-interactive mode |
| `--deny-tool 'shell(rm)'` | Prevent dangerous deletions |

### Claude Code CLI

Uses headless mode with permission controls:

```bash
claude -p "Your task prompt" \
  --allowedTools "Read,Write,Edit,Bash,Grep,Glob" \
  --permission-mode acceptEdits
```

| Flag | Purpose |
|------|---------|
| `-p` | Run in print/headless mode |
| `--allowedTools` | Specify which tools Claude can use |
| `--permission-mode` | Auto-accept edits without prompting |

### Configuration

Backend settings can be customized in `config.env`:

```bash
# Select default backend
SNOWYOWL_BACKEND="copilot"  # or "claude"

# Select default AI model (leave empty to use backend defaults)
SNOWYOWL_MODEL=""  # gpt-4o (copilot) or claude-sonnet-4-5-20250514 (claude)

# Enable PR creation by default (default: false)
SNOWYOWL_CREATE_PR=false

# Claude-specific settings
CLAUDE_ALLOWED_TOOLS="Read,Write,Edit,Bash,Grep,Glob"
CLAUDE_PERMISSION_MODE="acceptEdits"

# Copilot-specific settings
COPILOT_DENY_TOOLS="shell(rm)"
```

**Important:** By default, SnowyOwl only commits changes locally and does NOT create PRs. Use `--create-pr` flag or set `SNOWYOWL_CREATE_PR=true` in config.env to enable PR creation.

## 🛠️ Available mise Tasks
## 🛠️ Available Commands

SnowyOwl includes comprehensive command runners for common operations. You can use either **just** (recommended) or **mise**.

### Just Commands

Run `just --list` or `just help` to see all available commands. Key commands include:

| Command | Description |
|---------|-------------|
| `just quickstart` | Full setup from scratch |
| `just install` | Install all required dependencies |
| `just setup` | Run the initial setup wizard |
| `just verify` | Verify installation and dependencies |
| `just auth` | Authenticate with GitHub CLI |
| `just config-llm` | Configure LLM CLI with API key |
| `just automate` | Run the main automation workflow |
| `just automate-dry` | Run automation in dry-run mode |
| `just automate-custom <dir>` | Run with custom root directory |
| `just logs` | Show latest automation log |
| `just logs-errors` | Search for errors in logs |
| `just clean` | Clean old log files |
| `just status` | Show git status and recent branches |
| `just test` | Run test automation |
| `just sysinfo` | Show system and tool information |

### Mise Tasks

Run `mise tasks ls` to see all available tasks:

| Task | Description |
|------|-------------|
| `mise run setup` | Run the initial setup wizard |
| `mise run verify` | Verify installation and dependencies |
| `mise run automate` | Run automation with default backend |
| `mise run automate:copilot` | Run automation with Copilot backend |
| `mise run automate:claude` | Run automation with Claude backend |
| `mise run automate:dry` | Run in dry-run mode |
| `mise run automate:copilot:dry` | Copilot backend, dry-run |
| `mise run automate:claude:dry` | Claude backend, dry-run |
| `mise run automate:custom` | Run with custom options |
| `mise run install` | Install all dependencies |
| `mise run install:copilot` | Install Copilot CLI only |
| `mise run install:claude` | Install Claude Code CLI only |
| `mise run logs` | Show latest automation log |
| `mise run logs:errors` | Search for errors in logs |
| `mise run clean` | Clean old log files |
| `mise run status` | Show git status and recent branches |
| `mise run test` | Run test automation on snowyowl itself |
| `mise run help` | Show all available tasks |

## 🌙 Overnight Execution

### Using tmux/screen

```bash
# Start a tmux session
tmux new -s snowyowl

# Run the automation
./run_copilot_automation.sh
# Or with just
just tmux

# Detach with Ctrl+B, then D
```

### Using cron

```bash
# Show cron setup instructions
just cron-help

# Or manually:
# Edit crontab
crontab -e

# Add entry to run at 2 AM daily
0 2 * * * cd /path/to/snowyowl && ./run_copilot_automation.sh >> logs/cron.log 2>&1
```

### Using launchd (macOS)

```bash
# Install launchd agent (scheduled for 2 AM daily)
just install-scheduler

# Uninstall launchd agent
just uninstall-scheduler
```

## 📊 Logs

All automation runs are logged:

- **Main log:** `logs/automation_YYYYMMDD_HHMMSS.log`
- **Per-repository logs:** `logs/REPONAME_YYYYMMDD_HHMMSS.log`
- **Cron logs:** `logs/cron.log` (if using cron)

View logs:
```bash
# Latest run
ls -lt logs/ | head -1

# Follow live
tail -f logs/automation_*.log

# Search for errors
grep ERROR logs/automation_*.log
```

## 🔒 Safety Features

1. **Tool restrictions** - Only allowed tools can be executed
2. **Dry run mode** - Test without making changes
3. **Git worktrees** - Isolated work environments, no branch switching
4. **Branch isolation** - Changes in separate feature branches
5. **Local-first** - Commits locally by default (no automatic push/PR)
6. **Comprehensive logging** - Full audit trail
7. **Worktree cleanup** - Automatic cleanup after completion

## 🗂️ Project Structure

```
snowyowl/
├── run_copilot_automation.sh  # Main automation script
├── config.env                  # Configuration file
├── setup.sh                    # Setup wizard
├── verify_installation.sh      # Dependency checker
├── logs/                       # Automation logs
│   ├── automation_*.log       # Main logs
│   └── repo_*.log             # Per-repository logs
├── worktrees/                  # Git worktrees (auto-created)
│   └── reponame-branch-*      # Named: repo_name-branch_name
├── templates/                  # Task templates
└── examples/                   # Example task files
```

### Git Worktrees

SnowyOwl uses git worktrees to create isolated working directories for each task:

- **Location**: `$ROOT/worktrees/` (typically `~/aves/worktrees/`)
- **Naming**: `{repo_name}-{branch_name}` (e.g., `myapp-snowyowl-ai-feature-1234567890`)
- **Benefits**:
  - Work on multiple tasks in parallel
  - No branch switching in main repository
  - Isolated file system changes
  - Safe cleanup without affecting main repo
- **Lifecycle**:
  1. Created when task processing starts
  2. AI makes changes in the worktree
  3. Changes are committed in the worktree
  4. If `--create-pr` is enabled, branch is pushed
  5. Worktree is automatically cleaned up
  6. Branch remains in repository for review
5. **PR workflow** - All changes require review before merge

## 🎯 Best Practices

### Before Running

- ✅ Test on a single repository first
- ✅ Use `--dry-run` to preview actions
- ✅ Review existing code and tests
- ✅ Ensure clean working directory
- ✅ Verify GitHub CLI authentication

### After Running

- ✅ Review all created PRs carefully
- ✅ Check logs for errors or warnings
- ✅ Test changes locally before merging
- ✅ Validate CI/CD pipelines pass
- ✅ Update TASKS.md to mark completed items

### Writing Good Tasks

- ✅ Be specific and actionable
- ✅ Include context and requirements
- ✅ Break large tasks into subtasks
- ✅ Reference existing code patterns
- ✅ Specify desired behavior clearly

**Good:**
```markdown
- [ ] Add pagination to user list API endpoint
    - [ ] Accept page and limit query parameters
    - [ ] Return total count in response headers
    - [ ] Add validation for maximum limit of 100
```

**Not ideal:**
```markdown
- [ ] Fix the API
```

## 🏗️ Architecture

```
SnowyOwl Automation
├── run_copilot_automation.sh    # Main automation script
├── setup.sh                      # Setup wizard
├── verify_installation.sh        # Installation verification
├── copilot_integration.sh        # Copilot CLI integration
├── justfile                      # Just command runner config
├── .mise.toml                    # Mise task runner config
├── README.md                     # This file
├── TASKS.md                      # Specification document
├── config.env                    # Configuration file
├── logs/                         # Execution logs
├── templates/                    # Task templates
│   └── TASKS.template.md         # Template for new repos
└── examples/                     # Example task files
```

## 🤝 Contributing

To improve SnowyOwl:

1. Test changes in dry-run mode
2. Document new features in README
3. Add error handling for edge cases
4. Update TASKS.md specification if needed

## 📚 Examples

See the `examples/` directory for:
- Sample TASKS.md files for different project types
- Integration examples with CI/CD
- Custom workflow variations

## ⚠️ Troubleshooting

### Common Issues

**"GitHub CLI not authenticated"**
```bash
gh auth login
gh auth status
```

**"Claude Code CLI not installed"**
```bash
curl -fsSL https://claude.ai/install.sh | bash
```

**"Copilot CLI not installed"**
```bash
gh extension install github/gh-copilot
```

**"Permission denied"**
```bash
chmod +x run_copilot_automation.sh
```

**"No changes detected"**
- Verify TASKS.md format is correct
- Check repository is a git repository
- Ensure working directory is clean

**"PR creation failed"**
- Verify repository has a remote named 'origin'
- Check GitHub authentication
- Ensure base branch exists

**"AI backend implementation failed"**
- Check logs for detailed error messages
- Verify the selected backend CLI is installed
- Try running with `--dry-run` first
- Check that you have valid API credentials for the backend

## 📜 License

MIT License - see [LICENSE](LICENSE) file for details.

## 🔗 References

- [GitHub Copilot CLI Documentation](https://docs.github.com/copilot/concepts/agents/about-copilot-cli)
- [Claude Code Documentation](https://docs.anthropic.com/en/docs/claude-code)
- [GitHub CLI Documentation](https://cli.github.com/manual/)
- [Original Specification](./TASKS.md)

---

