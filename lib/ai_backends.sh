#!/usr/bin/env bash
#
# SnowyOwl AI Backends Module
#
# Handles AI coding assistant integrations (GitHub Copilot, Claude Code).
# This module should be sourced by the main script.
#

# Build enhanced prompt for AI with optional specification
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
2. Plan the necessary code changes
3. Implement ALL requirements listed in the specification
4. Analyze existing code patterns and follow them
5. Add appropriate error handling and logging
6. Include helpful comments where needed
7. Make focused changes to accomplish this task

Principles to follow:
- Clarity over flexibility
- Replaceability over extensibility
- Refactoring over future-proofing
- Working code over elegant abstractions
- Apply KISS and YAGNI throughout.

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
6. Make focused changes

Please implement this task now.
PROMPT_EOF
  fi
}

# Run GitHub Copilot CLI backend
run_copilot_backend() {
  local prompt="$1"
  local repo_log="$2"
  
  # Create a temporary prompt file
  local prompt_file=$(mktemp)
  echo "$prompt" > "$prompt_file"
  
  # Call Copilot CLI with proper flags
  local exit_code=0
  if copilot --allow-all-tools --deny-tool "$COPILOT_DENY_TOOLS" --model "$AI_MODEL" < "$prompt_file" >> "$repo_log" 2>&1; then
    rm -f "$prompt_file"
    return 0
  else
    exit_code=$?
    rm -f "$prompt_file"
    return $exit_code
  fi
}

# Run Claude Code CLI backend
run_claude_backend() {
  local prompt="$1"
  local repo_log="$2"
  
  # Call Claude Code CLI with headless mode flags
  if claude -p "$prompt" \
      --allowedTools "$CLAUDE_ALLOWED_TOOLS" \
      --permission-mode "$CLAUDE_PERMISSION_MODE" \
      --model "$AI_MODEL" >> "$repo_log" 2>&1; then
    return 0
  else
    return $?
  fi
}

# AI Backend dispatcher - routes to appropriate backend
run_ai_backend() {
  local prompt="$1"
  local repo_log="$2"
  
  case "$AI_BACKEND" in
    claude)
      run_claude_backend "$prompt" "$repo_log"
      ;;
    copilot|*)
      run_copilot_backend "$prompt" "$repo_log"
      ;;
  esac
}

# Check if the selected AI backend is available
check_ai_backend() {
  case "$AI_BACKEND" in
    claude)
      if ! command -v claude &> /dev/null; then
        log_error "Claude Code CLI is not installed"
        log_error "Install with: curl -fsSL https://claude.ai/install.sh | bash"
        return 1
      fi
      log "AI Backend: Claude Code CLI (model: $AI_MODEL)"
      ;;
    copilot)
      if ! command -v copilot &> /dev/null; then
        log "Copilot CLI not available - will create task markers for manual implementation"
        return 2  # Return 2 to indicate "soft" failure (fallback mode)
      fi
      log "AI Backend: GitHub Copilot CLI (model: $AI_MODEL)"
      ;;
    *)
      log_error "Unknown AI backend: $AI_BACKEND"
      log_error "Supported backends: copilot, claude"
      return 1
      ;;
  esac
  return 0
}

