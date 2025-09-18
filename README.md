## gtr — Git worktree helper

gtr is a lightweight helper around git worktrees that speeds up parallel development. It creates per-feature worktrees, copies local-only files (like .env*local*), can run pnpm setup, and provides safe pruning and a doctor to keep worktrees healthy.

> **🏗️ Modular Architecture**: gtr now features a modular design with separate modules for different concerns, comprehensive testing, and improved maintainability. See [REFACTORING_SUMMARY.md](./REFACTORING_SUMMARY.md) for details.

### Features
- **Fast worktree creation**: `gtr create feature1` (optionally from `--base main`)
- **Copies local files**: `.env*local*`, `.claude/`, `.anthropic/` by default
- **Optional pnpm setup**: runs `pnpm approve-builds` and `pnpm install` if present
- **Safe removal/pruning**: detects merged branches and offers dry-run/force
- **Doctor**: verifies and fixes missing or diverged local files
- **Smart naming**: branches like `worktrees/<username>/<name>`
- **Idea management**: `gtr idea create` and `gtr idea list` for tracking development ideas

### Installation

#### Homebrew (recommended)
```bash
brew tap ryanwjackson/tap
brew install ryanwjackson/tap/gtr
```

To upgrade to the latest version:
```bash
brew update
brew upgrade gtr
```

#### Manual installation

**Option 1: Modular version (recommended for development)**
```bash
# Use the new modular entry point
chmod +x bin/gtr-new
ln -sf "$PWD/bin/gtr-new" /usr/local/bin/gtr  # or ~/.local/bin
```

**Option 2: Original monolithic version**
```bash
# Use the original single-file version
chmod +x bin/gtr
ln -sf "$PWD/bin/gtr" /usr/local/bin/gtr  # or ~/.local/bin
```

**Option 3: Source as shell function (fastest)**
```bash
# Bash/Zsh - works with either version
source /path/to/bin/gtr-new  # or bin/gtr
# Optionally expose a wrapper so `gtr` works in subshells
command -v gtr >/dev/null || alias gtr='bash -lc "source /path/to/bin/gtr-new; gtr \"$@\""'
```

**Initialize configuration:**
```bash
gtr init
```

### Completion
Completion scripts are provided in `completions/`.

- **Bash**:
  - Copy or source `completions/gtr.bash`
  - Bash (Homebrew): `mkdir -p ~/.bash_completion && cp completions/gtr.bash ~/.bash_completion/`
  - Then add to `~/.bashrc`: `source ~/.bash_completion/gtr.bash`

- **Zsh**:
  - Copy `_gtr` into a directory in your `$fpath`, e.g. `~/.zsh/completions`
  - `mkdir -p ~/.zsh/completions && cp completions/_gtr ~/.zsh/completions/`
  - In `~/.zshrc`: `fpath=(~/.zsh/completions $fpath)` then `autoload -Uz compinit && compinit`

- **Fish**:
  - `mkdir -p ~/.config/fish/completions`
  - `cp completions/gtr.fish ~/.config/fish/completions/gtr.fish`

### Man page
A manual page is included at `man/man1/gtr.1`.

- Local view:
```bash
man -l man/man1/gtr.1
```
- System install (requires sudo):
```bash
sudo mkdir -p /usr/local/share/man/man1
sudo cp man/man1/gtr.1 /usr/local/share/man/man1/
sudo mandb 2>/dev/null || true  # macOS may not have mandb; Spotlight updates automatically
```

### Usage
```bash
gtr <command> [global options] [args]

# Create worktrees
gtr create feature0                       # from current branch
gtr create feat1 feat2                    # multiple at once
gtr create feature0 --base main           # base off main
gtr create feature0 --no-install --no-open

# Manage and navigate
gtr list
gtr cd feature0
gtr claude feature0

# Idea management
gtr idea                                  # create new idea (prompt for summary)
gtr idea 'New feature idea'               # create idea with summary
gtr idea list                             # list all ideas across worktrees
gtr idea list --mine                      # list your ideas only
gtr idea list --todo                      # list TODO status ideas
gtr idea list --filter=performance        # search ideas by content

# Cleanup
gtr rm feature0 --dry-run                 # preview removal
gtr prune --base develop --force          # remove merged worktrees

# Health check
gtr doctor feature0                       # check specific worktree
gtr doctor --fix --force                  # fix current or named worktree

# Configuration
gtr init                                  # create .gtr/config
gtr init --doctor --fix                   # analyze and auto-add missing local files
```

### Global options
- **--prefix <PREFIX>**: branch prefix (default: `claude`)
- **--username <USERNAME>**: username for branch naming (default: current user)
- **--editor <EDITOR>**: editor to open worktrees (default: `cursor`)
- **--no-open**: do not open editor after creation
- **--no-install**: skip pnpm commands during creation
- **--base <BRANCH>**: base branch for creation/pruning

### Command-specific options
- **remove/rm**: `--force`, `--dry-run`
- **prune**: `--base`, `--dry-run`, `--force`
- **doctor**: `--fix`, `--force`
- **init**: `--doctor`, `--fix`
- **idea list**: `--mine`, `--todo`, `--status=STATUS`, `--filter=STRING`

### Idea Management

gtr includes a built-in idea management system for tracking development ideas across worktrees:

#### Creating Ideas
```bash
gtr idea                                  # Prompt for idea summary (default)
gtr idea 'Performance optimization'       # Create with summary
gtr i 'Quick idea'                        # Short form
```

Ideas are stored as markdown files in `.gtr/ideas/` with YAML frontmatter containing:
- `summary`: Idea title/summary
- `author`: Your username
- `datetime`: ISO timestamp
- `repo_name`: Repository name
- `repo_url`: Repository URL
- `current_branch_name`: Branch where created
- `latest_commit`: Full commit hash
- `status`: Status (default: "TODO")

#### Listing Ideas
```bash
gtr idea list                             # List all ideas across worktrees
gtr idea list --mine                      # Show only your ideas
gtr idea list --todo                      # Show only TODO status
gtr idea list --status=IN_PROGRESS        # Show specific status
gtr idea list --filter=performance        # Search by content (case-insensitive)
gtr i l --filter=bug                      # Short form with filter
```

Ideas are automatically:
- **Ordered chronologically** (newest first)
- **Searched across all worktrees** and main repository
- **Filtered by content** in both title and markdown body
- **Displayed with worktree context** showing where each idea was created

### Configuration (.gtr/config)
INI-like sections in your main repository:

- **[files_to_copy]**: glob patterns copied into new worktrees
  - defaults: `.env*local*`, `.env.*local*`, `.claude/`, `.anthropic/`
- **[settings]**: `editor`, `prefix`, `run_pnpm`, `auto_open`, optional `worktree_base`
- **[doctor]**: `show_detailed_diffs`, `auto_fix`

### Environment
- **GTR_BASE_DIR**: override the base directory for worktrees (default `~/Documents/dev/worktrees`). If `settings.worktree_base` is set in `.gtr/config`, it takes precedence (relative to the main repo unless absolute).

### Requirements
- `git` 2.37+
- Optional: `pnpm` for Node repos, `diff3` for better merges

### Development

#### Architecture
gtr uses a modular architecture with the following structure:

```
gtr/
├── bin/
│   ├── gtr          # Original monolithic script (2300+ lines)
│   └── gtr-new      # New modular entry point (105 lines)
├── lib/             # Core library modules
│   ├── gtr-core.sh     # Core utilities and constants
│   ├── gtr-ui.sh       # User interaction functions
│   ├── gtr-config.sh   # Configuration management
│   ├── gtr-files.sh    # File operations
│   ├── gtr-git.sh      # Git operations
│   └── gtr-commands.sh # Public command implementations
├── test/            # Unit tests
│   ├── test-core.sh
│   ├── test-config.sh
│   ├── test-files.sh
│   └── test-runner.sh
└── test-helpers/    # Testing framework
    ├── test-utils.sh   # Assertion framework
    └── mock-git.sh     # Git mocking system
```

#### Testing
Run the comprehensive test suite to ensure code quality:

```bash
# Run all tests (30+ tests across 4 suites)
./test/test-runner.sh

# Run specific test suite
./test/test-runner.sh core    # Core functions (7 tests)
./test/test-runner.sh config  # Configuration (8 tests)
./test/test-runner.sh files   # File operations (8 tests)
./test/test-runner.sh ideas   # Idea management (8+ tests)

# List available tests
./test/test-runner.sh --list

# Run individual test files
bash test/test-core.sh
bash test/test-config.sh
bash test/test-files.sh
bash test/test-ideas.sh

# Simulate GitHub Actions locally
./.github/test-local.sh
```

**Continuous Integration**: Tests run automatically on GitHub Actions for all pushes and pull requests. See `.github/workflows/ci.yml` for the main CI pipeline.

#### Contributing
When modifying gtr:

1. **Understand the module structure** - See [REFACTORING_SUMMARY.md](./REFACTORING_SUMMARY.md)
2. **Write tests first** - Add tests for new functionality
3. **Test thoroughly** - Run `./test/test-runner.sh` before submitting
4. **Maintain compatibility** - Ensure both `gtr` and `gtr-new` work identically
5. **Update documentation** - Keep README and module comments current

#### Module Dependencies
Modules must be sourced in dependency order:
1. `gtr-core.sh` (no dependencies)
2. `gtr-ui.sh` (no dependencies)
3. `gtr-config.sh` (depends on gtr-ui.sh)
4. `gtr-files.sh` (depends on gtr-config.sh, gtr-ui.sh)
5. `gtr-git.sh` (depends on gtr-core.sh, gtr-config.sh, gtr-files.sh, gtr-ui.sh)
6. `gtr-commands.sh` (depends on all above)

### License
MIT

### Versioning
- `gtr --version` (or `-v`) prints the installed release tag as `gtr version <tag>`.
- The version is injected at build time for Homebrew releases. Running from a Git checkout (no CI replacement) prints `gtr version unknown`.

### Releasing
Use the helper to tag and create a GitHub Release:

```bash
# Basic: adds leading v automatically and uses the tag as notes/title
bin/release 0.1.2

# Or pass the tag explicitly
bin/release v0.1.2

# Custom message for release notes/title
bin/release 0.1.2 -m "Bugfixes and improvements"

# Help
bin/release --help
```

Notes:
- Requires GitHub CLI `gh` authenticated to this repo (`gh auth status`).
- Creates an annotated git tag if missing, pushes it, then creates the Release if absent.
