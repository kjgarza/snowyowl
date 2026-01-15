# SnowyOwl Justfile
# Run tasks with: just <recipe-name>
# See all recipes: just --list

# Default recipe - show help
default:
    @just --list

# === Setup and Installation ===

# Run full setup (check prerequisites, make executable, configure)
setup:
    @echo "🦉 Running SnowyOwl setup..."
    ./setup.sh

# Install all required dependencies
install:
    @echo "📦 Installing dependencies..."
    @# Check for Homebrew on macOS
    @if [ "$(uname)" = "Darwin" ] && ! command -v brew >/dev/null 2>&1; then \
        echo "Installing Homebrew..."; \
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; \
    fi
    @# Install GitHub CLI
    @if ! command -v gh >/dev/null 2>&1; then \
        echo "Installing GitHub CLI..."; \
        if [ "$(uname)" = "Darwin" ]; then \
            brew install gh; \
        else \
            curl -sS https://webi.sh/gh | sh; \
        fi; \
    else \
        echo "✅ GitHub CLI already installed"; \
    fi
    @# Install LLM CLI
    @if ! command -v llm >/dev/null 2>&1; then \
        echo "Installing LLM CLI..."; \
        pip install llm || pipx install llm; \
    else \
        echo "✅ LLM CLI already installed"; \
    fi
    @# Install GitHub Copilot CLI extension
    @if ! gh extension list | grep -q gh-copilot 2>/dev/null; then \
        echo "Installing GitHub Copilot CLI..."; \
        gh extension install github/gh-copilot; \
    else \
        echo "✅ GitHub Copilot CLI already installed"; \
    fi
    @echo ""
    @echo "✅ All dependencies installed!"
    @echo ""
    @echo "Next steps:"
    @echo "  1. Authenticate: just auth"
    @echo "  2. Verify setup: just verify"

# Make scripts executable
make-executable:
    @echo "🔧 Making scripts executable..."
    @chmod +x run_copilot_automation.sh
    @chmod +x setup.sh
    @chmod +x verify_installation.sh
    @chmod +x copilot_integration.sh
    @echo "✅ Scripts are now executable"

# Authenticate with GitHub CLI
auth:
    @echo "🔐 Authenticating with GitHub..."
    gh auth login

# Verify authentication status
auth-status:
    @echo "🔍 Checking authentication status..."
    @gh auth status

# Configure LLM CLI with OpenAI key
config-llm:
    @echo "🔧 Configuring LLM CLI..."
    llm keys set openai

# Verify installation and dependencies
verify:
    @echo "🔍 Verifying installation..."
    ./verify_installation.sh

# === Running Automation ===

# Run the main automation workflow
automate:
    @echo "🦉 Running automation..."
    ./run_copilot_automation.sh

# Run automation in dry-run mode (no commits or PRs)
automate-dry:
    @echo "🦉 Running automation in dry-run mode..."
    ./run_copilot_automation.sh --dry-run

# Run automation with custom root directory
automate-custom ROOT_DIR="~/aves":
    @echo "🦉 Running automation with root: {{ROOT_DIR}}"
    ./run_copilot_automation.sh --root {{ROOT_DIR}}

# Run automation with custom base branch
automate-branch BRANCH="main":
    @echo "🦉 Running automation with base branch: {{BRANCH}}"
    ./run_copilot_automation.sh --base-branch {{BRANCH}}

# Run automation with all custom options
automate-full ROOT_DIR="~/aves" BRANCH="main" DRY_RUN="false":
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🦉 Running automation with custom options..."
    echo "  Root: {{ROOT_DIR}}"
    echo "  Branch: {{BRANCH}}"
    echo "  Dry-run: {{DRY_RUN}}"
    if [ "{{DRY_RUN}}" = "true" ]; then
        ./run_copilot_automation.sh --root {{ROOT_DIR}} --base-branch {{BRANCH}} --dry-run
    else
        ./run_copilot_automation.sh --root {{ROOT_DIR}} --base-branch {{BRANCH}}
    fi

# === Logs and Monitoring ===

# Show latest automation log
logs:
    #!/usr/bin/env bash
    LOG_FILE=$(ls -t logs/automation_*.log 2>/dev/null | head -1)
    if [ -n "$LOG_FILE" ]; then
        echo "📋 Showing latest log: $LOG_FILE"
        tail -f "$LOG_FILE"
    else
        echo "❌ No log files found"
    fi

# Show last N lines of latest log
logs-tail N="50":
    #!/usr/bin/env bash
    LOG_FILE=$(ls -t logs/automation_*.log 2>/dev/null | head -1)
    if [ -n "$LOG_FILE" ]; then
        echo "📋 Last {{N}} lines of: $LOG_FILE"
        tail -n {{N}} "$LOG_FILE"
    else
        echo "❌ No log files found"
    fi

# Search for errors in logs
logs-errors:
    @echo "🔍 Searching for errors in logs..."
    @grep -i 'error\|fail' logs/*.log 2>/dev/null || echo "✅ No errors found"

# List all log files
logs-list:
    @echo "📋 Available log files:"
    @ls -lht logs/*.log 2>/dev/null || echo "No log files found"

# View a specific log file
logs-view LOGFILE:
    @less logs/{{LOGFILE}}

# === Maintenance ===

# Clean old log files (keep last 10)
clean:
    #!/usr/bin/env bash
    echo "🧹 Cleaning old log files..."
    cd logs
    LOG_COUNT=$(ls -t automation_*.log 2>/dev/null | wc -l)
    if [ "$LOG_COUNT" -gt 10 ]; then
        ls -t automation_*.log | tail -n +11 | xargs rm -f
        echo "✅ Cleaned $((LOG_COUNT - 10)) old log files"
    else
        echo "✅ No cleanup needed (only $LOG_COUNT log files)"
    fi

# Clean all log files
clean-all:
    @echo "🧹 Cleaning all log files..."
    @rm -f logs/*.log
    @echo "✅ All log files removed"

# Show git status and recent SnowyOwl branches
status:
    @echo "=== Current Status ==="
    @git status -s
    @echo ""
    @echo "=== Recent SnowyOwl Branches ==="
    @git branch -a | grep snowyowl | tail -5 || echo "No SnowyOwl branches found"

# Show recent commits
recent:
    @echo "📜 Recent commits:"
    @git log --oneline -10

# === Testing ===

# Run a test automation on snowyowl itself (dry-run)
test:
    @echo "🧪 Running test automation..."
    ./run_copilot_automation.sh --dry-run

# Test Copilot CLI integration
test-copilot:
    @echo "🧪 Testing Copilot CLI..."
    ./copilot_integration.sh

# === Scheduled Execution ===

# Install launchd agent for scheduled runs (macOS only)
install-scheduler:
    #!/usr/bin/env bash
    if [ "$(uname)" != "Darwin" ]; then
        echo "❌ This recipe is only for macOS"
        exit 1
    fi
    echo "📅 Installing launchd agent..."
    mkdir -p "$HOME/Library/LaunchAgents"
    cp com.snowyowl.automation.plist "$HOME/Library/LaunchAgents/"
    launchctl load "$HOME/Library/LaunchAgents/com.snowyowl.automation.plist"
    echo "✅ Launchd agent installed and loaded"
    echo "   Scheduled to run daily at 2:00 AM"

# Uninstall launchd agent (macOS only)
uninstall-scheduler:
    #!/usr/bin/env bash
    if [ "$(uname)" != "Darwin" ]; then
        echo "❌ This recipe is only for macOS"
        exit 1
    fi
    echo "📅 Uninstalling launchd agent..."
    launchctl unload "$HOME/Library/LaunchAgents/com.snowyowl.automation.plist" 2>/dev/null || true
    rm -f "$HOME/Library/LaunchAgents/com.snowyowl.automation.plist"
    echo "✅ Launchd agent uninstalled"

# Show cron setup instructions
cron-help:
    @echo "📅 To schedule with cron (Linux/macOS):"
    @echo ""
    @echo "1. Edit crontab:"
    @echo "   crontab -e"
    @echo ""
    @echo "2. Add entry to run at 2 AM daily:"
    @echo "   0 2 * * * $(pwd)/run_copilot_automation.sh >> $(pwd)/logs/cron.log 2>&1"
    @echo ""
    @echo "3. Verify cron is scheduled:"
    @echo "   crontab -l"

# Start tmux session for long-running automation
tmux:
    @echo "🖥️  Starting tmux session..."
    @tmux new -s snowyowl || tmux attach -t snowyowl

# === Information ===

# Show environment configuration
show-config:
    @echo "⚙️  SnowyOwl Configuration:"
    @cat config.env

# Show system information
sysinfo:
    @echo "🖥️  System Information:"
    @echo "OS: $(uname -s)"
    @echo "Architecture: $(uname -m)"
    @echo "Kernel: $(uname -r)"
    @echo ""
    @echo "📦 Installed Tools:"
    @command -v git >/dev/null && echo "  ✅ git: $(git --version)" || echo "  ❌ git: not installed"
    @command -v gh >/dev/null && echo "  ✅ gh: $(gh --version | head -1)" || echo "  ❌ gh: not installed"
    @command -v llm >/dev/null && echo "  ✅ llm: $(llm --version)" || echo "  ❌ llm: not installed"
    @command -v copilot >/dev/null && echo "  ✅ copilot: installed" || echo "  ⚠️  copilot: not installed (optional)"
    @command -v just >/dev/null && echo "  ✅ just: $(just --version)" || echo "  ❌ just: not installed"

# Show help and available recipes
help:
    @echo "🦉 SnowyOwl - GitHub Copilot CLI Automation"
    @echo ""
    @echo "Available recipes:"
    @just --list
    @echo ""
    @echo "Examples:"
    @echo "  just install              # Install all dependencies"
    @echo "  just setup                # Run setup wizard"
    @echo "  just verify               # Verify installation"
    @echo "  just automate             # Run automation"
    @echo "  just automate-dry         # Dry-run mode"
    @echo "  just logs                 # View latest log"
    @echo "  just status               # Show git status"
    @echo ""
    @echo "For more info: https://github.com/yourusername/snowyowl"

# Quick start - full setup from scratch
quickstart:
    @echo "🚀 Quick Start - Setting up SnowyOwl..."
    @echo ""
    just install
    @echo ""
    just make-executable
    @echo ""
    just verify
    @echo ""
    @echo "✅ Quick start complete!"
    @echo ""
    @echo "Next steps:"
    @echo "  1. Authenticate: just auth"
    @echo "  2. Configure LLM: just config-llm"
    @echo "  3. Run automation: just automate-dry"
