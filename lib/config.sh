#!/usr/bin/env bash
#
# SnowyOwl Configuration Module
#
# Handles configuration, environment setup, argument parsing, and logging functions.
# This module should be sourced by the main script.
#

# Default configuration
ROOT="${HOME}/aves"
BASE_BRANCH="main"
DRY_RUN=false
CREATE_PR="${SNOWYOWL_CREATE_PR:-false}"
LOG_DIR="${HOME}/aves/snowyowl/logs"
WORKTREES_DIR="${SNOWYOWL_WORKTREES_DIR:-${ROOT}/worktrees}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# AI Backend configuration
AI_BACKEND="${SNOWYOWL_BACKEND:-copilot}"

# AI Model configuration
AI_MODEL="${SNOWYOWL_MODEL:-}"

# Claude-specific settings
CLAUDE_ALLOWED_TOOLS="${CLAUDE_ALLOWED_TOOLS:-Read,Write,Edit,Bash,Grep,Glob}"
CLAUDE_PERMISSION_MODE="${CLAUDE_PERMISSION_MODE:-acceptEdits}"

# Copilot-specific settings
COPILOT_DENY_TOOLS="${COPILOT_DENY_TOOLS:-shell(rm)}"

# Worktree cleanup (disabled by default to preserve work)
CLEANUP_WORKTREES="${SNOWYOWL_CLEANUP_WORKTREES:-false}"

# Parse command line arguments
parse_arguments() {
  while [[ $# -gt 0 ]]; do
    case $1 in
      -r|--root)
        ROOT="$2"
        shift 2
        ;;
      -b|--base-branch)
        BASE_BRANCH="$2"
        shift 2
        ;;
      -B|--backend)
        AI_BACKEND="$2"
        if [[ "$AI_BACKEND" != "copilot" && "$AI_BACKEND" != "claude" ]]; then
          echo "Error: Invalid backend '$AI_BACKEND'. Must be 'copilot' or 'claude'"
          exit 1
        fi
        shift 2
        ;;
      -m|--model)
        AI_MODEL="$2"
        shift 2
        ;;
      -p|--create-pr)
        CREATE_PR=true
        shift
        ;;
      -d|--dry-run)
        DRY_RUN=true
        shift
        ;;
      --cleanup-worktrees)
        CLEANUP_WORKTREES=true
        shift
        ;;
      -h|--help)
        show_help
        exit 0
        ;;
      *)
        echo "Unknown option: $1"
        echo "Use --help for usage information"
        exit 1
        ;;
    esac
  done
}

# Show help message
show_help() {
  cat << 'EOF'
SnowyOwl - AI-Powered Overnight Automation Workflow

This script automates task implementation using AI coding assistants:
1. Reads tasks from TASKS.md in each repository
2. Creates a feature branch
3. For each task: plans and implements changes
4. Commits changes
5. Pushes to GitHub
6. Opens a pull request

Supports multiple AI backends:
  - copilot: GitHub Copilot CLI (default)
  - claude: Anthropic Claude Code CLI

Usage:
  ./run_copilot_automation.sh [OPTIONS]

Options:
  -r, --root DIR        Root directory containing repositories (default: $HOME/aves)
  -b, --base-branch     Base branch name (default: main)
  -B, --backend NAME    AI backend to use: copilot, claude (default: copilot)
  -m, --model NAME      AI model to use (default: gpt-4o for copilot, claude-sonnet-4-5 for claude)
  -p, --create-pr       Enable PR creation (default: false - only commit locally)
  -d, --dry-run         Dry run mode - no commits or PRs
  --cleanup-worktrees   Remove worktrees after completion (default: false - keep worktrees)
  -h, --help            Show this help message
EOF
}

# Set default model based on backend if not specified
set_default_model() {
  if [[ -z "$AI_MODEL" ]]; then
    case "$AI_BACKEND" in
      claude)
        AI_MODEL="claude-sonnet-4-5"
        ;;
      copilot|*)
        AI_MODEL="gpt-4o"
        ;;
    esac
  fi
}

# Initialize directories and log file
init_directories() {
  mkdir -p "$LOG_DIR"
  mkdir -p "$WORKTREES_DIR"
  MAIN_LOG="$LOG_DIR/automation_${TIMESTAMP}.log"
}

# Logging functions
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$MAIN_LOG"
}

log_error() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $*" | tee -a "$MAIN_LOG" >&2
}

log_success() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] SUCCESS: $*" | tee -a "$MAIN_LOG"
}

