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
LOG_DIR="${HOME}/aves/labs/snowyowl/logs"
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

# Extract markdown link from task text
# Returns: "title|path" or "title|" if no link
extract_task_link() {
  local task="$1"
  
  # Detect markdown link pattern: [title](path.md)
  # Using grep for bash 3.x compatibility
  if echo "$task" | grep -q '\[.*\](.*\.md)'; then
    local title=$(echo "$task" | sed -n 's/.*\[\([^]]*\)\](.*\.md).*/\1/p')
    local path=$(echo "$task" | sed -n 's/.*\[.*\](\([^)]*\.md\)).*/\1/p')
    if [[ -n "$title" && -n "$path" ]]; then
      echo "$title|$path"
      return
    fi
  fi
  # No link found, return task as-is
  echo "$task|"
}

# Load task specification from linked markdown file
# Returns: file content or empty string if file not found
load_task_specification() {
  local repo_path="$1"
  local file_path="$2"
  
  # Resolve relative paths
  local full_path
  if [[ "$file_path" = /* ]]; then
    # Absolute path from repo root
    full_path="${repo_path}${file_path}"
  elif [[ "$file_path" = ./* ]]; then
    # Relative path with ./
    full_path="${repo_path}/${file_path#./}"
  else
    # Relative path without ./
    full_path="${repo_path}/${file_path}"
  fi
  
  # Clean up path (remove double slashes)
  full_path=$(echo "$full_path" | sed 's#//#/#g')
  
  # Check if file exists and is readable
  if [[ -f "$full_path" && -r "$full_path" ]]; then
    # Check file size (limit to 100KB)
    local size=$(wc -c < "$full_path" 2>/dev/null || echo "0")
    if [[ $size -gt 102400 ]]; then
      log "Warning: Specification file is large (${size} bytes), truncating to 100KB: $file_path"
      head -c 102400 "$full_path"
    else
      cat "$full_path"
    fi
  else
    log "Warning: Task specification file not found or not readable: $file_path"
    echo ""
  fi
}

# Build enhanced prompt for Copilot with optional specification
build_task_prompt() {
  local repo_path="$1"
  local task_title="$2"
  local task_spec="$3"  # Optional specification content
  
  if [[ -n "$task_spec" ]]; then
    # Enhanced prompt with full specification
    cat << PROMPT_EOF
Implement the following task in this repository:

Repository: $(basename "$repo_path")
Current branch: $(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
Working directory: $repo_path

Task: $task_title

Detailed Specification:
$task_spec

Instructions:
1. Read and understand the full specification above
2. Implement ALL requirements listed in the specification
3. Analyze existing code patterns and follow them
4. Add appropriate error handling and logging
5. Include helpful comments where needed
6. Ensure the implementation is complete and production-ready
7. Make focused, minimal changes to accomplish this task

Please implement this task now.
PROMPT_EOF
  else
    # Simple prompt without specification
    cat << PROMPT_EOF
Implement the following task in this repository:

Repository: $(basename "$repo_path")
Current branch: $(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
Working directory: $repo_path

Task: $task_title

Instructions:
1. Analyze the existing code structure and patterns
2. Implement the changes needed for this task
3. Follow existing code style and conventions
4. Add appropriate error handling
5. Include helpful comments where needed
6. Make minimal, focused changes

Please implement this task now.
PROMPT_EOF
  fi
}

# Check if repository has a GitHub remote
has_github_remote() {
  local repo_path="$1"
  cd "$repo_path"
  
  # Get all remote URLs
  local remotes=$(git remote -v 2>/dev/null || echo "")
  
  # Check if any remote URL contains github.com
  if echo "$remotes" | grep -q 'github.com'; then
    return 0  # Has GitHub remote
  else
    return 1  # No GitHub remote
  fi
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
4. PRESERVE markdown links exactly as written: [text](file.md)
5. Preserve the hierarchy by indenting subtasks with 2 spaces
6. Skip completed tasks (marked with - [x])
7. Return ONLY the task list, one task per line
8. Do not add any explanations or additional text

TASKS.md content:
$(cat "$tasks_file")

Output format (one task per line):
Task description
[Task with link](./specs/file.md)
  Subtask description
Another top-level task"

  # Call LLM CLI to parse tasks
  local parsed_tasks
  parsed_tasks=$(echo "$prompt" | llm -m gpt-4o-mini 2>/dev/null || echo "")
  
  # Fallback to simple parsing if LLM fails
  if [[ -z "$parsed_tasks" ]]; then
    log "LLM parsing failed, falling back to simple regex parsing"
    local tasks=()
    while IFS= read -r line; do
      if [[ "$line" =~ ^([[:space:]]*)-[[:space:]]\[[[:space:]]\] ]]; then
        local indent="${BASH_REMATCH[1]}"
        local content=$(echo "$line" | sed -E 's/^[[:space:]]*-[[:space:]]\[[[:space:]]\][[:space:]]*//')
        if [[ -n "$content" ]]; then
          tasks+=("${indent}${content}")
        fi
      fi
    done < "$tasks_file"
    printf '%s\n' "${tasks[@]}"
  else
    # Clean up and return LLM-parsed tasks
    # Remove checkbox syntax but preserve indentation
    echo "$parsed_tasks" | grep -v '^[[:space:]]*$' | sed -E 's/^([[:space:]]*)-[[:space:]]\[[[:space:]xX]\][[:space:]]*/\1/'
  fi
}

# Implement a single task
implement_task() {
  local repo_path="$1"
  local task_title="$2"
  local task_link="$3"
  local repo_log="$4"
  local dry_run="$5"
  
  log "Task: $task_title"
  echo "---" >> "$repo_log"
  echo "Task: $task_title" >> "$repo_log"
  if [[ -n "$task_link" ]]; then
    echo "Specification: $task_link" >> "$repo_log"
  fi
  echo "---" >> "$repo_log"
  
  # Load specification if link exists
  local task_spec=""
  if [[ -n "$task_link" ]]; then
    log "Loading specification from: $task_link"
    task_spec=$(load_task_specification "$repo_path" "$task_link")
    if [[ -n "$task_spec" ]]; then
      local spec_lines=$(echo "$task_spec" | wc -l)
      local spec_chars=$(echo "$task_spec" | wc -c)
      log "Loaded specification: $spec_lines lines, $spec_chars bytes"
      echo "Specification loaded: $spec_lines lines" >> "$repo_log"
    else
      log "Using task title only (specification not available)"
    fi
  fi
  
  # Check if copilot CLI is available for actual implementation
  if command -v copilot &> /dev/null; then
    log "Using GitHub Copilot CLI to implement task..."
    
    # Build enhanced prompt with specification
    local full_prompt=$(build_task_prompt "$repo_path" "$task_title" "$task_spec")
    
    # Create a temporary prompt file
    local prompt_file=$(mktemp)
    echo "$full_prompt" > "$prompt_file"

    # Call Copilot CLI with proper flags
    # Use --allow-all-tools for non-interactive mode
    if copilot --allow-all-tools --deny-tool 'shell(rm)' < "$prompt_file" >> "$repo_log" 2>&1; then
      rm -f "$prompt_file"
      log "Copilot implementation completed for: $task_title"
    else
      local exit_code=$?
      rm -f "$prompt_file"
      log_error "Copilot implementation failed with exit code $exit_code"
      log_error "Check log: $repo_log"
      return 1
    fi
  else
    log "Copilot CLI not available, creating task marker for manual implementation"
    # Create a marker file to show the task was processed
    local task_marker=".snowyowl_tasks/$(echo "$task_title" | sed 's/[^a-zA-Z0-9]/_/g').txt"
    mkdir -p .snowyowl_tasks
    echo "Task: $task_title" > "$task_marker"
    if [[ -n "$task_link" ]]; then
      echo "Specification: $task_link" >> "$task_marker"
    fi
    echo "Timestamp: $(date)" >> "$task_marker"
    echo "Status: Awaiting Copilot CLI implementation" >> "$task_marker"
    echo "" >> "$task_marker"
    echo "To implement manually:" >> "$task_marker"
    echo "1. Review the task description above" >> "$task_marker"
    if [[ -n "$task_link" ]]; then
      echo "2. Read the detailed specification in: $task_link" >> "$task_marker"
      echo "3. Implement according to the specification" >> "$task_marker"
    else
      echo "2. Make necessary code changes" >> "$task_marker"
    fi
    echo "$(( [[ -n "$task_link" ]] && echo "4" || echo "3" )). Test your changes" >> "$task_marker"
    echo "$(( [[ -n "$task_link" ]] && echo "5" || echo "4" )). Delete this marker file" >> "$task_marker"
  fi
  
  # Stage and commit changes for this task
  if [[ "$dry_run" == false ]]; then
    git add .
    if git diff --cached --quiet; then
      log "No changes to commit for task: $task_title"
      return 0
    else
      if ! git commit -m "AI: $task_title" 2>&1 | tee -a "$repo_log"; then
        log_error "Failed to commit changes"
        return 1
      fi
      log_success "Committed changes for: $task_title"
      return 0
    fi
  else
    log "[DRY RUN] Would commit: $task_title"
    return 0
  fi
}

# Create PR for a branch or just commit if no GitHub remote
create_pr_for_branch() {
  local repo_name="$1"
  local feature_branch="$2"
  local repo_base_branch="$3"
  local repo_log="$4"
  local dry_run="$5"
  shift 5
  local tasks=("${@}")
  
  # Check if repository has GitHub remote
  if ! has_github_remote "$(pwd)"; then
    log "Repository has no GitHub remote - skipping push and PR creation"
    log "Changes committed to branch: $feature_branch"
    if [[ "$dry_run" == false ]]; then
      log_success "All changes committed to local branch: $feature_branch"
    else
      log "[DRY RUN] Would commit to local branch: $feature_branch (no GitHub remote)"
    fi
    return 0
  fi
  
  if [[ "$dry_run" == false ]]; then
    log "Pushing branch to GitHub..."
    if ! git push -u origin "$feature_branch" 2>&1 | tee -a "$repo_log"; then
      log_error "Failed to push branch for $repo_name"
      return 1
    fi
    log_success "Pushed branch: $feature_branch"
    
    # Wait 30 seconds before creating PR
    log "Waiting 30 seconds before creating pull request..."
    sleep 30
    
    # Create PR
    log "Creating pull request..."
    local pr_title="[SnowyOwl] Automated task implementation - $feature_branch"
    
    # Build task list for PR body
    local task_list=""
    for task in "${tasks[@]}"; do
      task_list="${task_list}- ${task}
"
    done
    
    local pr_body="🦉 **SnowyOwl Automated Workflow**

This PR contains automated code changes.

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
      return 1
    fi
    log_success "Created pull request for $repo_name (base: $repo_base_branch)"
  else
    log "[DRY RUN] Would push branch: $feature_branch"
    log "[DRY RUN] Would create PR with ${#tasks[@]} task(s)"
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
    return
  fi
  
  log "Found $task_count task(s) in $repo_name"
  
  local current_branch=""
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
    
    # If top-level task, switch branch
    if [[ "$is_subtask" == false ]]; then
      # Finish previous branch if exists
      if [[ -n "$current_branch" ]]; then
        create_pr_for_branch "$repo_name" "$current_branch" "$repo_base_branch" "$repo_log" "$DRY_RUN" "${current_tasks[@]}"
        # Switch back to base
        git checkout "$repo_base_branch" 2>/dev/null || true
      fi
      
      # Start new branch
      # Sanitize task title for branch name
      local link_info=$(extract_task_link "$clean_task")
      local task_title=$(echo "$link_info" | cut -d'|' -f1)
      local sanitized_title=$(echo "$task_title" | sed 's/[^a-zA-Z0-9]/-/g' | tr '[:upper:]' '[:lower:]' | cut -c 1-30)
      # Remove leading/trailing dashes
      sanitized_title=$(echo "$sanitized_title" | sed 's/^-*//;s/-*$//')
      if [[ -z "$sanitized_title" ]]; then
        sanitized_title="task"
      fi
      
      current_branch="snowyowl-ai-${sanitized_title}-$(date +%s)"
      
      log "Creating feature branch: $current_branch"
      if ! git checkout -b "$current_branch" "$repo_base_branch" 2>&1 | tee -a "$repo_log"; then
        log_error "Failed to create feature branch in $repo_name"
        current_branch=""
        continue
      fi
      current_tasks=()
    fi
    
    # Implement task (only if we have a valid branch)
    if [[ -n "$current_branch" ]]; then
      local link_info=$(extract_task_link "$clean_task")
      local task_title=$(echo "$link_info" | cut -d'|' -f1)
      local task_link=$(echo "$link_info" | cut -d'|' -f2)
      
      if implement_task "$repo_path" "$task_title" "$task_link" "$repo_log" "$DRY_RUN"; then
        current_tasks+=("$task_title")
      else
        log_error "Failed to implement task: $task_title"
      fi
    else
       log_error "Skipping task because branch creation failed: $clean_task"
    fi
  done
  
  # Finish last branch
  if [[ -n "$current_branch" ]]; then
    create_pr_for_branch "$repo_name" "$current_branch" "$repo_base_branch" "$repo_log" "$DRY_RUN" "${current_tasks[@]}"
    git checkout "$repo_base_branch" 2>/dev/null || true
  fi
  
  # Restore original branch if it wasn't the base branch
  if [[ -n "$original_branch" && "$original_branch" != "$repo_base_branch" ]]; then
    git checkout "$original_branch" 2>/dev/null || true
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
