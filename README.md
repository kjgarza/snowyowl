# 🦉 SnowyOwl - GitHub Copilot CLI Automation Workflow

An automated overnight workflow system that uses GitHub Copilot CLI to autonomously read tasks, implement code changes, and create pull requests.

## 📋 Overview

SnowyOwl automates the complete software development workflow using GitHub Copilot CLI in programmatic mode:

1. **Read** - Scans repositories for `TASKS.md` files
2. **Plan** - Generates implementation plans for each task
3. **Implement** - Makes code changes automatically
4. **Commit** - Creates clean, descriptive commits
5. **Push** - Pushes changes to GitHub
6. **PR** - Opens pull requests for review

## 🚀 Quick Start

### Prerequisites

- **Git** - Version control
- **GitHub CLI (gh)** - For PR creation and GitHub integration
- **LLM CLI** - For intelligent task parsing ([simonw/llm](https://github.com/simonw/llm))
- **GitHub Copilot CLI** - For AI-powered code generation (optional)
- **GitHub Copilot subscription** - Pro, Business, or Enterprise (optional)
- **mise** - Task runner and environment manager (optional, but recommended) ([jdx/mise](https://github.com/jdx/mise))

### Installation

1. **Install GitHub CLI:**
   ```bash
   # macOS
   brew install gh
   
   # Linux
   curl -sS https://webi.sh/gh | sh
   ```

2. **Authenticate GitHub CLI:**
   ```bash
   gh auth login
   ```

3. **Install LLM CLI:**
   ```bash
   # Using pip
   pip install llm
   
   # Or using pipx
   pipx install llm
   
   # Configure with your OpenAI API key
   llm keys set openai
   ```

4. **Install GitHub Copilot CLI (optional):**
   ```bash
   gh extension install github/gh-copilot
   ```

5. **Make the script executable:**
   ```bash
   chmod +x /Users/kristiangarza/aves/labs/snowyowl/run_copilot_automation.sh
   ```

## 📝 Usage

### Using mise (Recommended)

If you have [mise](https://mise.jdx.dev/) installed, you can use convenient task shortcuts:

```bash
# Quick start - run setup wizard
mise run setup

# Verify installation
mise run verify

# Run automation
mise run automate

# Dry run (no commits or PRs)
mise run automate:dry

# View all available tasks
mise tasks ls

# Show latest logs
mise run logs

# Check for errors in logs
mise run logs:errors
```

### Basic Usage (without mise)

```bash
./run_copilot_automation.sh
```

This will:
- Scan all repositories in `~/aves`
- Process repositories with `TASKS.md` files
- Create feature branches named `snowyowl-ai-<timestamp>`
- Commit changes per task
- Create pull requests

### Advanced Usage

```bash
# Specify custom root directory
./run_copilot_automation.sh --root /path/to/repos

# Use different base branch
./run_copilot_automation.sh --base-branch develop

# Dry run (no commits or PRs)
./run_copilot_automation.sh --dry-run

# Combine options
./run_copilot_automation.sh --root ~/projects --base-branch main --dry-run
```

### Options

| Option | Description | Default |
|--------|-------------|---------|
| `-r, --root DIR` | Root directory containing repositories | `$HOME/aves` |
| `-b, --base-branch` | Base branch for PRs | `main` |
| `-d, --dry-run` | Test mode - no commits or PRs | `false` |
| `-h, --help` | Show help message | - |

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

## 🔧 Integration with Copilot CLI

This script is designed to work **with** GitHub Copilot CLI in programmatic mode. The full integration would use:

```bash
copilot -p "Implement the plan for: <TASK>" \
  --allow-tool 'write' \
  --allow-tool 'shell(git)' \
  --allow-tool 'shell(gh)' \
  --deny-tool 'shell(rm)'
```

### Tool Permissions

| Flag | Purpose |
|------|---------|
| `--allow-tool 'write'` | Allow file modifications |
| `--allow-tool 'shell(git)'` | Allow Git commands |
| `--allow-tool 'shell(gh)'` | Allow GitHub CLI commands |
| `--deny-tool 'shell(rm)'` | Prevent dangerous deletions |

## 🛠️ Available mise Tasks

SnowyOwl includes a comprehensive set of mise tasks for common operations:

| Task | Description |
|------|-------------|
| `mise run setup` | Run the initial setup wizard |
| `mise run verify` | Verify installation and dependencies |
| `mise run automate` | Run the main automation workflow |
| `mise run automate:dry` | Run automation in dry-run mode |
| `mise run automate:custom` | Run automation with custom root directory |
| `mise run logs` | Show latest automation log |
| `mise run logs:errors` | Search for errors in logs |
| `mise run clean` | Clean old log files |
| `mise run status` | Show git status and recent branches |
| `mise run install` | Install all required dependencies |
| `mise run test` | Run test automation on snowyowl itself |
| `mise run help` | Show all available tasks |

To see all tasks with descriptions:
```bash
mise tasks ls
```

## 🌙 Overnight Execution

### Using tmux/screen

```bash
# Start a tmux session
tmux new -s snowyowl

# Run the automation
./run_copilot_automation.sh

# Detach with Ctrl+B, then D
```

### Using cron

```bash
# Edit crontab
crontab -e

# Add entry to run at 2 AM daily
0 2 * * * /Users/kristiangarza/aves/labs/snowyowl/run_copilot_automation.sh >> /Users/kristiangarza/aves/labs/snowyowl/logs/cron.log 2>&1
```

### Using launchd (macOS)

Create a launch agent plist file (see `com.snowyowl.automation.plist` for example).

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
3. **Branch isolation** - Changes in separate feature branches
4. **Comprehensive logging** - Full audit trail
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
├── README.md                     # This file
├── TASKS.md                      # Specification document
├── config.env                    # Configuration file
├── logs/                         # Execution logs
└── templates/                    # Task templates
    └── TASKS.template.md         # Template for new repos
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

## 📜 License

MIT License - see [LICENSE](LICENSE) file for details.

## 📖 Citation

If you use SnowyOwl in your research or project, please cite it using the metadata in `CITATION.cff`:

```bash
# View citation information
cat CITATION.cff
```

Or use GitHub's built-in citation feature on the repository page.

## 🔗 References

- [GitHub Copilot CLI Documentation](https://docs.github.com/copilot/concepts/agents/about-copilot-cli)
- [GitHub CLI Documentation](https://cli.github.com/manual/)
- [Original Specification](./TASKS.md)

---

**Built with ❤️ using GitHub Copilot CLI**
