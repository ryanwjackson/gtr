# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

gtr is a Git worktree helper tool written in Bash that speeds up parallel development by creating per-feature worktrees with automatic file copying and setup. The project uses a modular architecture split between a legacy monolithic script and a new modular system.

## Development Commands

### Testing
```bash
# Run all tests (91 tests across 10 suites) - ALWAYS run before and after changes
./test/test-runner.sh
# OR use the convenience script:
./bin/test

# Run test categories
./test/test-runner.sh helpers  # All helper tests (40 tests)
./test/test-runner.sh actions  # All action tests (51 tests)

# Run specific helper test suites
./test/test-runner.sh core     # Core functions (7 tests)
./test/test-runner.sh config   # Configuration (8 tests)
./test/test-runner.sh files    # File operations (8 tests)
./test/test-runner.sh hooks    # Hook execution (17 tests)

# Run specific action test suites
./test/test-runner.sh create   # Create command (6 tests)
./test/test-runner.sh init     # Init command (9 tests)
./test/test-runner.sh remove   # Remove command (6 tests)
./test/test-runner.sh prune    # Prune command (6 tests)
./test/test-runner.sh stash    # Stash functionality (5 tests)
./test/test-runner.sh ideas    # Ideas management (22 tests)

# Run individual test files directly
bash test/helpers/test-core.sh
bash test/actions/test-create.sh
# ... etc

# Simulate GitHub Actions locally
./.github/test-local.sh
```

### Development Testing
```bash
# Test the modular version (ALWAYS use for development - tests current changes)
./bin/gtr-new --version
./bin/gtr-new --help
./bin/gtr-new create test-branch --no-open

# Test dry-run functionality
./bin/gtr-new create feature-test --dry-run
./bin/gtr-new remove feature-test --dry-run
./bin/gtr-new prune --dry-run

# Test the legacy version (compatibility check with current repository)
./bin/gtr --version

# Compare with installed Homebrew version (only when comparing behavior)
gtr --version  # This uses the system-installed version via brew
```

### Release Management
```bash
# Create and publish a new release
bin/release 0.1.2
bin/release v0.1.2
bin/release 0.1.2 -m "Custom release message"
```

## Architecture

### Important: Development vs Production Versions

- **Production/Installed**: `gtr` command (installed via Homebrew) - Only use for comparing behavior with released version
- **Development**: `./bin/gtr-new` (3.3KB modular entry point) - **ALWAYS use this for testing current changes**
- **Legacy/Compatibility**: `./bin/gtr` (80KB monolithic script) - Use for compatibility verification

**Critical**: When developing, always use `./bin/gtr-new` to test your changes. The `gtr` command uses the system-installed version and won't reflect your modifications.

### Modular Design
The project uses a dual-architecture approach:

- **Legacy**: `bin/gtr` (80KB monolithic script, 2300+ lines)
- **Modular**: `bin/gtr-new` (3.3KB entry point) + `lib/` modules

### Module Structure (lib/)
Modules must be sourced in exact dependency order:

1. **gtr-core.sh** (21KB) - Core utilities, version, help, repo detection
2. **gtr-ui.sh** (1.1KB) - User interaction functions (_gtr_ask_user)
3. **gtr-config.sh** (26KB) - Configuration reading/writing (depends on gtr-ui.sh)
4. **gtr-files.sh** (5.6KB) - File operations, copying, diffing (depends on gtr-config.sh, gtr-ui.sh)
5. **gtr-git.sh** (20KB) - Git worktree management (depends on gtr-core.sh, gtr-config.sh, gtr-files.sh, gtr-ui.sh)
6. **gtr-commands.sh** (22KB) - Public command implementations (depends on all above)
7. **gtr-ideas.sh** (19KB) - Idea management system
8. **gtr-hooks.sh** (3.5KB) - Hook execution system

### Key Components

- **Worktree Management**: Create, remove, and manage Git worktrees with automatic branch naming (`worktrees/<username>/<name>`)
- **File Copying**: Automatically copy local files (`.env*local*`, `.claude/`, `.anthropic/`) to new worktrees
- **Idea System**: Built-in markdown-based idea tracking with YAML frontmatter across worktrees
- **Configuration**: INI-like config system in `.gtr/config` with file patterns and settings
- **Hook System**: Execute custom commands during worktree operations

### Critical Development Rules

1. **Use Development Version**: **ALWAYS use `./bin/gtr-new` for testing changes** - the `gtr` command is the Homebrew-installed version and won't reflect your modifications
2. **Module-First Development**: Add functionality to appropriate modules in `lib/`, never modify `bin/gtr` directly
3. **Testing Required**: Always run `./test/test-runner.sh` before and after changes
4. **Compatibility Promise**: Both `bin/gtr` and `bin/gtr-new` must work identically
5. **Dependency Order**: Never break module sourcing order or introduce circular dependencies

### Function Naming Conventions

- `_gtr_*` - Private/internal functions
- `gtr_*` - Public command functions (in gtr-commands.sh)
- Modules use consistent prefixes matching their filename

### Testing Framework

- **Isolated Environment**: Each test runs in temporary git repository
- **Comprehensive Assertions**: `assert_equals`, `assert_contains`, `assert_file_exists`, etc.
- **Git Mocking**: Mock git operations for reliable testing
- **Automatic Cleanup**: Temporary files cleaned up after each test
- **Cross-Platform**: Tests use portable paths and avoid hardcoded user directories

### Test Structure

The test suite is organized with an action-based structure:

```
test/
├── actions/           # User-facing command tests
│   ├── test-create.sh     # Create command functionality
│   ├── test-remove.sh     # Remove command functionality
│   ├── test-prune.sh      # Prune command functionality
│   ├── test-init.sh       # Init command functionality
│   ├── test-stash.sh      # Stash functionality
│   └── test-ideas.sh      # Ideas management functionality
├── helpers/           # Shared functionality tests
│   ├── test-core.sh       # Core function tests
│   ├── test-config.sh     # Configuration tests
│   ├── test-files.sh      # File operation tests
│   ├── test-hooks.sh      # Hook execution tests
│   ├── test-utils.sh      # Testing framework utilities
│   └── mock-git.sh        # Git mocking utilities
└── test-runner.sh     # Main test runner
```

**Key Features:**
- **Action-Based Organization**: Tests grouped by user-facing commands
- **Helper Tests**: Shared functionality tested separately
- **Convenience Script**: `./bin/test` forwards to `./test/test-runner.sh`
- **Granular Execution**: Run individual tests, categories, or all tests
- **Dry-Run Testing**: Comprehensive tests for `--dry-run` functionality

## Development Workflow

1. Read `REFACTORING_SUMMARY.md` to understand architecture changes
2. Run `./test/test-runner.sh` to ensure clean starting state
3. Identify target module(s) for changes
4. Write/update tests first
5. Implement changes maintaining module boundaries
6. Test with `./bin/gtr-new` (development version) - **never use `gtr` for testing your changes**
7. Verify both `./bin/gtr-new` and `./bin/gtr` work identically for compatibility
8. Run full test suite again

**Remember**: The `gtr` command is installed via Homebrew and reflects the released version, not your development changes. Always use `./bin/gtr-new` during development.

## Configuration

The project uses `.gtr/config` with INI-like sections:
- `[files_to_copy]` - Glob patterns for file copying
- `[settings]` - Editor, prefix, pnpm settings, auto-open behavior
- `[doctor]` - Diagnostic and auto-fix settings

Environment variable `GTR_BASE_DIR` can override worktree location (default: `~/Documents/dev/worktrees`).