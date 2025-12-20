#!/usr/bin/env bash
#
# SnowyOwl - Enhanced Copilot CLI Integration Wrapper
#
# This script is designed to be called BY GitHub Copilot CLI with appropriate
# tool permissions. It provides a structured workflow for task automation.
#
# Usage (when called by Copilot CLI):
#   copilot -p "$(cat prompts/plan.txt)" --allow-tool 'write' --allow-tool 'shell(git)' --allow-tool 'shell(gh)'
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_PATH="${1:-.}"

# Load configuration if exists
if [[ -f "$SCRIPT_DIR/config.env" ]]; then
    source "$SCRIPT_DIR/config.env"
fi

cd "$REPO_PATH"

# Helper to generate Copilot prompts
generate_plan_prompt() {
    local task="$1"
    cat <<EOF
You are acting as an autonomous code implementation agent.

Repository: $(basename "$REPO_PATH")
Branch: $(git rev-parse --abbrev-ref HEAD)

Task to plan:
$task

Please create a detailed implementation plan that includes:
1. Files that need to be created or modified
2. Key functions or components to implement
3. Dependencies or libraries needed
4. Testing approach
5. Any potential edge cases

Return the plan in a structured format.
EOF
}

generate_implementation_prompt() {
    local task="$1"
    cat <<EOF
You are acting as an autonomous code implementation agent.

Repository: $(basename "$REPO_PATH")
Branch: $(git rev-parse --abbrev-ref HEAD)

Task to implement:
$task

Please implement this task by:
1. Creating or modifying necessary files
2. Following existing code patterns in the repository
3. Adding appropriate error handling
4. Including inline comments where needed
5. Ensuring code quality and best practices

Make the minimal necessary changes to accomplish the task.
After implementation, stage the changes with git add.
EOF
}

# Export functions for use by Copilot
export -f generate_plan_prompt
export -f generate_implementation_prompt

# When run standalone, show usage
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "SnowyOwl Copilot Integration Wrapper"
    echo
    echo "This script provides helper functions for Copilot CLI integration."
    echo
    echo "Example usage with Copilot CLI:"
    echo
    echo "  # Generate and execute a plan"
    echo "  copilot -p \"\$(./copilot_integration.sh generate-plan 'Add user auth')\" \\"
    echo "    --allow-tool 'write' \\"
    echo "    --allow-tool 'shell(git)' \\"
    echo "    --allow-tool 'shell(gh)'"
    echo
    echo "Available commands:"
    echo "  generate-plan <task>         - Generate planning prompt"
    echo "  generate-implement <task>    - Generate implementation prompt"
    echo
    
    # Handle commands
    case "${1:-}" in
        generate-plan)
            generate_plan_prompt "${2:-}"
            ;;
        generate-implement)
            generate_implementation_prompt "${2:-}"
            ;;
        *)
            exit 0
            ;;
    esac
fi
