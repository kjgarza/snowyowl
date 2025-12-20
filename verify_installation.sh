#!/usr/bin/env bash
#
# SnowyOwl Installation Verification Script
#
# This script verifies that SnowyOwl is properly installed and configured
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "🦉 SnowyOwl Installation Verification"
echo "======================================"
echo

# Track overall status
ALL_CHECKS_PASSED=true

check_pass() {
    echo -e "${GREEN}✅ $1${NC}"
}

check_fail() {
    echo -e "${RED}❌ $1${NC}"
    ALL_CHECKS_PASSED=false
}

check_warn() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# 1. Check files exist
echo "Checking required files..."
required_files=(
    "run_copilot_automation.sh"
    "setup.sh"
    "copilot_integration.sh"
    "README.md"
    "QUICKSTART.md"
    "PROJECT_OVERVIEW.md"
    "CHANGELOG.md"
    "TASKS.md"
    "config.env"
    ".gitignore"
    "com.snowyowl.automation.plist"
)

for file in "${required_files[@]}"; do
    if [[ -f "$SCRIPT_DIR/$file" ]]; then
        check_pass "$file exists"
    else
        check_fail "$file is missing"
    fi
done
echo

# 2. Check directories
echo "Checking directories..."
required_dirs=(
    "logs"
    "templates"
    "examples"
)

for dir in "${required_dirs[@]}"; do
    if [[ -d "$SCRIPT_DIR/$dir" ]]; then
        check_pass "$dir/ directory exists"
    else
        check_fail "$dir/ directory is missing"
    fi
done
echo

# 3. Check script permissions
echo "Checking script permissions..."
executable_scripts=(
    "run_copilot_automation.sh"
    "setup.sh"
    "copilot_integration.sh"
)

for script in "${executable_scripts[@]}"; do
    if [[ -x "$SCRIPT_DIR/$script" ]]; then
        check_pass "$script is executable"
    else
        check_fail "$script is not executable"
    fi
done
echo

# 4. Check system prerequisites
echo "Checking system prerequisites..."

if command -v git &> /dev/null; then
    check_pass "git is installed ($(git --version))"
else
    check_fail "git is not installed"
fi

if command -v gh &> /dev/null; then
    check_pass "GitHub CLI is installed ($(gh --version | head -1))"
    
    if gh auth status &> /dev/null; then
        check_pass "GitHub CLI is authenticated"
    else
        check_warn "GitHub CLI is not authenticated (run: gh auth login)"
    fi
else
    check_fail "GitHub CLI (gh) is not installed"
fi

if command -v llm &> /dev/null; then
    check_pass "LLM CLI is installed ($(llm --version))"
else
    check_fail "LLM CLI is not installed (install with: pip install llm)"
fi

if command -v copilot &> /dev/null; then
    check_pass "GitHub Copilot CLI is installed"
else
    check_warn "GitHub Copilot CLI not found (optional, install with: gh extension install github/gh-copilot)"
fi
echo

# 5. Check template files
echo "Checking template and example files..."

if [[ -f "$SCRIPT_DIR/templates/TASKS.template.md" ]]; then
    check_pass "Task template exists"
else
    check_fail "Task template is missing"
fi

example_count=$(find "$SCRIPT_DIR/examples" -name "*.md" 2>/dev/null | wc -l)
if [[ $example_count -gt 0 ]]; then
    check_pass "Found $example_count example file(s)"
else
    check_warn "No example files found"
fi
echo

# 6. Test script syntax
echo "Checking script syntax..."

for script in "${executable_scripts[@]}"; do
    if bash -n "$SCRIPT_DIR/$script" 2>/dev/null; then
        check_pass "$script has valid bash syntax"
    else
        check_fail "$script has syntax errors"
    fi
done
echo

# 7. Check launchd configuration
echo "Checking launchd configuration..."

if [[ -f "$SCRIPT_DIR/com.snowyowl.automation.plist" ]]; then
    check_pass "launchd plist file exists"
    
    if plutil -lint "$SCRIPT_DIR/com.snowyowl.automation.plist" &> /dev/null; then
        check_pass "launchd plist is valid XML"
    else
        check_fail "launchd plist has invalid XML"
    fi
    
    if [[ -f "$HOME/Library/LaunchAgents/com.snowyowl.automation.plist" ]]; then
        check_pass "launchd agent is installed"
    else
        check_warn "launchd agent not installed (run setup.sh to install)"
    fi
else
    check_fail "launchd plist file is missing"
fi
echo

# 8. Check documentation
echo "Checking documentation..."

docs=(
    "README.md"
    "QUICKSTART.md"
    "PROJECT_OVERVIEW.md"
)

for doc in "${docs[@]}"; do
    if [[ -s "$SCRIPT_DIR/$doc" ]]; then
        lines=$(wc -l < "$SCRIPT_DIR/$doc")
        check_pass "$doc exists ($lines lines)"
    else
        check_fail "$doc is missing or empty"
    fi
done
echo

# 9. Test dry-run execution
echo "Testing dry-run execution..."

if "$SCRIPT_DIR/run_copilot_automation.sh" --help &> /dev/null; then
    check_pass "Main script --help works"
else
    check_fail "Main script --help failed"
fi
echo

# Final summary
echo "======================================"
if [[ "$ALL_CHECKS_PASSED" == true ]]; then
    echo -e "${GREEN}✅ All checks passed!${NC}"
    echo
    echo "SnowyOwl is properly installed and ready to use."
    echo
    echo "Next steps:"
    echo "1. Authenticate GitHub CLI: gh auth login"
    echo "2. Create TASKS.md files in your repositories"
    echo "3. Run setup.sh for installation options"
    echo "4. Try a dry-run: ./run_copilot_automation.sh --dry-run"
    exit 0
else
    echo -e "${RED}❌ Some checks failed${NC}"
    echo
    echo "Please fix the issues above before using SnowyOwl."
    echo "Run ./setup.sh for guided setup."
    exit 1
fi
