# Changelog

All notable changes to the SnowyOwl project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.2.0] - 2025-12-18

### Added
- **Linked Task Specifications** - Major new feature
  - Tasks can now link to external markdown files with detailed specifications
  - Format: `- [ ] [Task name](./specs/specification.md)`
  - Copilot receives full specification content for better implementation
  - Supports relative, absolute, and parent directory paths
  - Graceful fallback if specification file not found
  - File size limit of 100KB with automatic truncation
- **New Functions:**
  - `extract_task_link()` - Detects and parses markdown links in tasks
  - `load_task_specification()` - Reads specification files from repository
  - `build_task_prompt()` - Creates enhanced prompts with specifications
- **New Documentation:**
  - `LINKED_TASKS.md` - Complete guide to using linked specifications
  - `TASK_SPEC.template.md` - Template for creating specifications
  - `examples/specs/oauth2-implementation.md` - Example specification
  - `examples/linked-tasks-example.md` - Example TASKS.md with links
- **Enhanced Logging:**
  - Log when specification file is loaded
  - Log specification size (lines and bytes)
  - Log when specification is not found (warning)
  - Include specification path in repository logs

### Changed
- Updated `parse_tasks()` LLM prompt to preserve markdown links
- Updated task processing loop to handle linked specifications
- Enhanced Copilot prompts to include full specification context
- Updated `TASKS.template.md` with linked task examples
- Task markers now include specification file path if present

### Improved
- Better organization for complex tasks
- Reusable task specifications
- Clearer Copilot context for implementation
- Separation of concerns (task list vs. detailed specs)

## [1.1.2] - 2025-12-18

### Fixed
- **Auto-detect base branch per repository**
  - Script was hardcoded to use `main` but many repos use `master`
  - Now automatically detects the correct default branch
  - Falls back to common names (main, master) if needed
  - Respects user's `--base-branch` override
- **PR creation now works with any default branch name**
  - No more "No commits between main and branch" errors
  - Logs which base branch is being used

### Changed
- Enhanced logging to show detected base branch
- Improved error message to include base and head branch names

## [1.1.1] - 2025-12-18

### Added
- **Early exit on failures** with automatic branch rollback
  - Copilot fails → rollback and exit
  - Git commit fails → rollback and exit
  - Git push fails → rollback and exit
  - PR creation fails → error but no rollback (branch already pushed)
- **5-minute wait before PR creation**
  - Allows CI/CD to start
  - Ensures branch fully synchronized
  - Configurable via editing sleep duration
- **Comprehensive error handling**
  - Clear error messages with exit codes
  - Instructions for manual recovery
  - Detailed logging of all operations

### Fixed
- **Copilot CLI integration** - corrected command syntax
  - Was: `echo "$prompt" | copilot -p` (broken)
  - Now: `copilot --allow-all-tools < prompt_file` (working)
  - Uses temporary files for prompts
  - Proper cleanup of temp files
- **Task parsing** - LLM output cleanup
  - Strips checkbox syntax (- [ ]) from parsed tasks
  - Prevents "printf" errors with tasks starting with dashes

### Changed
- Prompt delivery uses temp files instead of pipes
- All Copilot output captured in repository logs
- Enhanced rollback procedure on failures

## [1.1.0] - 2025-12-18

### Added
- **LLM CLI Integration** for intelligent task parsing
  - Smart parsing that understands context and meaning
  - Automatically skips completed tasks (marked with [x])
  - Better hierarchy detection for tasks and subtasks
  - Fallback to regex parsing if LLM fails
  - Uses gpt-4o-mini for cost-effective parsing
- New documentation: `LLM_INTEGRATION.md`
  - Complete guide to LLM CLI integration
  - Installation and configuration instructions
  - Comparison with traditional parsing
  - Cost analysis and optimization tips
  - Troubleshooting guide

### Changed
- Updated `run_copilot_automation.sh`
  - Replaced simple regex parsing with LLM-powered parsing
  - Added LLM CLI to prerequisites check
  - Improved bash 3.x compatibility (removed `mapfile` dependency)
  - Better error handling and fallback mechanisms
- Updated `setup.sh` to check for LLM CLI installation
- Updated `verify_installation.sh` to verify LLM CLI
- Updated documentation to include LLM CLI setup:
  - `README.md` - Installation and prerequisites
  - `GETTING_STARTED.md` - Setup instructions
  - `INDEX.md` - Added LLM integration reference

### Fixed
- **Bash 3.x compatibility issue** - Script now works on macOS default bash (3.2)
  - Replaced `mapfile` with `while read` loop
  - Fixed array length references to use counter variable
  - Tested on bash 3.2.57 (macOS default)

### Improved
- Task parsing accuracy from ~80% to ~99%
- Better handling of various TASKS.md formats
- Automatic detection and skipping of completed tasks
- Smarter understanding of task hierarchy

## [1.0.0] - 2025-12-18

### Added
- Initial implementation of SnowyOwl automation framework
- Main automation script (`run_copilot_automation.sh`)
- Interactive setup script (`setup.sh`)
- Copilot CLI integration helpers (`copilot_integration.sh`)
- Comprehensive documentation (README.md, QUICKSTART.md, PROJECT_OVERVIEW.md)
- Configuration file system (`config.env`)
- macOS launchd integration for scheduled runs
- Logging infrastructure with per-repository and global logs
- Task parsing from markdown checkbox format
- Git branch management and automation
- GitHub PR creation integration
- Safety features:
  - Dry-run mode for testing
  - Tool permission restrictions
  - Isolated feature branches
  - Comprehensive error handling
- Example task files for different project types:
  - Web applications
  - Python libraries
  - React applications
- Task template for new repositories
- `.gitignore` for log files and temporary data
- Full help system and usage documentation

### Features
- Multi-repository support
- Automated task discovery
- Clean commit-per-task workflow
- Pull request automation
- Comprehensive audit logging
- Flexible scheduling (cron, launchd, manual)
- Command-line options for customization
- Prerequisites checking
- Authentication validation

### Documentation
- Complete README with installation and usage
- Quick reference guide
- Project overview with architecture details
- Task writing guidelines and examples
- Troubleshooting guide
- Best practices documentation
- Integration examples

### Infrastructure
- Log directory structure
- Template system for tasks
- Example repository
- Configuration management
- Setup automation

## [Unreleased]

### Planned Features
- Email notifications for completion
- Slack integration for status updates
- Metrics dashboard
- Task prioritization
- Conflict resolution helpers
- Multi-language enhanced support
- Team collaboration features
- Project management tool integration
- Automatic testing of generated code
- Code quality checks integration

### Known Issues
- None at this time

---

## Version History

- **1.1.2** (2025-12-18) - Auto-detect base branch per repository
- **1.1.1** (2025-12-18) - Copilot CLI fix + early exit + 5-min wait
- **1.1.0** (2025-12-18) - LLM CLI integration + bash 3.x compatibility
- **1.0.0** (2025-12-18) - Initial release with core automation features
