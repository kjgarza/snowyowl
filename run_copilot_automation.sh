#!/usr/bin/env bash
#
# SnowyOwl - AI-Powered Overnight Automation Workflow
# 
# This script automates task implementation using AI coding assistants:
# 1. Reads tasks from TASKS.md in each repository
# 2. Creates git worktrees for isolated work
# 3. For each task: plans and implements changes
# 4. Commits changes in worktrees
# 5. Optionally pushes to GitHub and opens pull requests
#
# Supports multiple AI backends:
#   - copilot: GitHub Copilot CLI (default)
#   - claude: Anthropic Claude Code CLI
#

set -euo pipefail

# Get script directory for sourcing modules
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source all library modules
source "$SCRIPT_DIR/lib/config.sh"
source "$SCRIPT_DIR/lib/git_utils.sh"
source "$SCRIPT_DIR/lib/ai_backends.sh"
source "$SCRIPT_DIR/lib/task_processing.sh"

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
    repo_base_branch="$BASE_BRANCH"
  elif git show-ref --verify --quiet refs/remotes/origin/"$BASE_BRANCH"; then
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
  
  # Parse tasks
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
    return
  fi
  
  log "Found $task_count task(s) in $repo_name"
  
  local current_branch=""
  local current_worktree=""
  local current_tasks=()
  
  # Process each task
  for task_line in "${tasks[@]}"; do
    # Check indentation to determine if subtask
    local is_subtask=false
    local clean_task="$task_line"
    
    if [[ "$task_line" =~ ^[[:space:]] ]]; then
      is_subtask=true
      clean_task=$(echo "$task_line" | sed 's/^[[:space:]]*//')
    fi
    
    # If top-level task, create new worktree
    if [[ "$is_subtask" == false ]]; then
      # Finish previous worktree if exists
      if [[ -n "$current_branch" && -n "$current_worktree" ]]; then
        create_pr_for_branch "$repo_path" "$repo_name" "$current_worktree" "$current_branch" "$repo_base_branch" "$repo_log" "$DRY_RUN" "$CREATE_PR" "${current_tasks[@]}"
      fi
      
      # Start new branch and worktree
      local link_info=$(extract_task_link "$clean_task")
      local task_title=$(echo "$link_info" | cut -d'|' -f1)
      
      # Generate branch name using LLM slug
      local branch_slug
      branch_slug=$(generate_branch_slug "$task_title")
      current_branch="${branch_slug}-$(date +%s)"
      
      # Create worktree
      current_worktree=$(create_worktree "$repo_path" "$repo_name" "$current_branch" "$repo_base_branch" "$repo_log")
      if [[ -z "$current_worktree" || ! -d "$current_worktree" ]]; then
        log_error "Failed to create worktree for $current_branch in $repo_name"
        current_branch=""
        current_worktree=""
        continue
      fi
      current_tasks=()
    fi
    
    # Implement task (only if we have a valid worktree)
    if [[ -n "$current_branch" && -n "$current_worktree" ]]; then
      local link_info=$(extract_task_link "$clean_task")
      local task_title=$(echo "$link_info" | cut -d'|' -f1)
      local task_link=$(echo "$link_info" | cut -d'|' -f2)
      
      if implement_task "$repo_path" "$current_worktree" "$task_title" "$task_link" "$repo_log" "$DRY_RUN"; then
        current_tasks+=("$task_title")
      else
        log_error "Failed to implement task: $task_title"
      fi
    else
       log_error "Skipping task because worktree creation failed: $clean_task"
    fi
  done
  
  # Finish last worktree
  if [[ -n "$current_branch" && -n "$current_worktree" ]]; then
    create_pr_for_branch "$repo_path" "$repo_name" "$current_worktree" "$current_branch" "$repo_base_branch" "$repo_log" "$DRY_RUN" "$CREATE_PR" "${current_tasks[@]}"
  fi
  
  # Return to repo path
  cd "$repo_path"
  
  # Restore original branch if it wasn't the base branch
  if [[ -n "$original_branch" && "$original_branch" != "$repo_base_branch" ]]; then
    git checkout "$original_branch" 2>/dev/null || true
  fi
  
  log "Completed processing $repo_name"
}

# Main execution
main() {
  # Parse command-line arguments
  parse_arguments "$@"
  
  # Set default model based on backend
  set_default_model
  
  # Initialize directories and log file
  init_directories
  
  log "=========================================="
  log "SnowyOwl Automation Workflow Started"
  log "=========================================="
  log "Root directory: $ROOT"
  log "Base branch: $BASE_BRANCH"
  log "AI Backend: $AI_BACKEND"
  log "AI Model: $AI_MODEL"
  log "Create PR: $CREATE_PR"
  log "Dry run: $DRY_RUN"
  log "Log directory: $LOG_DIR"
  log "Worktrees directory: $WORKTREES_DIR"
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
