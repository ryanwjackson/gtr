#!/bin/bash

# gtr-core.sh - Core utilities and constants
# Contains version information, help text, and basic utility functions

# Default version string placeholder; replaced during release packaging
GTR_VERSION="@VERSION@"

# Version output helper for CLI
_gtr_print_version() {
  # If we have a real version (not the placeholder), use it directly
  if [[ -n "$GTR_VERSION" && "$GTR_VERSION" =~ ^v?[0-9]+\.[0-9]+(\.[0-9]+)?$ ]]; then
    echo "gtr version $GTR_VERSION"
    return
  fi

  # Otherwise, try to get version from various sources
  local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  local version_info=""

  # Method 1: Check Homebrew formula info first (for installed versions)
  if command -v brew >/dev/null 2>&1; then
    local brew_info
    brew_info=$(brew list --versions gtr 2>/dev/null | head -1)
    if [[ -n "$brew_info" ]]; then
      local brew_version="${brew_info#gtr }"
      echo "gtr version $brew_version"
      return
    fi
  fi

  # Method 2: Check if we're in a git repository (development case)
  if [[ -d "$script_dir/../.git" ]] && command -v git >/dev/null 2>&1; then
    local git_describe
    git_describe=$(cd "$script_dir/.." && git describe --tags --always 2>/dev/null)
    if [[ -n "$git_describe" ]]; then
      version_info=" ($git_describe)"
    fi
    echo "gtr version dev${version_info}"
    return
  fi

  # Method 3: Try to extract from script path (some package managers include version in path)
  if [[ "$script_dir" =~ /([0-9]+\.[0-9]+(\.[0-9]+)?)/bin$ ]]; then
    local path_version="${BASH_REMATCH[1]}"
    echo "gtr version $path_version"
    return
  fi

  # Fallback
  echo "gtr version unknown"
}

# Private helper functions (prefixed with _gtr_)
_gtr_get_base_dir() {
  echo "${GTR_BASE_DIR:-$HOME/Documents/dev/worktrees}"
}

# Helper function for getting repository name
# Usage: _gtr_get_repo_name
# Returns: repository name from git remote or directory name
_gtr_get_repo_name() {
  # Try to get repo name from git remote origin
  local repo_name=$(git remote get-url origin 2>/dev/null | sed 's/.*\///' | sed 's/\.git$//')

  # If that fails, use the directory name
  if [[ -z "$repo_name" ]]; then
    repo_name=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)")
  fi

  # Fallback to a default if still empty
  if [[ -z "$repo_name" ]]; then
    repo_name="unknown-repo"
  fi

  echo "$repo_name"
}

# Helper function for generating worktree branch names
# Usage: _gtr_get_worktree_branch_name "worktree_name"
# Returns: worktrees/$repo_name/$username/$worktree_name
_gtr_get_worktree_branch_name() {
  local worktree_name="$1"
  local username="${_GTR_USERNAME:-$(whoami)}"
  local repo_name="$(_gtr_get_repo_name)"
  echo "worktrees/$repo_name/$username/$worktree_name"
}

_gtr_get_main_worktree() {
  # Get the main worktree (the one that's not a worktree)
  local current_worktree=$(git rev-parse --show-toplevel)
  local git_dir=$(git rev-parse --git-dir)

  # If we're in a worktree, the git-dir will be in .git/worktrees/
  # The main worktree is the parent of the .git directory
  if [[ "$git_dir" == *"/.git/worktrees/"* ]]; then
    # We're in a worktree, get the main repository
    local main_git_dir=$(dirname "$(dirname "$git_dir")")
    # The main worktree is the parent of the .git directory
    echo "$(dirname "$main_git_dir")"
  else
    # We're in the main repository
    echo "$current_worktree"
  fi
}

_gtr_is_initialized() {
  local main_worktree="$(_gtr_get_main_worktree)"
  local global_config_file="$HOME/.gtr/config"
  local local_config_file="$main_worktree/.gtr/config"

  # Check if either global or local config file exists
  if [[ -f "$local_config_file" || -f "$global_config_file" ]]; then
    return 0  # Initialized
  else
    return 1  # Not initialized
  fi
}

_gtr_parse_global_flags() {
  local main_worktree="$(_gtr_get_main_worktree)"
  local editor="cursor"
  local no_open=false
  local no_install=false
  local username=$(whoami)
  local base_branch=""
  local untracked=""
  local args=()
  local extra_args=()
  local parsing_extra=false


  # Read default values from config
  local config_editor="$(_gtr_read_config_setting "$main_worktree" "settings" "editor" "cursor")"
  local config_run_pnpm="$(_gtr_read_config_setting "$main_worktree" "settings" "run_pnpm" "true")"
  local config_auto_open="$(_gtr_read_config_setting "$main_worktree" "settings" "auto_open" "true")"
  local config_worktree_base="$(_gtr_read_config_setting "$main_worktree" "settings" "worktree_base" "")"
  local config_untracked="$(_gtr_read_config_setting "$main_worktree" "settings" "untracked" "true")"

  # Set defaults from config
  editor="$config_editor"

  # Set worktree base if configured
  if [[ -n "$config_worktree_base" ]]; then
    if [[ "$config_worktree_base" == /* ]]; then
      # Absolute path
      export GTR_BASE_DIR="$config_worktree_base"
    else
      # Relative path from main worktree
      export GTR_BASE_DIR="$main_worktree/$config_worktree_base"
    fi
  fi

  while [[ $# -gt 0 ]]; do
    if [[ "$parsing_extra" == "true" ]]; then
      # Everything after -- goes to extra_args
      extra_args+=("$1")
      shift
      continue
    fi

    case "$1" in
      --)
        parsing_extra=true
        shift
        ;;
      --prefix)
        if [[ -n "$2" ]]; then
          prefix="$2"
          shift 2
        else
          echo "Error: --prefix requires a value"
          return 1
        fi
        ;;
      --prefix=*)
        prefix="${1#*=}"
        shift
        ;;
      --editor)
        if [[ -n "$2" ]]; then
          editor="$2"
          shift 2
        else
          echo "Error: --editor requires a value"
          return 1
        fi
        ;;
      --editor=*)
        editor="${1#*=}"
        shift
        ;;
      --username)
        if [[ -n "$2" ]]; then
          username="$2"
          shift 2
        else
          echo "Error: --username requires a value"
          return 1
        fi
        ;;
      --username=*)
        username="${1#*=}"
        shift
        ;;
      --no-open)
        no_open=true
        shift
        ;;
      --no-install)
        no_install=true
        shift
        ;;
      --base)
        if [[ -n "$2" ]]; then
          base_branch="$2"
          shift 2
        else
          echo "Error: --base requires a value"
          return 1
        fi
        ;;
      --base=*)
        base_branch="${1#*=}"
        shift
        ;;
      --untracked)
        if [[ -n "$2" ]]; then
          untracked="$2"
          shift 2
        else
          echo "Error: --untracked requires a value (true or false)"
          return 1
        fi
        ;;
      --untracked=*)
        untracked="${1#*=}"
        shift
        ;;
      --uncommitted)
        echo "Error: --uncommitted flag has been renamed to --untracked"
        echo "Please use --untracked instead"
        return 1
        ;;
      --uncommitted=*)
        echo "Error: --uncommitted flag has been renamed to --untracked"
        echo "Please use --untracked instead"
        return 1
        ;;
      --force|--dry-run)
        # These are command-specific flags, pass them through
        args+=("$1")
        shift
        ;;
      --*)
        echo "Error: Unknown option '$1'"
        echo "Valid global options: --prefix, --username, --editor, --no-open, --no-install, --base, --untracked"
        echo "Command-specific options: --force, --dry-run (for rm command)"
        return 1
        ;;
      *)
        args+=("$1")
        shift
        ;;
    esac
  done

  # Apply config-based defaults if not overridden by flags
  if [[ "$no_open" == "false" && "$config_auto_open" == "false" ]]; then
    no_open=true
  fi

  if [[ "$no_install" == "false" && "$config_run_pnpm" == "false" ]]; then
    no_install=true
  fi

  # Set untracked default from config if not specified
  if [[ -z "$untracked" ]]; then
    untracked="$config_untracked"
  fi


  # Export variables for use in other functions
  export _GTR_EDITOR="$editor"
  export _GTR_NO_OPEN="$no_open"
  export _GTR_NO_INSTALL="$no_install"
  export _GTR_USERNAME="$username"
  export _GTR_BASE_BRANCH="$base_branch"
  export _GTR_UNTRACKED="$untracked"

  # Set _GTR_ARGS and _GTR_EXTRA_ARGS in the global scope
  _GTR_ARGS=("${args[@]}")
  _GTR_EXTRA_ARGS=("${extra_args[@]}")
  export _GTR_ARGS
  export _GTR_EXTRA_ARGS
}

_gtr_show_help() {
  cat << 'EOF'
gtr - Git worktree helper

USAGE:
    gtr <COMMAND> [OPTIONS] [ARGS...]

COMMANDS:
    create, c <name>...           Create new worktrees
    remove, rm [name]...          Remove worktrees (with --force, --dry-run)
                                  If no name provided, removes current worktree
    cd <name>                     Change directory to worktree
    list, ls, l                   List all worktrees
    idea, i {create|list|open}    Manage idea files
    claude <name> [-- <args>...]  Run claude in worktree directory
    cursor <name> [-- <args>...]  Run cursor in worktree directory
    prune                         Clean up merged worktrees
    doctor [name]                 Check worktree for missing local files
    init                          Initialize gtr configuration
    --help, -h                    Show this help message
    --version, -v                 Show version

GLOBAL OPTIONS:
    --username <USERNAME>         Set username for branch naming (default: current user)
    --editor <EDITOR>             Set editor to open worktrees (default: cursor)
    --no-open                     Don't open editor after creating worktree
    --no-install                  Skip pnpm commands during worktree creation
    --base <BRANCH>               Base branch for worktree creation (default: current branch)
    --untracked <true|false>      Include untracked changes in worktree (default: true)

EXAMPLES:
    # Create worktrees
    gtr create feature0                    # Create worktree based on current branch
    gtr create feat1 feat2                 # Create multiple worktrees
    gtr create feature0 --base main        # Create worktree based on main branch
    gtr create feature0 --no-install       # Skip pnpm commands
    gtr create feature0 --no-open          # Don't open editor
    gtr create feature0 --untracked false  # Don't include untracked changes
    gtr create feature0 --base main --untracked false  # Create from main without untracked

    # Manage worktrees
    gtr list                               # List all worktrees
    gtr cd feature0                        # Navigate to worktree
    gtr claude feature0                    # Run claude in worktree
    gtr cursor feature0                    # Run cursor in worktree

    # Manage ideas
    gtr idea create                        # Create new idea (prompt for summary)
    gtr idea create 'New feature'          # Create idea with summary
    gtr idea create 'New feature' --less   # Create idea and open with less
    gtr idea list                          # List all ideas
    gtr idea list --mine                   # List your ideas
    gtr idea list --todo                   # List TODO ideas
    gtr idea open idea.md                  # Open idea file
    gtr idea open idea.md --less           # Open idea with less

    # Run tools with arguments
    gtr claude feature0 -- --model sonnet  # Run claude with specific model
    gtr cursor feature0 -- --new-window    # Run cursor with new window
    gtr claude feature0 -- --help          # Pass --help to claude

    # Cleanup
    gtr rm feature0                        # Remove worktree (with confirmation)
    gtr rm                                 # Remove current worktree (when inside one)
    gtr rm feature0 --force                # Force remove worktree
    gtr rm --dry-run                       # Show what would be removed (current worktree)
    gtr prune                              # Clean up merged worktrees
    gtr prune --base develop --force       # Clean up with custom base branch

    # Health check
    gtr doctor feature0                    # Check specific worktree
    gtr doctor                             # Check current directory (if it's a worktree)
    gtr doctor feature0 --fix              # Check and fix specific worktree
    gtr doctor --fix                       # Check and fix current worktree
    gtr doctor --fix --force               # Fix without interactive prompts

    # Configuration
    gtr init                               # Initialize gtr configuration
    gtr init --doctor                      # Check configuration coverage
    gtr init --doctor --fix                # Auto-add missing files to config

FEATURES:
    • Automatic copying of .env*local* files to new worktrees (recursive search)
    • Automatic copying of Claude settings (.claude/, .anthropic/)
    • Automatic pnpm approve-builds and pnpm install on creation
    • Smart branch naming with worktrees/repo_name/username/name pattern
    • Safe worktree removal with merge detection
    • Health checking with automatic fixing (recursive .env*local* detection)
    • Pass arguments to claude/cursor using -- delimiter

For more information, visit: https://medium.com/@dtunai/mastering-git-worktrees-with-claude-code-for-parallel-development-workflow-41dc91e645fe
EOF
}

# Idea management helper functions

# Helper function to get ideas directory
# Usage: _gtr_get_ideas_dir
# Returns: path to .gtr/ideas directory
_gtr_get_ideas_dir() {
  local main_worktree="$(_gtr_get_main_worktree)"
  echo "$main_worktree/.gtr/ideas"
}

# Helper function to create ideas directory if it doesn't exist
# Usage: _gtr_ensure_ideas_dir
# Returns: 0 on success, 1 on failure
_gtr_ensure_ideas_dir() {
  local ideas_dir="$(_gtr_get_ideas_dir)"
  
  if [[ ! -d "$ideas_dir" ]]; then
    if mkdir -p "$ideas_dir" 2>/dev/null; then
      echo "📁 Created ideas directory: $ideas_dir"
      return 0
    else
      echo "❌ Failed to create ideas directory: $ideas_dir" >&2
      return 1
    fi
  fi
  
  return 0
}

# Helper function to generate idea filename
# Usage: _gtr_generate_idea_filename "summary"
# Returns: filename in format [ISO_DATETIME]_[username]_[summary].md
_gtr_generate_idea_filename() {
  local summary="$1"
  local username="${_GTR_USERNAME:-$(whoami)}"
  local datetime=$(date -u +"%Y%m%dT%H%M%SZ")
  
  # Sanitize summary for filename (replace spaces with hyphens, replace special chars with dashes)
  # Use a more explicit approach to avoid locale/version issues with sed
  # First replace spaces with hyphens
  local sanitized_summary=$(echo "$summary" | sed 's/ /-/g')
  # Then replace any remaining non-alphanumeric characters (except dots, underscores, hyphens) with dashes
  sanitized_summary=$(echo "$sanitized_summary" | sed 's/[^a-zA-Z0-9._-]/-/g')
  # Only clean up leading/trailing dashes, preserve consecutive dashes in the middle
  sanitized_summary=$(echo "$sanitized_summary" | sed 's/^-\|-$//g')
  
  # Limit length to avoid filesystem issues
  if [[ ${#sanitized_summary} -gt 50 ]]; then
    sanitized_summary="${sanitized_summary:0:50}"
  fi
  
  echo "${datetime}_${username}_${sanitized_summary}.md"
}

# Helper function to get repository information
# Usage: _gtr_get_repo_info
# Returns: array with repo_name, repo_url, current_branch, latest_commit
_gtr_get_repo_info() {
  local repo_name="$(_gtr_get_repo_name)"
  local repo_url=$(git remote get-url origin 2>/dev/null || echo "")
  local current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
  local latest_commit=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
  
  echo "$repo_name|$repo_url|$current_branch|$latest_commit"
}

# Helper function to create idea file content
# Usage: _gtr_create_idea_content "summary" "repo_name" "repo_url" "current_branch" "latest_commit"
# Returns: markdown content for idea file
_gtr_create_idea_content() {
  local summary="$1"
  local repo_name="$2"
  local repo_url="$3"
  local current_branch="$4"
  local latest_commit="$5"
  local username="${_GTR_USERNAME:-$(whoami)}"
  local datetime=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  
  cat << EOF
---
summary: "$summary"
author: "$username"
datetime: "$datetime"
repo_name: "$repo_name"
repo_url: "$repo_url"
current_branch_name: "$current_branch"
latest_commit: "$latest_commit"
status: "TODO"
---

# $summary

## Description

<!-- Add your idea description here -->

## Implementation Notes

<!-- Add implementation details here -->

## Acceptance Criteria

<!-- Add acceptance criteria here -->

## Related Issues/PRs

<!-- Add related issues or PRs here -->
EOF
}

# Helper function to list ideas with filtering
# Usage: _gtr_list_ideas [--mine] [--todo] [--status=STATUS]
# Returns: list of idea files with metadata
_gtr_list_ideas() {
  local ideas_dir="$(_gtr_get_ideas_dir)"
  local show_mine="false"
  local show_todo="false"
  local status_filter=""
  local content_filter=""
  local username="${_GTR_USERNAME:-$(whoami)}"
  
  # Parse arguments
  for arg in "$@"; do
    case "$arg" in
      --mine)
        show_mine="true"
        ;;
      --todo)
        show_todo="true"
        ;;
      --status=*)
        status_filter="${arg#*=}"
        ;;
      --filter=*)
        content_filter="${arg#*=}"
        ;;
    esac
  done
  
  if [[ ! -d "$ideas_dir" ]]; then
    echo "No ideas directory found. Create your first idea with 'gtr idea create'"
    return 0
  fi
  
  local idea_files=()
  while IFS= read -r -d '' file; do
    if [[ -f "$file" && "$file" == *.md ]]; then
      idea_files+=("$file")
    fi
  done < <(find "$ideas_dir" -name "*.md" -type f -print0 2>/dev/null | sort -z)
  
  if [[ ${#idea_files[@]} -eq 0 ]]; then
    echo "No ideas found. Create your first idea with 'gtr idea create'"
    return 0
  fi
  
  echo "📋 Ideas:"
  echo ""
  
  for file in "${idea_files[@]}"; do
    local filename=$(basename "$file")
    local author=""
    local summary=""
    local status=""
    local datetime=""
    
    # Extract metadata from YAML front matter
    local in_frontmatter=false
    while IFS= read -r line; do
      if [[ "$line" == "---" ]]; then
        if [[ "$in_frontmatter" == "false" ]]; then
          in_frontmatter=true
        else
          break
        fi
      elif [[ "$in_frontmatter" == "true" ]]; then
        case "$line" in
          author:*)
            author="${line#author: }"
            author="${author%\"}"
            author="${author#\"}"
            ;;
          summary:*)
            summary="${line#summary: }"
            summary="${summary%\"}"
            summary="${summary#\"}"
            ;;
          status:*)
            status="${line#status: }"
            status="${status%\"}"
            status="${status#\"}"
            ;;
          datetime:*)
            datetime="${line#datetime: }"
            datetime="${datetime%\"}"
            datetime="${datetime#\"}"
            ;;
        esac
      fi
    done < "$file"
    
    # Apply filters
    local should_show=true
    
    if [[ "$show_mine" == "true" && "$author" != "$username" ]]; then
      should_show=false
    fi
    
    if [[ "$show_todo" == "true" && "$status" != "TODO" ]]; then
      should_show=false
    fi
    
    if [[ -n "$status_filter" && "$status" != "$status_filter" ]]; then
      should_show=false
    fi
    
    if [[ -n "$content_filter" ]]; then
      # Check if content filter matches summary or file content
      local content_match=false
      local filter_lower=$(echo "$content_filter" | tr '[:upper:]' '[:lower:]')
      local filter_upper=$(echo "$content_filter" | tr '[:lower:]' '[:upper:]')
      local summary_lower=$(echo "$summary" | tr '[:upper:]' '[:lower:]')
      
      if [[ "$summary" == *"$content_filter"* ]] || [[ "$summary_lower" == *"$filter_lower"* ]] || [[ "$summary" == *"$filter_upper"* ]]; then
        content_match=true
      else
        # Check file content for the filter
        if grep -qi "$content_filter" "$file" 2>/dev/null; then
          content_match=true
        fi
      fi
      
      if [[ "$content_match" == "false" ]]; then
        should_show=false
      fi
    fi
    
    if [[ "$should_show" == "true" ]]; then
      # Format datetime for display
      local display_date=""
      if [[ -n "$datetime" ]]; then
        display_date=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$datetime" "+%Y-%m-%d %H:%M" 2>/dev/null || echo "$datetime")
      fi
      
      # Display idea
      echo "📄 $filename"
      echo "   Summary: $summary"
      echo "   Author:  $author"
      echo "   Status:  $status"
      echo "   Date:    $display_date"
      echo ""
    fi
  done
}