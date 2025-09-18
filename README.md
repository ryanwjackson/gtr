## gtr — Git worktree helper

gtr is a lightweight helper around git worktrees that speeds up parallel development. It creates per-feature worktrees, copies local-only files (like .env*local*), can run pnpm setup, and provides safe pruning and a doctor to keep worktrees healthy.

### Features
- **Fast worktree creation**: `gtr create feature1` (optionally from `--base main`)
- **Copies local files**: `.env*local*`, `.claude/`, `.anthropic/` by default
- **Optional pnpm setup**: runs `pnpm approve-builds` and `pnpm install` if present
- **Safe removal/pruning**: detects merged branches and offers dry-run/force
- **Doctor**: verifies and fixes missing or diverged local files
- **Smart naming**: branches like `worktrees/<username>/<name>`

### Installation
1) Put `bin/gtr` somewhere on your PATH, or symlink it:
```bash
chmod +x bin/gtr
ln -sf "$PWD/bin/gtr" /usr/local/bin/gtr  # or ~/.local/bin
```

2) If you prefer to source as a shell function (recommended for speed and interactivity):
```bash
# Bash/Zsh
source /path/to/bin/gtr
# Optionally expose a wrapper so `gtr` works in subshells
command -v gtr >/dev/null || alias gtr='bash -lc "source /path/to/bin/gtr; gtr \"$@\""'
```

3) Initialize per-repo configuration once inside your main repo:
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

### License
MIT
