#!/usr/bin/env bash
#
# SnowyOwl Task Processing Module
#
# Handles task parsing, specification loading, implementation, and PR creation.
# This module should be sourced by the main script.
#

# Extract markdown link from task text
# Returns: "title|path" or "title|" if no link
extract_task_link() {
  local task="$1"
  
  # Detect markdown link pattern: [title](path.md)
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
  
  # Check if the selected AI backend is available
  local backend_status
  check_ai_backend
  backend_status=$?
  
  if [[ $backend_status -eq 1 ]]; then
    # Hard failure - backend explicitly required but not available
    exit 1
  fi
  # backend_status=2 means soft failure (copilot not available, will use markers)
  # backend_status=0 means success
  
  log_success "Prerequisites check passed"
}

# Parse tasks from TASKS.md using LLM CLI for intelligent parsing
parse_tasks() {
  local tasks_file="$1"
  
  # Use LLM CLI to intelligently parse tasks from the TASKS.md file
  local prompt="You are a task parser for a code automation system.

Parse the following TASKS.md file and extract all actionable tasks.

Rules:
1. Extract tasks marked with - [ ] (unchecked checkboxes)
2. Include both top-level tasks and subtasks
3. Rephrase each task as a concise, actionable imperative (e.g., 'Add user validation' not 'User validation needs to be added')
4. Keep rephrased tasks brief - do not add context or details not present in the original
5. PRESERVE markdown links exactly as written: [text](file.md)
6. Preserve the hierarchy by indenting subtasks with 2 spaces
7. Skip completed tasks (marked with - [x])
8. Return ONLY the task list, one task per line
9. Do not add any explanations or additional text

TASKS.md content:
$(cat "$tasks_file")

Output format (one task per line):
Add user validation
[Implement OAuth](./specs/oauth.md)
  Configure token refresh
Fix memory leak in cache"

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
    echo "$parsed_tasks" | grep -v '^[[:space:]]*$' | sed -E 's/^([[:space:]]*)-[[:space:]]\[[[:space:]xX]\][[:space:]]*/\1/'
  fi
}

# Generate a short branch slug from task title using LLM
# Returns: lowercase-hyphenated-slug (2-4 words)
generate_branch_slug() {
  local task_title="$1"
  
  local prompt="Generate a short git branch slug for this task:

Task: $task_title

Rules:
1. Output ONLY the slug, nothing else
2. Use 2-4 lowercase words separated by hyphens
3. No special characters, only a-z and hyphens
4. Keep it descriptive but brief
5. Use conventional prefixes: feat/, fix/, refactor/, docs/, chore/

Examples:
- 'Add user authentication' -> feat/add-user-auth
- 'Fix memory leak in cache' -> fix/cache-memory-leak
- 'Update README documentation' -> docs/update-readme

Output only the slug:"

  local slug
  slug=$(echo "$prompt" | llm -m gpt-4o-mini 2>/dev/null | tr -d '[:space:]' || echo "")
  
  # Validate and fallback if LLM fails
  if [[ -z "$slug" || ! "$slug" =~ ^[a-z]+/[a-z-]+$ ]]; then
    # Fallback to simple sanitization
    local sanitized=$(echo "$task_title" | sed 's/[^a-zA-Z0-9]/-/g' | tr '[:upper:]' '[:lower:]' | cut -c 1-30)
    sanitized=$(echo "$sanitized" | sed 's/^-*//;s/-*$//' | sed 's/--*/-/g')
    if [[ -z "$sanitized" ]]; then
      sanitized="task"
    fi
    slug="feat/$sanitized"
  fi
  
  echo "$slug"
}

# Generate a conventional commit message from task title using LLM
# Returns: conventional commit format (e.g., "feat: add user validation")
generate_commit_message() {
  local task_title="$1"
  
  local prompt="Generate a conventional commit message for this task:

Task: $task_title

Rules:
1. Output ONLY the commit message, nothing else
2. Use conventional commit format: type: description
3. Types: feat, fix, refactor, docs, chore, style, test, perf
4. Keep description lowercase, concise (under 50 chars if possible)
5. No period at the end

Examples:
- 'Add user authentication' -> feat: add user authentication
- 'Fix memory leak in cache' -> fix: resolve memory leak in cache
- 'Update README' -> docs: update readme

Output only the commit message:"

  local message
  message=$(echo "$prompt" | llm -m gpt-4o-mini 2>/dev/null | head -1 || echo "")
  
  # Validate and fallback if LLM fails
  if [[ -z "$message" || ! "$message" =~ ^[a-z]+:[[:space:]] ]]; then
    # Fallback to simple format
    local clean_title=$(echo "$task_title" | tr '[:upper:]' '[:lower:]')
    message="feat: $clean_title"
  fi
  
  echo "$message"
}

# Implement a single task
implement_task() {
  local repo_path="$1"
  local worktree_path="$2"
  local task_title="$3"
  local task_link="$4"
  local repo_log="$5"
  local dry_run="$6"
  
  log "Task: $task_title"
  echo "---" >> "$repo_log"
  echo "Task: $task_title" >> "$repo_log"
  if [[ -n "$task_link" ]]; then
    echo "Specification: $task_link" >> "$repo_log"
  fi
  echo "Worktree: $worktree_path" >> "$repo_log"
  echo "---" >> "$repo_log"
  
  # Change to worktree directory for all operations
  cd "$worktree_path"
  
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
  
  # Check if the selected AI backend is available
  local backend_available=false
  case "$AI_BACKEND" in
    claude)
      command -v claude &> /dev/null && backend_available=true
      ;;
    copilot|*)
      command -v copilot &> /dev/null && backend_available=true
      ;;
  esac
  
  if [[ "$backend_available" == true ]]; then
    log "Using $AI_BACKEND backend to implement task..."
    
    # Build enhanced prompt with specification (use worktree path)
    local full_prompt=$(build_task_prompt "$worktree_path" "$task_title" "$task_spec")

    # Call the AI backend dispatcher
    if run_ai_backend "$full_prompt" "$repo_log"; then
      log "$AI_BACKEND implementation completed for: $task_title"
    else
      local exit_code=$?
      log_error "$AI_BACKEND implementation failed with exit code $exit_code"
      log_error "Check log: $repo_log"
      return 1
    fi
  else
    log "$AI_BACKEND CLI not available, creating task marker for manual implementation"
    # Create a marker file to show the task was processed
    local task_marker=".pending_tasks/$(echo "$task_title" | sed 's/[^a-zA-Z0-9]/_/g').txt"
    mkdir -p .pending_tasks
    echo "Task: $task_title" > "$task_marker"
    if [[ -n "$task_link" ]]; then
      echo "Specification: $task_link" >> "$task_marker"
    fi
    echo "Timestamp: $(date)" >> "$task_marker"
    echo "Status: Pending implementation" >> "$task_marker"
    echo "" >> "$task_marker"
    echo "To implement:" >> "$task_marker"
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
  
  # Stage and commit changes for this task (in worktree)
  if [[ "$dry_run" == false ]]; then
    git add .
    if git diff --cached --quiet; then
      log "No changes to commit for task: $task_title"
      return 0
    else
      # Generate conventional commit message
      local commit_msg
      commit_msg=$(generate_commit_message "$task_title")
      if ! git commit -m "$commit_msg" 2>&1 | tee -a "$repo_log"; then
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
  local repo_path="$1"
  local repo_name="$2"
  local worktree_path="$3"
  local feature_branch="$4"
  local repo_base_branch="$5"
  local repo_log="$6"
  local dry_run="$7"
  local create_pr="$8"
  shift 8
  local tasks=("${@}")
  
  # Change to worktree to push
  cd "$worktree_path"
  
  # Check if repository has GitHub remote
  if ! has_github_remote "$repo_path"; then
    log "Repository has no GitHub remote - skipping push and PR creation"
    log "Changes committed to branch: $feature_branch"
    if [[ "$dry_run" == false ]]; then
      log_success "All changes committed to local branch: $feature_branch"
      # Clean up worktree if enabled
      if [[ "$CLEANUP_WORKTREES" == true ]]; then
        remove_worktree "$repo_path" "$worktree_path" "$repo_log"
      else
        log "Worktree preserved at: $worktree_path"
      fi
    else
      log "[DRY RUN] Would commit to local branch: $feature_branch (no GitHub remote)"
    fi
    return 0
  fi
  
  # Check if PR creation is disabled
  if [[ "$create_pr" == false ]]; then
    log "PR creation disabled - changes committed to local branch: $feature_branch"
    if [[ "$dry_run" == false ]]; then
      log_success "All changes committed to local branch: $feature_branch (use --create-pr to push and create PR)"
      # Clean up worktree if enabled
      if [[ "$CLEANUP_WORKTREES" == true ]]; then
        remove_worktree "$repo_path" "$worktree_path" "$repo_log"
      else
        log "Worktree preserved at: $worktree_path"
      fi
    else
      log "[DRY RUN] Would commit to local branch: $feature_branch (PR creation disabled)"
    fi
    return 0
  fi
  
  if [[ "$dry_run" == false ]]; then
    log "Pushing branch to GitHub from worktree..."
    if ! git push -u origin "$feature_branch" 2>&1 | tee -a "$repo_log"; then
      log_error "Failed to push branch for $repo_name"
      return 1
    fi
    log_success "Pushed branch: $feature_branch"
    
    # Wait 30 seconds before creating PR
    log "Waiting 30 seconds before creating pull request..."
    sleep 30
    
    # Create PR (must be in repo_path for gh pr create)
    cd "$repo_path"
    log "Creating pull request..."
    
    # Use first task as PR title, or branch name if no tasks
    local pr_title
    if [[ ${#tasks[@]} -gt 0 ]]; then
      pr_title="${tasks[0]}"
    else
      pr_title="$feature_branch"
    fi
    
    # Build task list for PR body
    local task_list=""
    for task in "${tasks[@]}"; do
      task_list="${task_list}- ${task}
"
    done
    
    local pr_body="## Summary

This PR implements the following changes:

${task_list}
## Review Checklist

- [ ] Code follows project conventions
- [ ] Tests pass
- [ ] Documentation updated if needed"

    if ! gh pr create \
      --base "$repo_base_branch" \
      --head "$feature_branch" \
      --title "$pr_title" \
      --body "$pr_body" 2>&1 | tee -a "$repo_log"; then
      log_error "Failed to create pull request for $repo_name"
      return 1
    fi
    log_success "Created pull request for $repo_name (base: $repo_base_branch)"
    
    # Clean up worktree if enabled
    if [[ "$CLEANUP_WORKTREES" == true ]]; then
      log "Cleaning up worktree..."
      remove_worktree "$repo_path" "$worktree_path" "$repo_log"
    else
      log "Worktree preserved at: $worktree_path"
    fi
  else
    log "[DRY RUN] Would push branch: $feature_branch"
    log "[DRY RUN] Would create PR with ${#tasks[@]} task(s)"
  fi
}

