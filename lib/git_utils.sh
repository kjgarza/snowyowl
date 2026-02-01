#!/usr/bin/env bash
#
# SnowyOwl Git Utilities Module
#
# Handles all git operations including worktree management and remote checking.
# This module should be sourced by the main script.
#

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

# Create a worktree for a feature branch
# Returns: worktree_path
create_worktree() {
  local repo_path="$1"
  local repo_name="$2"
  local branch_name="$3"
  local base_branch="$4"
  local repo_log="$5"
  
  cd "$repo_path"
  
  # Create worktree directory name: repo_name-branch_name
  local worktree_name="${repo_name}-${branch_name}"
  local worktree_path="${WORKTREES_DIR}/${worktree_name}"
  
  # Remove existing worktree if it exists
  if [[ -d "$worktree_path" ]]; then
    log "Removing existing worktree: $worktree_name" >&2
    remove_worktree "$repo_path" "$worktree_path" "$repo_log"
  fi
  
  # Create new worktree
  log "Creating worktree: $worktree_name" >&2
  if ! git worktree add -b "$branch_name" "$worktree_path" "$base_branch" >> "$repo_log" 2>&1; then
    log_error "Failed to create worktree: $worktree_name" >&2
    return 1
  fi
  
  log "Worktree created at: $worktree_path" >&2
  echo "$worktree_path"
}

# Remove a worktree and its branch
remove_worktree() {
  local repo_path="$1"
  local worktree_path="$2"
  local repo_log="$3"
  
  cd "$repo_path"
  
  if [[ -d "$worktree_path" ]]; then
    # Get the branch name from the worktree
    local branch_name=$(cd "$worktree_path" && git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
    
    # Remove the worktree
    if git worktree remove "$worktree_path" --force >> "$repo_log" 2>&1; then
      log "Removed worktree: $(basename "$worktree_path")" >&2
    else
      log "Warning: Could not remove worktree: $worktree_path" >&2
      # Try manual cleanup
      rm -rf "$worktree_path" 2>/dev/null || true
      git worktree prune >> "$repo_log" 2>&1 || true
    fi
    
    # Optionally delete the branch (if it wasn't pushed)
    if [[ -n "$branch_name" && "$branch_name" != "HEAD" ]]; then
      if ! git ls-remote --exit-code --heads origin "$branch_name" &>/dev/null; then
        # Branch not pushed, safe to delete locally
        git branch -D "$branch_name" >> "$repo_log" 2>&1 || true
      fi
    fi
  fi
}

# Clean up all worktrees for a repository
cleanup_repo_worktrees() {
  local repo_path="$1"
  local repo_name="$2"
  local repo_log="$3"
  
  cd "$repo_path"
  
  # Find all worktrees for this repo
  local pattern="${repo_name}-*"
  for worktree_path in "$WORKTREES_DIR"/$pattern; do
    if [[ -d "$worktree_path" ]]; then
      log "Cleaning up worktree: $(basename "$worktree_path")" >&2
      remove_worktree "$repo_path" "$worktree_path" "$repo_log"
    fi
  done
  
  # Prune any stale worktree references
  git worktree prune >> "$repo_log" 2>&1 || true
}

