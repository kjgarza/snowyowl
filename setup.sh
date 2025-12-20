#!/usr/bin/env bash
#
# SnowyOwl Setup Script
# 
# This script helps set up the SnowyOwl automation environment
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLIST_FILE="$SCRIPT_DIR/com.snowyowl.automation.plist"
LAUNCHD_DIR="$HOME/Library/LaunchAgents"

echo "🦉 SnowyOwl Setup"
echo "================="
echo

# Check prerequisites
check_prerequisites() {
    echo "Checking prerequisites..."
    
    local all_good=true
    
    if ! command -v git &> /dev/null; then
        echo "❌ git is not installed"
        all_good=false
    else
        echo "✅ git is installed"
    fi
    
    if ! command -v gh &> /dev/null; then
        echo "❌ GitHub CLI (gh) is not installed"
        echo "   Install with: brew install gh"
        all_good=false
    else
        echo "✅ GitHub CLI is installed"
        
        if ! gh auth status &> /dev/null; then
            echo "⚠️  GitHub CLI is not authenticated"
            echo "   Run: gh auth login"
            all_good=false
        else
            echo "✅ GitHub CLI is authenticated"
        fi
    fi
    
    if ! command -v llm &> /dev/null; then
        echo "❌ LLM CLI is not installed"
        echo "   Install with: pip install llm"
        echo "   Then configure: llm keys set openai"
        all_good=false
    else
        echo "✅ LLM CLI is installed"
    fi
    
    if ! command -v copilot &> /dev/null; then
        echo "ℹ️  GitHub Copilot CLI not found (optional for testing)"
        echo "   Install with: gh extension install github/gh-copilot"
    else
        echo "✅ GitHub Copilot CLI is installed"
    fi
    
    if [[ "$all_good" == false ]]; then
        echo
        echo "❌ Please install missing prerequisites before continuing"
        exit 1
    fi
    
    echo
}

# Make script executable
make_executable() {
    echo "Making automation script executable..."
    chmod +x "$SCRIPT_DIR/run_copilot_automation.sh"
    echo "✅ Script is now executable"
    echo
}

# Install launchd agent
install_launchd() {
    echo "Installing launchd agent for scheduled runs..."
    
    mkdir -p "$LAUNCHD_DIR"
    
    if [[ -f "$LAUNCHD_DIR/com.snowyowl.automation.plist" ]]; then
        echo "⚠️  Existing launchd agent found. Unloading..."
        launchctl unload "$LAUNCHD_DIR/com.snowyowl.automation.plist" 2>/dev/null || true
    fi
    
    cp "$PLIST_FILE" "$LAUNCHD_DIR/"
    launchctl load "$LAUNCHD_DIR/com.snowyowl.automation.plist"
    
    echo "✅ Launchd agent installed and loaded"
    echo "   Scheduled to run daily at 2:00 AM"
    echo
}

# Show menu
show_menu() {
    echo "What would you like to do?"
    echo
    echo "1. Run full setup (check prerequisites + make executable + install launchd)"
    echo "2. Just check prerequisites"
    echo "3. Make script executable only"
    echo "4. Install/update launchd agent only"
    echo "5. Uninstall launchd agent"
    echo "6. Test run (dry-run mode)"
    echo "7. View logs"
    echo "8. Exit"
    echo
    read -p "Enter your choice (1-8): " choice
    echo
    
    case $choice in
        1)
            check_prerequisites
            make_executable
            # install_launchd
            echo "✅ Setup complete!"
            ;;
        2)
            check_prerequisites
            ;;
        3)
            make_executable
            ;;
        4)
            install_launchd
            ;;
        5)
            echo "Uninstalling launchd agent..."
            launchctl unload "$LAUNCHD_DIR/com.snowyowl.automation.plist" 2>/dev/null || true
            rm -f "$LAUNCHD_DIR/com.snowyowl.automation.plist"
            echo "✅ Launchd agent uninstalled"
            ;;
        6)
            echo "Running test in dry-run mode..."
            echo
            "$SCRIPT_DIR/run_copilot_automation.sh" --dry-run
            ;;
        7)
            echo "Recent log files:"
            echo
            ls -lt "$SCRIPT_DIR/logs/" 2>/dev/null | head -10 || echo "No logs found"
            echo
            read -p "Enter log file name to view (or press Enter to skip): " logfile
            if [[ -n "$logfile" ]]; then
                less "$SCRIPT_DIR/logs/$logfile"
            fi
            ;;
        8)
            echo "Goodbye! 🦉"
            exit 0
            ;;
        *)
            echo "Invalid choice"
            exit 1
            ;;
    esac
}

# Main
main() {
    show_menu
    
    echo
    echo "Next steps:"
    echo "1. Create TASKS.md files in your repositories"
    echo "2. Use the template: $SCRIPT_DIR/templates/TASKS.template.md"
    echo "3. See examples in: $SCRIPT_DIR/examples/"
    echo "4. Run manually: $SCRIPT_DIR/run_copilot_automation.sh"
    echo "5. Check logs in: $SCRIPT_DIR/logs/"
    echo
}

main "$@"
