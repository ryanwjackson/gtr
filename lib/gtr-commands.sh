#!/bin/bash

# gtr-commands.sh - Public command implementations
# Contains all the public gtr_* command functions

# Public command functions
gtr_create() {
  local dry_run="false"
  local names=()

  # Parse arguments for create command
  for arg in "${_GTR_ARGS[@]}"; do
    if [[ "$arg" == "--dry-run" ]]; then
      dry_run="true"
    else
      names+=("$arg")
    fi
  done

  # Check if configuration exists (either global or local)
  if ! _gtr_is_initialized; then
    echo "❌ No gtr configuration found"
    echo "   Run 'gtr init' to create a global configuration (~/.gtr/config)"
    echo "   or create a local configuration in this repository (.gtr/config)"
    return 1
  fi

  # Use the global base_branch variable, default to current branch if not set
  if [[ -z "$_GTR_BASE_BRANCH" ]]; then
    _GTR_BASE_BRANCH=$(git rev-parse --abbrev-ref HEAD)
  fi

  for name in "${names[@]}"; do
    if [[ "$dry_run" == "true" ]]; then
      echo "🔍 [DRY RUN] Would create worktree: $name"
      echo "🔍 [DRY RUN] Base branch: $_GTR_BASE_BRANCH"
      echo "🔍 [DRY RUN] Target branch: $(_gtr_get_worktree_branch_name "$name")"
    else
      _gtr_create_worktree "$name"
    fi
  done

  if [[ "$dry_run" == "true" ]]; then
    echo "🔍 Dry run complete! Use without --dry-run to actually create worktrees."
  fi
}

gtr_remove() {
  local force="false"
  local dry_run="false"
  local names=()

  # Check for flags and separate them from names
  for arg in "${_GTR_ARGS[@]}"; do
    if [[ "$arg" == "--force" ]]; then
      force="true"
    elif [[ "$arg" == "--dry-run" ]]; then
      dry_run="true"
    else
      names+=("$arg")
    fi
  done

  # If no worktree names provided, check if we're in a worktree
  if [[ ${#names[@]} -eq 0 ]]; then
    local current_dir="$(pwd)"
    local git_dir=$(git rev-parse --git-dir 2>/dev/null)

    if [[ -n "$git_dir" && "$git_dir" == *"/.git/worktrees/"* ]]; then
      # We're in a worktree, extract the worktree name
      local worktree_name=$(basename "$current_dir")
      echo "🔍 No worktree specified, detected current worktree: $worktree_name"
      names+=("$worktree_name")
    else
      echo "❌ No worktree specified and not currently in a worktree"
      echo "💡 Usage: gtr rm <worktree-name> or run from within a worktree"
      echo "💡 Available worktrees:"
      git worktree list
      return 1
    fi
  fi

  for name in "${names[@]}"; do
    _gtr_remove_worktree "$name" "$force" "$dry_run"
  done

  if [[ "$dry_run" == "true" ]]; then
    echo "🔍 Dry run complete! Use without --dry-run to actually remove worktrees."
  fi
}

gtr_cd() {
  local name=""
  if [[ ${#_GTR_ARGS[@]} -gt 0 ]]; then
    name="${_GTR_ARGS[0]}"
  fi

  if [[ -z "$name" ]]; then
    echo "Usage: gtr cd <name>"
    return 1
  fi

  local worktree_path="$(_gtr_get_worktree_path "$name")"

  # First check if the worktree directory exists
  if [[ -d "$worktree_path" ]]; then
    cd "$worktree_path" || { echo "Cannot change to worktree: $worktree_path"; return 1; }
  # Otherwise check if it's a branch name
  elif git rev-parse --verify "$name" >/dev/null 2>&1; then
    local main_worktree="$(_gtr_get_main_worktree)"
    cd "$main_worktree" || { echo "Cannot change to main worktree: $main_worktree"; return 1; }
  else
    echo "No such worktree or branch: $name"
    return 1
  fi
}

gtr_list() {
  git worktree list
}

gtr_claude() {
  local name=""
  local claude_args=()
  if [[ ${#_GTR_ARGS[@]} -gt 0 ]]; then
    name="${_GTR_ARGS[0]}"
  fi
  if [[ ${#_GTR_EXTRA_ARGS[@]} -gt 0 ]]; then
    claude_args=("${_GTR_EXTRA_ARGS[@]}")
  fi

  if [[ -z "$name" ]]; then
    echo "Usage: gtr claude <name> [-- <claude_args>...]"
    return 1
  fi

  local dir
  dir=$(_gtr_find_or_create_worktree "$name") || return 1

  if [[ ${#claude_args[@]} -gt 0 ]]; then
    ( cd "$dir" && claude "${claude_args[@]}" )
  else
    ( cd "$dir" && claude )
  fi
}

gtr_cursor() {
  local name=""
  local cursor_args=()
  if [[ ${#_GTR_ARGS[@]} -gt 0 ]]; then
    name="${_GTR_ARGS[0]}"
  fi
  if [[ ${#_GTR_EXTRA_ARGS[@]} -gt 0 ]]; then
    cursor_args=("${_GTR_EXTRA_ARGS[@]}")
  fi

  if [[ -z "$name" ]]; then
    echo "Usage: gtr cursor <name> [-- <cursor_args>...]"
    return 1
  fi

  local dir
  dir=$(_gtr_find_or_create_worktree "$name") || return 1

  if [[ ${#cursor_args[@]} -gt 0 ]]; then
    ( cd "$dir" && cursor "${cursor_args[@]}" )
  else
    ( cd "$dir" && cursor )
  fi
}

gtr_prune() {
  local base_branch="main"
  local dry_run="false"
  local force="false"

  # Parse prune-specific flags
  for arg in "${_GTR_ARGS[@]}"; do
    case "$arg" in
      --base)
        # This won't work in a simple loop, but we'll handle it in the main function
        ;;
      --dry-run)
        dry_run="true"
        ;;
      --force)
        force="true"
        ;;
    esac
  done

  # Handle --base flag properly
  local i=0
  while [[ $i -lt ${#_GTR_ARGS[@]} ]]; do
    if [[ "${_GTR_ARGS[$i]}" == "--base" && $((i+1)) -lt ${#_GTR_ARGS[@]} ]]; then
      base_branch="${_GTR_ARGS[$((i+1))]}"
      i=$((i+2))
    else
      i=$((i+1))
    fi
  done

  export _GTR_BASE_BRANCH="$base_branch"
  export _GTR_DRY_RUN="$dry_run"
  export _GTR_FORCE="$force"

  _gtr_prune_worktrees
}

gtr_init() {
  local init_doctor="${_GTR_INIT_DOCTOR:-false}"
  local init_fix="${_GTR_INIT_FIX:-false}"
  local current_dir="$(pwd)"
  local global_config_dir="$HOME/.gtr"
  local global_config_file="$global_config_dir/config"
  local local_config_dir="$current_dir/.gtr"
  local local_config_file="$local_config_dir/config"
  
  if [[ "$init_doctor" == "true" ]]; then
    # For doctor mode, check the config that would be used
    local config_file="$local_config_file"
    if [[ ! -f "$local_config_file" && -f "$global_config_file" ]]; then
      config_file="$global_config_file"
    fi
    _gtr_init_doctor "$current_dir" "$config_file" "$init_fix"
  else
    # Ask about global config first
    if [[ ! -f "$global_config_file" ]]; then
      echo "🔧 No global gtr configuration found at ~/.gtr/config"
      echo ""
      printf "Create global config? [Y/n] "
      read -r choice
      if [[ -z "$choice" ]]; then
        choice="Y"
      fi
      case "$choice" in
        [nN]|[nN][oO])
          echo "⏭️  Skipping global configuration"
          ;;
        *)
          _gtr_init_global_config "$global_config_dir" "$global_config_file"
          ;;
      esac
    else
      echo "📋 Global config already exists: $global_config_file"
      echo ""
      echo "What would you like to do with the global config?"
      echo "  [k]eep    - Keep existing global configuration"
      echo "  [u]pdate  - Update/recreate global configuration"
      echo "  [d]iff    - Show diff between current and default"
      echo ""

      printf "Choose [keep/update/diff]: "
      read -r choice
      if [[ -z "$choice" ]]; then
        choice="keep"
      fi
      case "$choice" in
        [uU]|update)
          _gtr_init_config_with_options "$global_config_dir" "$global_config_file" "global"
          ;;
        [dD]|diff)
          _gtr_show_config_diff "$global_config_file"
          ;;
        *)
          echo "✅ Keeping existing global configuration"
          ;;
      esac
    fi

    echo ""

    # Ask about local config
    if [[ ! -f "$local_config_file" ]]; then
      echo "🤔 Would you like to create a local .gtr/config for this repository?"
      echo "   This will override the global config (~/.gtr/config) for this repo only."
      echo ""

      printf "Create local config? [y/N] "
      read -r choice
      if [[ -z "$choice" ]]; then
        choice="N"
      fi
      case "$choice" in
        [yY]|[yY][eE][sS])
          _gtr_init_config "$current_dir" "$local_config_dir" "$local_config_file"
          ;;
        *)
          echo "✅ Using global configuration at $global_config_file"
          ;;
      esac
    else
      echo "📋 Local config already exists: $local_config_file"
      _gtr_init_config "$current_dir" "$local_config_dir" "$local_config_file"
    fi
  fi
}

gtr_doctor() {
  local worktree_name=""
  if [[ ${#_GTR_ARGS[@]} -gt 0 ]]; then
    worktree_name="${_GTR_ARGS[1]}"
  fi
  local fix_mode="${_GTR_FIX_MODE:-false}"
  local force_mode="${_GTR_FORCE_MODE:-false}"
  local username="${_GTR_USERNAME:-$(whoami)}"
  local current_dir="$(pwd)"

  # Detect if we're in a worktree or main repo
  local git_dir=$(git rev-parse --git-dir)
  local is_worktree=false
  local main_worktree=""
  local worktree_path=""

  if [[ "$git_dir" == *"/.git/worktrees/"* ]]; then
    # We're in a worktree
    is_worktree=true
    main_worktree=$(dirname "$(dirname "$(dirname "$git_dir")")")
    worktree_path="$current_dir"
    echo "🔍 Running from worktree: $worktree_path"
  else
    # We're in the main repository
    is_worktree=false
    main_worktree="$current_dir"
    echo "🔍 Running from main repository: $main_worktree"
  fi

  # If worktree name provided, find that specific worktree
  if [[ -n "$worktree_name" ]]; then
    if [[ "$worktree_name" == *"/"* ]]; then
      # Full worktree path provided
      worktree_path="$worktree_name"
    else
      # Just the name, try to find the worktree using git worktree list
      worktree_path=$(git worktree list --porcelain | awk -v name="$worktree_name" '
        /^worktree / { worktree_path = $2 }
        /^branch refs\/heads\// {
          branch = substr($0, 19)
          if (branch ~ name || worktree_path ~ name) {
            print worktree_path
            exit
          }
        }
      ')

      if [[ -z "$worktree_path" ]]; then
        echo "❌ Worktree not found: $worktree_name"
        echo "💡 Available worktrees:"
        git worktree list
        return 1
      fi
    fi

    if [[ ! -d "$worktree_path" ]]; then
      echo "❌ Worktree not found: $worktree_path"
      echo "💡 Available worktrees:"
      git worktree list
      return 1
    fi
  elif [[ "$is_worktree" == "false" ]]; then
    # Running from main repo without specifying worktree name
    echo "Usage: gtr doctor [WORKTREE_NAME] [--fix] [--username USERNAME]"
    echo "  WORKTREE_NAME: Name of the worktree to check"
    echo "  When run from main repo, WORKTREE_NAME is required"
    return 1
  fi

  echo "📋 Source (main repo): $main_worktree"
  echo "📋 Target (worktree): $worktree_path"
  echo ""

  local missing_files=()
  local different_files=()
  local missing_dirs=()

  # Read configuration patterns
  local patterns=($(_gtr_read_config "$main_worktree"))

  # Check files and directories based on configuration
  for pattern in "${patterns[@]}"; do
    if [[ "$pattern" == */ ]]; then
      # Directory pattern
      local dir_name="${pattern%/}"
      if [[ -d "$main_worktree/$dir_name" ]]; then
        if [[ ! -d "$worktree_path/$dir_name" ]]; then
          missing_dirs+=("$dir_name/")
        fi
      fi
    else
      # File pattern - use find to search recursively
      while IFS= read -r -d '' file; do
        if [[ -f "$file" ]]; then
          local relative_path="${file#$main_worktree/}"
          local target_file="$worktree_path/$relative_path"
          if [[ ! -f "$target_file" ]]; then
            missing_files+=("$relative_path")
          elif _gtr_files_different "$file" "$target_file"; then
            different_files+=("$relative_path")
          fi
        fi
      done < <(find "$main_worktree" -name "$pattern" -type f -print0 2>/dev/null)
    fi
  done

  # Check hooks
  local missing_hooks=()
  local different_hooks=()
  _gtr_check_hooks "$main_worktree" "$worktree_path" missing_hooks different_hooks

  # Report findings
  if [[ ${#missing_files[@]} -eq 0 && ${#different_files[@]} -eq 0 && ${#missing_dirs[@]} -eq 0 && ${#missing_hooks[@]} -eq 0 && ${#different_hooks[@]} -eq 0 ]]; then
    echo "✅ All local files and hooks are present and up-to-date in the worktree"
    return 0
  fi

  if [[ ${#missing_files[@]} -gt 0 ]]; then
    echo "❌ Missing files in worktree:"
    for file in "${missing_files[@]}"; do
      echo "  - $file"
    done
  fi

  if [[ ${#different_files[@]} -gt 0 ]]; then
    echo "⚠️  Different files in worktree:"
    for file in "${different_files[@]}"; do
      echo "  - $file"
    done
  fi

  if [[ ${#missing_dirs[@]} -gt 0 ]]; then
    echo "❌ Missing directories in worktree:"
    for dir in "${missing_dirs[@]}"; do
      echo "  - $dir"
    done
  fi

  if [[ ${#missing_hooks[@]} -gt 0 ]]; then
    echo "❌ Missing hooks in worktree:"
    for hook in "${missing_hooks[@]}"; do
      echo "  - $hook"
    done
  fi

  if [[ ${#different_hooks[@]} -gt 0 ]]; then
    echo "⚠️  Different hooks in worktree:"
    for hook in "${different_hooks[@]}"; do
      echo "  - $hook"
    done
  fi

  if [[ "$fix_mode" == "true" ]]; then
    echo ""
    echo "🔧 Fixing files..."
    _gtr_copy_local_files "$main_worktree" "$worktree_path" "$force_mode" "$main_worktree"
    
    # Fix hooks if needed
    if [[ ${#missing_hooks[@]} -gt 0 || ${#different_hooks[@]} -gt 0 ]]; then
      echo "🔧 Fixing hooks..."
      _gtr_copy_hooks_to_worktree "$main_worktree" "$worktree_path"
    fi
    
    echo "✅ Fix complete!"
  else
    echo ""
    echo "💡 To fix files, run:"
    if [[ ${#different_files[@]} -gt 0 ]]; then
      echo "   gtr doctor $worktree_name --fix --username $username"
      echo "   (Use --force to skip interactive prompts for different files)"
    else
      echo "   gtr doctor $worktree_name --fix --username $username"
    fi
  fi
}

# Idea management commands

_gtr_idea_show_help() {
  cat << 'EOF'
gtr idea - Manage development ideas across worktrees

USAGE:
    gtr idea [COMMAND] [OPTIONS] [ARGS...]

COMMANDS:
    create, c [summary]        Create a new idea file (default: prompt for summary)
    list, l [OPTIONS]          List all ideas with optional filtering
    open, o [OPTIONS]          Interactive idea opener with optional filtering
    --help, -h                 Show this help message

OPTIONS:
    --mine                     Show only your ideas (for list/open commands)
    --todo                     Show only TODO ideas (for list command)
    --status=STATUS            Filter by status: TODO, IN_PROGRESS, DONE, BLOCKED (for list command)
    --filter=STRING            Search for ideas containing STRING in title or content (for list command)

EXAMPLES:
    # Create ideas
    gtr idea                           # Create idea (prompt for summary)
    gtr idea "New feature idea"        # Create idea with summary
    gtr idea create "Bug fix idea"     # Create idea with explicit command

    # List ideas
    gtr idea list                      # List all ideas
    gtr idea list --mine               # List only your ideas
    gtr idea list --todo               # List only TODO ideas
    gtr idea list --status=IN_PROGRESS # List ideas in progress
    gtr idea list --filter=bug         # Search for ideas containing "bug"

    # Open ideas
    gtr idea open                      # Interactive opener for all ideas
    gtr idea open --mine               # Interactive opener for your ideas only

FEATURES:
    • Ideas are stored in .gtr/ideas/ directory
    • Automatic metadata including author, timestamp, repo info
    • Cross-worktree idea discovery and management
    • Rich filtering and search capabilities
    • Interactive idea selection and opening

For more information, visit: https://medium.com/@dtunai/mastering-git-worktrees-with-claude-code-for-parallel-development-workflow-41dc91e645fe
EOF
}

gtr_idea_create() {
  local summary=""
  local use_less="false"
  
  # Parse arguments - first non-option argument is the summary
  for arg in "${_GTR_ARGS[@]}"; do
    case "$arg" in
      --less)
        use_less="true"
        ;;
      --*)
        # Skip other options
        ;;
      *)
        if [[ -z "$summary" ]]; then
          summary="$arg"
        fi
        ;;
    esac
  done
  
  # If no summary provided, prompt for it
  if [[ -z "$summary" ]]; then
    printf "Enter idea summary: "
    read -r summary
    if [[ -z "$summary" ]]; then
      echo "❌ No summary provided. Idea creation cancelled."
      return 1
    fi
  fi
  
  # Ensure ideas directory exists
  if ! _gtr_ensure_ideas_dir; then
    return 1
  fi
  
  # Get repository information
  local repo_info="$(_gtr_get_repo_info)"
  IFS='|' read -r repo_name repo_url current_branch latest_commit <<< "$repo_info"
  
  # Generate filename and file path
  local filename="$(_gtr_generate_idea_filename "$summary")"
  local ideas_dir="$(_gtr_get_ideas_dir)"
  local file_path="$ideas_dir/$filename"
  
  # Create idea file content
  local content="$(_gtr_create_idea_content "$summary" "$repo_name" "$repo_url" "$current_branch" "$latest_commit")"
  
  # Write idea file
  if echo "$content" > "$file_path"; then
    echo "✅ Created idea: $filename"
    echo "📁 Location: $file_path"
    
    # Open in editor or less
    if [[ "$use_less" == "true" ]]; then
      echo "🔧 Opening with less..."
      less "$file_path"
    else
      local editor="${_GTR_EDITOR:-cursor}"
      if command -v "$editor" >/dev/null 2>&1; then
        echo "🔧 Opening in $editor..."
        "$editor" "$file_path"
      else
        echo "💡 Open with: $editor \"$file_path\""
      fi
    fi
  else
    echo "❌ Failed to create idea file: $file_path"
    return 1
  fi
}

gtr_idea_list() {
  # Parse arguments for filtering
  local filter_args=()
  for arg in "${_GTR_ARGS[@]}"; do
    case "$arg" in
      --mine|--todo|--status=*|--filter=*)
        filter_args+=("$arg")
        ;;
    esac
  done
  
  # List ideas with filters
  _gtr_list_ideas "${filter_args[@]}"
}

gtr_idea_open() {
  local idea_file=""
  local use_less="false"
  
  # Parse arguments
  for arg in "${_GTR_ARGS[@]}"; do
    case "$arg" in
      --less)
        use_less="true"
        ;;
      --*)
        # Skip other options
        ;;
      *)
        if [[ -z "$idea_file" ]]; then
          idea_file="$arg"
        fi
        ;;
    esac
  done
  
  if [[ -z "$idea_file" ]]; then
    echo "Usage: gtr idea open <idea-file> [--less]"
    echo ""
    echo "OPTIONS:"
    echo "  --less               Open with less instead of editor"
    echo ""
    echo "EXAMPLES:"
    echo "  gtr idea open 20240101T120000Z_user_My-Idea.md"
    echo "  gtr idea open 20240101T120000Z_user_My-Idea.md --less"
    return 1
  fi
  
  local ideas_dir="$(_gtr_get_ideas_dir)"
  local full_path="$ideas_dir/$idea_file"
  
  if [[ ! -f "$full_path" ]]; then
    echo "❌ Idea file not found: $idea_file"
    echo "💡 Available ideas:"
    gtr_idea_list
    return 1
  fi
  
  if [[ "$use_less" == "true" ]]; then
    less "$full_path"
  else
    local editor="${_GTR_EDITOR:-cursor}"
    if command -v "$editor" >/dev/null 2>&1; then
      "$editor" "$full_path"
    else
      echo "❌ Editor not found: $editor"
      echo "💡 Open with: $editor \"$full_path\""
      return 1
    fi
  fi
}

gtr_idea() {
  local subcmd="${_GTR_ARGS[0]:-}"
  
  # Check for help flags first
  if [[ "$subcmd" == "--help" || "$subcmd" == "-h" ]]; then
    _gtr_idea_show_help
    return 0
  fi
  
  # Remove the subcommand from args
  if [[ ${#_GTR_ARGS[@]} -gt 0 ]]; then
    _GTR_ARGS=("${_GTR_ARGS[@]:1}")
  fi
  
  case "$subcmd" in
    c|create)
      gtr_idea_create
      ;;
    l|list)
      gtr_idea_list
      ;;
    o|open)
      gtr_idea_open
      ;;
    "")
      echo "Usage: gtr idea {create|list|open} [OPTIONS]"
      echo ""
      echo "COMMANDS:"
      echo "  create, c [summary]  Create a new idea file"
      echo "  list, l             List ideas with optional filters"
      echo "  open, o <file>      Open an idea file"
      echo ""
      echo "OPTIONS for list:"
      echo "  --mine              Show only your ideas"
      echo "  --todo              Show only TODO status ideas"
      echo "  --status=STATUS     Show only ideas with specific status"
      echo "  --filter=CONTENT    Filter by content (case-insensitive)"
      echo ""
      echo "OPTIONS for open:"
      echo "  --less              Open with less instead of editor"
      echo ""
      echo "EXAMPLES:"
      echo "  gtr idea create                    # Prompt for summary"
      echo "  gtr idea create 'New feature'      # Create with summary"
      echo "  gtr idea list                      # List all ideas"
      echo "  gtr idea list --mine               # List your ideas"
      echo "  gtr idea list --todo               # List TODO ideas"
      echo "  gtr idea list --status=IN_PROGRESS # List in-progress ideas"
      echo "  gtr idea list --filter=performance # Filter by content"
      echo "  gtr idea open idea.md              # Open idea file"
      echo "  gtr idea open idea.md --less       # Open with less"
      return 1
      ;;
    *)
      echo "Unknown idea sub-command: $subcmd"
      echo "Use 'gtr idea' to see available commands"
      return 1
      ;;
  esac
}

_gtr_check_hooks() {
  local main_worktree="$1"
  local worktree_path="$2"
  local -n missing_hooks_ref="$3"
  local -n different_hooks_ref="$4"
  
  local global_hooks_dir="$HOME/.gtr/hooks"
  local local_hooks_dir="$main_worktree/.gtr/hooks"
  local worktree_hooks_dir="$worktree_path/.gtr/hooks"
  
  # Determine which hooks directory to use as source
  local source_hooks_dir=""
  if [[ -d "$local_hooks_dir" ]]; then
    source_hooks_dir="$local_hooks_dir"
  elif [[ -d "$global_hooks_dir" ]]; then
    source_hooks_dir="$global_hooks_dir"
  fi
  
  if [[ -z "$source_hooks_dir" || ! -d "$source_hooks_dir" ]]; then
    return 0  # No hooks to check
  fi
  
  # Check each hook in the source directory
  for hook_file in "$source_hooks_dir"/*; do
    if [[ -f "$hook_file" && -x "$hook_file" ]]; then
      local hook_name="$(basename "$hook_file")"
      local worktree_hook="$worktree_hooks_dir/$hook_name"
      
      if [[ ! -f "$worktree_hook" ]]; then
        missing_hooks_ref+=("$hook_name")
      elif _gtr_files_different "$hook_file" "$worktree_hook"; then
        different_hooks_ref+=("$hook_name")
      fi
    fi
  done
}

_gtr_copy_hooks_to_worktree() {
  local main_worktree="$1"
  local worktree_path="$2"
  
  local global_hooks_dir="$HOME/.gtr/hooks"
  local local_hooks_dir="$main_worktree/.gtr/hooks"
  local worktree_hooks_dir="$worktree_path/.gtr/hooks"
  
  # Determine which hooks directory to use as source
  local source_hooks_dir=""
  if [[ -d "$local_hooks_dir" ]]; then
    source_hooks_dir="$local_hooks_dir"
  elif [[ -d "$global_hooks_dir" ]]; then
    source_hooks_dir="$global_hooks_dir"
  fi
  
  if [[ -z "$source_hooks_dir" || ! -d "$source_hooks_dir" ]]; then
    return 0  # No hooks to copy
  fi
  
  # Create hooks directory in worktree
  if [[ ! -d "$worktree_hooks_dir" ]]; then
    mkdir -p "$worktree_hooks_dir"
  fi
  
  # Copy each hook
  local copied_hooks=()
  for hook_file in "$source_hooks_dir"/*; do
    if [[ -f "$hook_file" && -x "$hook_file" ]]; then
      local hook_name="$(basename "$hook_file")"
      local worktree_hook="$worktree_hooks_dir/$hook_name"
      
      if cp "$hook_file" "$worktree_hook" 2>/dev/null; then
        chmod +x "$worktree_hook" 2>/dev/null
        copied_hooks+=("$hook_name")
      fi
    fi
  done
  
  if [[ ${#copied_hooks[@]} -gt 0 ]]; then
    echo "  📋 Copied hooks:"
    for hook in "${copied_hooks[@]}"; do
      echo "    - $hook"
    done
  fi
}

gtr_generate() {
  local subcommand=""

  # Parse subcommand
  if [[ ${#_GTR_ARGS[@]} -gt 0 ]]; then
    subcommand="${_GTR_ARGS[0]}"
  fi

  case "$subcommand" in
    hook)
      _gtr_generate_hook
      ;;
    *)
      echo "Usage: gtr generate <subcommand>"
      echo ""
      echo "SUBCOMMANDS:"
      echo "  hook                 Generate a new hook from template"
      echo ""
      echo "EXAMPLES:"
      echo "  gtr generate hook"
      echo "  gtr g hook"
      return 1
      ;;
  esac
}

_gtr_get_hook_description() {
  case "$1" in
    pre-create) echo "BEFORE creating a new worktree" ;;
    post-create) echo "AFTER successfully creating a new worktree" ;;
    pre-remove) echo "BEFORE removing a worktree" ;;
    post-remove) echo "AFTER successfully removing a worktree" ;;
    pre-prune) echo "BEFORE pruning merged worktrees" ;;
    post-prune) echo "AFTER successfully pruning merged worktrees" ;;
  esac
}

_gtr_get_hook_args() {
  case "$1" in
    pre-create|post-create)
      echo "#   \$1 - worktree name
#   \$2 - worktree path
#   \$3 - branch name
#   \$4 - base branch"
      ;;
    pre-remove|post-remove)
      echo "#   \$1 - worktree name
#   \$2 - worktree path
#   \$3 - branch name
#   \$4 - force flag (true/false)
#   \$5 - dry run flag (true/false)"
      ;;
    pre-prune|post-prune)
      echo "#   \$1 - base branch
#   \$2 - dry run flag (true/false)
#   \$3 - force flag (true/false)"
      ;;
  esac
}

_gtr_get_hook_vars() {
  case "$1" in
    pre-create|post-create)
      echo "WORKTREE_NAME=\"\$1\"
WORKTREE_PATH=\"\$2\"
BRANCH_NAME=\"\$3\"
BASE_BRANCH=\"\$4\""
      ;;
    pre-remove|post-remove)
      echo "WORKTREE_NAME=\"\$1\"
WORKTREE_PATH=\"\$2\"
BRANCH_NAME=\"\$3\"
FORCE=\"\$4\"
DRY_RUN=\"\$5\""
      ;;
    pre-prune|post-prune)
      echo "BASE_BRANCH=\"\$1\"
DRY_RUN=\"\$2\"
FORCE=\"\$3\""
      ;;
  esac
}

_gtr_get_hook_example_var() {
  case "$1" in
    pre-create|post-create|pre-remove|post-remove) echo "\$WORKTREE_NAME" ;;
    pre-prune|post-prune) echo "\$BASE_BRANCH" ;;
  esac
}

_gtr_generate_hook() {
  # Define valid hooks
  local valid_hooks=("pre-create" "post-create" "pre-remove" "post-remove" "pre-prune" "post-prune")

  # Ask for scope (global vs local)
  echo "📂 Select hook scope:"
  echo ""
  echo "  1) Local (current project only)"
  echo "  2) Global (all projects)"
  echo ""

  local scope_selection
  read -p "Enter number (1-2): " scope_selection

  # Validate scope selection
  if [[ ! "$scope_selection" =~ ^[1-2]$ ]]; then
    echo "❌ Invalid selection"
    return 1
  fi

  local hooks_dir
  local config_file

  if [[ "$scope_selection" == "1" ]]; then
    # Local scope - check if in git repository
    local main_worktree
    if ! main_worktree="$(_gtr_get_main_worktree)"; then
      echo "❌ Not in a git repository"
      return 1
    fi

    hooks_dir="$main_worktree/.gtr/hooks"
    config_file="$main_worktree/.gtr/config"

    # Check if local config exists
    if [[ ! -f "$config_file" ]]; then
      echo "❌ No local gtr configuration found at $config_file"
      echo "💡 Run 'gtr init' to create a local configuration"
      return 1
    fi
  else
    # Global scope
    hooks_dir="$HOME/.gtr/hooks"
    config_file="$HOME/.gtr/config"

    # Check if global config exists
    if [[ ! -f "$config_file" ]]; then
      echo "❌ No global gtr configuration found at $config_file"
      echo "💡 Run 'gtr init' to create a global configuration"
      return 1
    fi
  fi

  # Display hook selection menu
  echo ""
  echo "🔧 Select a hook to generate:"
  echo ""
  local i=1
  for hook in "${valid_hooks[@]}"; do
    echo "  $i) $hook - $(_gtr_get_hook_description "$hook")"
    ((i++))
  done
  echo ""

  # Get user selection
  local selection
  read -p "Enter number (1-${#valid_hooks[@]}): " selection

  # Validate selection
  if [[ ! "$selection" =~ ^[0-9]+$ ]] || [[ "$selection" -lt 1 ]] || [[ "$selection" -gt "${#valid_hooks[@]}" ]]; then
    echo "❌ Invalid selection"
    return 1
  fi

  local hook_name="${valid_hooks[$((selection - 1))]}"
  echo ""
  echo "📝 Generating hook: $hook_name"

  local hook_file="$hooks_dir/$hook_name"

  # Check if hook already exists
  if [[ -f "$hook_file" ]]; then
    echo "⚠️  Hook already exists: $hook_file"
    local overwrite
    read -p "Overwrite existing hook? (y/N): " overwrite

    if [[ "$overwrite" != "y" && "$overwrite" != "Y" ]]; then
      echo "❌ Aborted"
      return 0
    fi
  fi

  # Create hooks directory if it doesn't exist
  if [[ ! -d "$hooks_dir" ]]; then
    mkdir -p "$hooks_dir"
  fi

  # Read template
  local template_file

  # Get the directory containing the gtr script
  local script_dir
  if [[ -n "${BASH_SOURCE[0]}" ]]; then
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  fi

  # Check for template in repository (relative to lib/)
  if [[ -n "$script_dir" && -f "$script_dir/dot_gtr/hooks/template" ]]; then
    template_file="$script_dir/dot_gtr/hooks/template"
  # Check for template in repository (from main worktree)
  elif [[ -f "$main_worktree/dot_gtr/hooks/template" ]]; then
    template_file="$main_worktree/dot_gtr/hooks/template"
  # Check for installed template
  elif [[ -f "/usr/local/share/gtr/hooks/template" ]]; then
    template_file="/usr/local/share/gtr/hooks/template"
  # Check for template in home directory
  elif [[ -f "$HOME/.gtr/hooks/template" ]]; then
    template_file="$HOME/.gtr/hooks/template"
  else
    echo "❌ Hook template not found"
    return 1
  fi

  # Generate hook from template
  local template_content
  template_content=$(cat "$template_file")

  # Replace placeholders
  local hook_description="$(_gtr_get_hook_description "$hook_name")"
  local hook_args="$(_gtr_get_hook_args "$hook_name")"
  local hook_vars="$(_gtr_get_hook_vars "$hook_name")"
  local hook_example_var="$(_gtr_get_hook_example_var "$hook_name")"

  template_content="${template_content//HOOK_NAME/$hook_name}"
  template_content="${template_content//HOOK_DESCRIPTION/$hook_description}"
  template_content="${template_content//HOOK_ARGS/$hook_args}"
  template_content="${template_content//HOOK_VARS/$hook_vars}"
  template_content="${template_content//HOOK_EXAMPLE_VAR/$hook_example_var}"

  # Write hook file
  echo "$template_content" > "$hook_file"
  chmod +x "$hook_file"

  echo "✅ Hook created: $hook_file"
  echo "💡 Edit the hook to add your custom logic"

  return 0
}