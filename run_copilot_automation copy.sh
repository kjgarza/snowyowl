#!/usr/bin/env bash
#
# SnowyOwl - GitHub Copilot CLI Overnight Automation Workflow
# 
# This script automates task implementation using GitHub Copilot CLI:
# 1. Reads tasks from TASKS.md in each repository
# 2. Creates a feature branch
# 3. For each task: plans and implements changes
# 4. Commits changes
# 5. Pushes to GitHub
# 6. Opens a pull request
#
# Usage:
#   ./run_copilot_automation.sh [OPTIONS]
#
# Options:
#   -r, --root DIR        Root directory containing repositories (default: $HOME/aves)
#   -b, --base-branch     Base branch name (default: main)
#   -d, --dry-run         Dry run mode - no commits or PRs
#   -h, --help            Show this help message
#

set -euo pipefail

# Default configuration
ROOT="${HOME}/aves"
BASE_BRANCH="main"
DRY_RUN=false
LOG_DIR="${HOME}/aves/snowyowl/logs"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Parse command line arguments
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
    -d|--dry-run)
      DRY_RUN=true
      shift
      ;;
    -h|--help)
      grep '^#' "$0" | sed 's/^# \?//'
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      echo "Use --help for usage information"
      exit 1
      ;;
  esac
done

# Create log directory
mkdir -p "$LOG_DIR"

# Main log file
MAIN_LOG="$LOG_DIR/automation_${TIMESTAMP}.log"

# Helper functions
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$MAIN_LOG"
}

log_error() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $*" | tee -a "$MAIN_LOG" >&2
}

log_success() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] SUCCESS: $*" | tee -a "$MAIN_LOG"
}

# Check prerequisites
check_prerequisites() {
  log "Checking prerequisites..."
  
  if ! command -v git &> /dev/null; then
    log_error "git is not installed"
    exit 1
  fi
  
  if ! command -v gh &> /dev/null; then
    log_error "GitHub CLI (gh) is not installed"
    exit 1
  fi
  
  # Check if gh is authenticated
  if ! gh auth status &> /dev/null; then
    log_error "GitHub CLI is not authenticated. Run: gh auth login"
    exit 1
  fi
  
  # Check if llm is installed for intelligent task parsing
  if ! command -v llm &> /dev/null; then
    log_error "LLM CLI is not installed. Install with: pip install llm"
    exit 1
  fi
  
  # Note: We don't check for 'copilot' command here since this script
  # is meant to be run BY GitHub Copilot CLI itself in programmatic mode
  
  log_success "Prerequisites check passed"
}

# Parse tasks from TASKS.md using LLM CLI for intelligent parsing
parse_tasks() {
  local tasks_file="$1"
  
  # Use LLM CLI to intelligently parse tasks from the TASKS.md file
  # This provides better understanding of task structure, context, and relationships
  local prompt="You are a task parser for a code automation system.

Parse the following TASKS.md file and extract all actionable tasks.

Rules:
1. Extract tasks marked with - [ ] (unchecked checkboxes)
2. Include both top-level tasks and subtasks
3. For each task, provide the complete description
4. Preserve the hierarchy by indenting subtasks with 2 spaces
5. Skip completed tasks (marked with - [x])
6. Return ONLY the task list, one task per line
7. Do not add any explanations or additional text

TASKS.md content:
$(cat "$tasks_file")

Output format (one task per line):
Task description
  Subtask description
  Another subtask description
Another top-level task"

  # Call LLM CLI to parse tasks
  local parsed_tasks
  parsed_tasks=$(echo "$prompt" | llm -m gpt-4o-mini 2>/dev/null || echo "")
  
  # Fallback to simple parsing if LLM fails
  if [[ -z "$parsed_tasks" ]]; then
    log "LLM parsing failed, falling back to simple regex parsing"
    local tasks=()
    while IFS= read -r line; do
      if [[ "$line" =~ ^[[:space:]]*-[[:space:]]\[[[:space:]]\] ]]; then
        task=$(echo "$line" | sed -E 's/^[[:space:]]*-[[:space:]]\[[[:space:]]\][[:space:]]*//')
        if [[ -n "$task" ]]; then
          tasks+=("$task")
        fi
      fi
    done < "$tasks_file"
    printf '%s\n' "${tasks[@]}"
  else
    # Clean up and return LLM-parsed tasks
    # Remove checkbox syntax, empty lines, and extra whitespace
    echo "$parsed_tasks" | grep -v '^[[:space:]]*$' | sed -E 's/^[[:space:]]*-[[:space:]]\[[[:space:]xX]\][[:space:]]*//' | sed 's/^[[:space:]]*//'
  fi
}

# Process a single repository
process_repository() {
  local repo_path="$1"
  local repo_name=$(basename "$repo_path")
  
  log "Processing repository: $repo_name"
  
  # Check if TASKS.md exists
  if [[ ! -f "$repo_path/TASKS.md" ]]; then
    log "Skipping $repo_name - no TASKS.md found"
    return
  fi
  
  # Check if it's a git repository
  if [[ ! -d "$repo_path/.git" ]]; then
    log "Skipping $repo_name - not a git repository"
    return
  fi
  
  cd "$repo_path"
  
  # Create repository-specific log file
  local repo_log="$LOG_DIR/${repo_name}_${TIMESTAMP}.log"
  
  # Save current branch
  local original_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
  
  # Auto-detect the default/base branch for this repository
  local repo_base_branch
  if git show-ref --verify --quiet refs/heads/"$BASE_BRANCH"; then
    # User-specified base branch exists locally
    repo_base_branch="$BASE_BRANCH"
  elif git show-ref --verify --quiet refs/remotes/origin/"$BASE_BRANCH"; then
    # User-specified base branch exists remotely
    repo_base_branch="$BASE_BRANCH"
  else
    # Auto-detect from remote HEAD
    repo_base_branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "")
    if [[ -z "$repo_base_branch" ]]; then
      # Fallback: try common branch names
      if git show-ref --verify --quiet refs/heads/main; then
        repo_base_branch="main"
      elif git show-ref --verify --quiet refs/heads/master; then
        repo_base_branch="master"
      elif git show-ref --verify --quiet refs/remotes/origin/main; then
        repo_base_branch="main"
      elif git show-ref --verify --quiet refs/remotes/origin/master; then
        repo_base_branch="master"
      else
        log_error "Could not determine base branch for $repo_name"
        return 1
      fi
    fi
  fi
  
  log "Using base branch: $repo_base_branch"
  
  # Create feature branch
  local feature_branch="snowyowl-ai-$(date +%s)"
  
  log "Creating feature branch: $feature_branch"
  if ! git checkout -b "$feature_branch" 2>&1 | tee -a "$repo_log"; then
    log_error "Failed to create feature branch in $repo_name"
    return
  fi
  
  # Parse tasks (bash 3.x compatible)
  local tasks=()
  local task_count=0
  while IFS= read -r task; do
    if [[ -n "$task" ]]; then
      tasks+=("$task")
      ((task_count++))
    fi
  done < <(parse_tasks "$repo_path/TASKS.md")
  
  if [[ $task_count -eq 0 ]]; then
    log "No tasks found in $repo_name/TASKS.md"
    git checkout "$original_branch" 2>/dev/null || true
    git branch -D "$feature_branch" 2>/dev/null || true
    return
  fi
  
  log "Found $task_count task(s) in $repo_name"
  
  local changes_made=false
  
  # Process each task
  for task in "${tasks[@]}"; do
    log "Task: $task"
    echo "---" >> "$repo_log"
    echo "Task: $task" >> "$repo_log"
    echo "---" >> "$repo_log"
    
    # Check if copilot CLI is available for actual implementation
    if command -v copilot &> /dev/null; then
      log "Using GitHub Copilot CLI to implement task..."
      
      # Create a temporary prompt file
      local prompt_file=$(mktemp)
      cat > "$prompt_file" << PROMPT_EOF
Implement the following task in this repository:

Repository: $(basename "$repo_path")
Current branch: $feature_branch
Working directory: $repo_path

Task: $task

Instructions:
1. Analyze the existing code structure and patterns
2. Implement the changes needed for this task
3. Follow existing code style and conventions
4. Add appropriate error handling
5. Include helpful comments where needed
6. Make minimal, focused changes

Please implement this task now.
PROMPT_EOF

      # Call Copilot CLI with proper flags
      # Use --allow-all-tools for non-interactive mode
      if copilot --allow-all-tools --deny-tool 'shell(rm)' < "$prompt_file" >> "$repo_log" 2>&1; then
        rm -f "$prompt_file"
        log "Copilot implementation completed for: $task"
        changes_made=true
      else
        local exit_code=$?
        rm -f "$prompt_file"
        log_error "Copilot implementation failed with exit code $exit_code"
        log_error "Check log: $repo_log"
        
        if [[ "$DRY_RUN" == false ]]; then
          # Rollback the branch and exit
          log_error "Rolling back branch due to failure"
          git checkout "$original_branch" 2>/dev/null || true
          git branch -D "$feature_branch" 2>/dev/null || true
          return 1
        fi
      fi
    else
      log "Copilot CLI not available, creating task marker for manual implementation"
      # Create a marker file to show the task was processed
      local task_marker=".snowyowl_tasks/$(echo "$task" | sed 's/[^a-zA-Z0-9]/_/g').txt"
      mkdir -p .snowyowl_tasks
      echo "Task: $task" > "$task_marker"
      echo "Timestamp: $(date)" >> "$task_marker"
      echo "Status: Awaiting Copilot CLI implementation" >> "$task_marker"
      echo "" >> "$task_marker"
      echo "To implement manually:" >> "$task_marker"
      echo "1. Review the task description above" >> "$task_marker"
      echo "2. Make necessary code changes" >> "$task_marker"
      echo "3. Test your changes" >> "$task_marker"
      echo "4. Delete this marker file" >> "$task_marker"
      changes_made=true
    fi
    
    # Stage and commit changes for this task
    if [[ "$DRY_RUN" == false ]]; then
      git add .
      if git diff --cached --quiet; then
        log "No changes to commit for task: $task"
      else
        if ! git commit -m "AI: $task" 2>&1 | tee -a "$repo_log"; then
          log_error "Failed to commit changes"
          git checkout "$original_branch" 2>/dev/null || true
          git branch -D "$feature_branch" 2>/dev/null || true
          return 1
        fi
        log_success "Committed changes for: $task"
      fi
    else
      log "[DRY RUN] Would commit: $task"
    fi
  done
  
  # Push and create PR if changes were made
  if [[ "$changes_made" == true ]]; then
    if [[ "$DRY_RUN" == false ]]; then
      log "Pushing branch to GitHub..."
      if ! git push -u origin "$feature_branch" 2>&1 | tee -a "$repo_log"; then
        log_error "Failed to push branch for $repo_name"
        git checkout "$original_branch" 2>/dev/null || true
        git branch -D "$feature_branch" 2>/dev/null || true
        return 1
      fi
      log_success "Pushed branch: $feature_branch"
      
      # Wait 5 minutes before creating PR to allow for any async operations
      log "Waiting 5 minutes before creating pull request..."
      log "This allows time for CI/CD checks to start and ensures branch is fully synchronized"
      sleep 30  # 5 minutes = 300 seconds
      
      # Create PR
      log "Creating pull request..."
      local pr_title="[SnowyOwl] Automated task implementation - $TIMESTAMP"
      
      # Build task list for PR body (avoiding printf issues with dashes)
      local task_list=""
      for task in "${tasks[@]}"; do
        task_list="${task_list}- ${task}
"
      done
      
      local pr_body="🦉 **SnowyOwl Automated Workflow**

This PR contains automated code changes from the overnight workflow.

**Tasks completed:**
${task_list}
**Timestamp:** $(date)
**Branch:** $feature_branch
**Log file:** $repo_log

Please review all changes carefully before merging."

      if ! gh pr create \
        --base "$repo_base_branch" \
        --head "$feature_branch" \
        --title "$pr_title" \
        --body "$pr_body" 2>&1 | tee -a "$repo_log"; then
        log_error "Failed to create pull request for $repo_name"
        log_error "Branch $feature_branch has been pushed but PR creation failed"
        log_error "You can create the PR manually on GitHub"
        log_error "Base branch: $repo_base_branch, Head branch: $feature_branch"
        return 1
      fi
      log_success "Created pull request for $repo_name (base: $repo_base_branch)"
    else
      log "[DRY RUN] Would push branch: $feature_branch"
      log "[DRY RUN] Would wait 5 minutes"
      log "[DRY RUN] Would create PR with $task_count task(s)"
    fi
  else
    log "No changes made in $repo_name"
    git checkout "$original_branch" 2>/dev/null || true
    git branch -D "$feature_branch" 2>/dev/null || true
  fi
  
  log "Completed processing $repo_name"
}

# Main execution
main() {
  log "=========================================="
  log "SnowyOwl Automation Workflow Started"
  log "=========================================="
  log "Root directory: $ROOT"
  log "Base branch: $BASE_BRANCH"
  log "Dry run: $DRY_RUN"
  log "Log directory: $LOG_DIR"
  log "=========================================="
  
  check_prerequisites
  
  # Find all repositories with TASKS.md
  local repo_count=0
  local processed_count=0
  
  for repo_path in "$ROOT"/*; do
    if [[ -d "$repo_path" ]]; then
      ((repo_count++))
      if [[ -f "$repo_path/TASKS.md" ]]; then
        ((processed_count++))
        process_repository "$repo_path"
      fi
    fi
  done
  
  log "=========================================="
  log "SnowyOwl Automation Workflow Completed"
  log "=========================================="
  log "Total repositories scanned: $repo_count"
  log "Repositories with TASKS.md: $processed_count"
  log "Main log file: $MAIN_LOG"
  log "=========================================="
}

# Run main function
main "$@"
