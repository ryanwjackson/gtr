#!/bin/bash

# gtr-run-hook.sh - Run hook command
# Allows running hooks manually with proper variable setup

# Function to find hook in local and/or global directories
# Returns the directory containing the hook, or asks user to choose if both exist
_gtr_find_hook_for_run() {
  local main_worktree="$1"
  local hook_name="$2"
  local global_hooks_dir="$HOME/.gtr/hooks"
  local local_hooks_dir="$main_worktree/.gtr/hooks"
  
  local local_hook_exists=false
  local global_hook_exists=false
  local local_hook_file=""
  local global_hook_file=""
  
  # Check if local hook exists and is executable
  if [[ -f "$local_hooks_dir/$hook_name" && -x "$local_hooks_dir/$hook_name" ]]; then
    local_hook_exists=true
    local_hook_file="$local_hooks_dir/$hook_name"
  fi
  
  # Check if global hook exists and is executable
  if [[ -f "$global_hooks_dir/$hook_name" && -x "$global_hooks_dir/$hook_name" ]]; then
    global_hook_exists=true
    global_hook_file="$global_hooks_dir/$hook_name"
  fi
  
  # If neither exists, return error
  if [[ "$local_hook_exists" == "false" && "$global_hook_exists" == "false" ]]; then
    return 1
  fi
  
  # If only one exists, return that directory
  if [[ "$local_hook_exists" == "true" && "$global_hook_exists" == "false" ]]; then
    echo "$local_hooks_dir"
    return 0
  fi
  
  if [[ "$local_hook_exists" == "false" && "$global_hook_exists" == "true" ]]; then
    echo "$global_hooks_dir"
    return 0
  fi
  
  # Both exist - ask user to choose
  echo "🔍 Found hook '$hook_name' in both local and global directories:" >&2
  echo "" >&2
  echo "  1) Local:  $local_hook_file" >&2
  echo "  2) Global: $global_hook_file" >&2
  echo "" >&2
  
  local selection
  if [[ -t 0 ]]; then
    printf "Select which hook to run (1-2): " >&2
    read -r selection
  else
    # Non-interactive mode - prefer local
    selection="1"
    echo "Using local hook (non-interactive mode)" >&2
  fi
  
  # Validate selection
  if [[ "$selection" == "1" ]]; then
    echo "$local_hooks_dir"
    return 0
  elif [[ "$selection" == "2" ]]; then
    echo "$global_hooks_dir"
    return 0
  else
    echo "❌ Invalid selection" >&2
    return 1
  fi
}

gtr_run_hook() {
  # Check if first argument is "hook"
  if [[ "$1" == "hook" ]]; then
    shift
  fi
  
  local hook_name="$1"
  local base_branch="${_GTR_BASE_BRANCH:-}"
  local dry_run="${_GTR_DRY_RUN:-false}"
  local force="${_GTR_FORCE:-false}"
  
  # Check if hook name is provided
  if [[ -z "$hook_name" ]]; then
    echo "❌ Hook name required"
    echo "Usage: gtr run hook <hook-name> [--base=BRANCH]"
    echo ""
    echo "Available hooks:"
    local main_worktree
    if main_worktree="$(_gtr_get_main_worktree)"; then
      local global_hooks_dir="$HOME/.gtr/hooks"
      local local_hooks_dir="$main_worktree/.gtr/hooks"
      local hooks_found=false
      
      # Check local hooks
      if [[ -d "$local_hooks_dir" ]]; then
        echo "  Local hooks:"
        for hook in "$local_hooks_dir"/*; do
          if [[ -f "$hook" && -x "$hook" ]]; then
            echo "    - $(basename "$hook")"
            hooks_found=true
          fi
        done
      fi
      
      # Check global hooks
      if [[ -d "$global_hooks_dir" ]]; then
        echo "  Global hooks:"
        for hook in "$global_hooks_dir"/*; do
          if [[ -f "$hook" && -x "$hook" ]]; then
            echo "    - $(basename "$hook")"
            hooks_found=true
          fi
        done
      fi
      
      if [[ "$hooks_found" == "false" ]]; then
        echo "  No hooks found"
      fi
    else
      echo "  Not in a git repository"
    fi
    return 1
  fi
  
  # Check if we're in a git repository
  if ! git rev-parse --git-dir >/dev/null 2>&1; then
    echo "❌ Not in a git repository"
    return 1
  fi
  
  # Get main worktree
  local main_worktree
  if ! main_worktree="$(_gtr_get_main_worktree)"; then
    echo "❌ Could not determine main worktree"
    return 1
  fi
  
  # If no base branch provided, ask user
  if [[ -z "$base_branch" ]]; then
    echo "📋 Select base branch for hook execution:"
    echo ""
    
    # Get available branches
    local branches=()
    while IFS= read -r branch; do
      if [[ -n "$branch" ]]; then
        branches+=("$branch")
      fi
    done < <(git branch -r --format='%(refname:short)' | grep -v 'HEAD' | head -20)
    
    # Add local branches
    while IFS= read -r branch; do
      if [[ -n "$branch" && "$branch" != "*"* ]]; then
        # Remove the * prefix and leading space
        branch="${branch#* }"
        # Check if not already in the list
        local already_exists=false
        for existing_branch in "${branches[@]}"; do
          if [[ "$existing_branch" == "$branch" ]]; then
            already_exists=true
            break
          fi
        done
        if [[ "$already_exists" == "false" ]]; then
          branches+=("$branch")
        fi
      fi
    done < <(git branch --format='%(refname:short)')
    
    # Show branches with main as default
    local i=1
    local default_index=1
    for branch in "${branches[@]}"; do
      if [[ "$branch" == "main" ]]; then
        echo "  [$i] $branch (default)"
        default_index=$i
      else
        echo "  [$i] $branch"
      fi
      ((i++))
    done
    echo ""
    
    # Get user selection
    local selection
    if [[ -t 0 ]]; then
      printf "Enter number (1-${#branches[@]}) [default: $default_index]: "
      read -r selection
    else
      # Non-interactive mode, use main as default
      selection="$default_index"
      echo "Using default selection: $default_index (non-interactive mode)" >&2
    fi
    
    # Validate selection
    if [[ -z "$selection" ]]; then
      selection="$default_index"
    fi
    
    if [[ ! "$selection" =~ ^[0-9]+$ ]] || [[ "$selection" -lt 1 ]] || [[ "$selection" -gt ${#branches[@]} ]]; then
      echo "❌ Invalid selection"
      return 1
    fi
    
    base_branch="${branches[$((selection - 1))]}"
    echo "✅ Selected base branch: $base_branch"
    echo ""
  fi
  
  # Find hooks directory (local and/or global)
  local hooks_dir
  if ! hooks_dir="$(_gtr_find_hook_for_run "$main_worktree" "$hook_name")"; then
    echo "❌ Hook '$hook_name' not found in any hooks directory"
    echo "💡 Run 'gtr init' to create a hooks directory"
    echo "💡 Run 'gtr generate hook' to create hooks"
    return 1
  fi
  
  # Hook file path (already validated by _gtr_find_hook_for_run)
  local hook_file="$hooks_dir/$hook_name"
  
  # Set up hook variables based on hook type
  local worktree_name="manual-run"
  local worktree_path="$main_worktree"
  local branch_name="$base_branch"
  local editor="${_GTR_EDITOR:-cursor}"
  local gtr_action="run-hook"
  
  # Export variables for the hook
  export WORKTREE_NAME="$worktree_name"
  export WORKTREE_PATH="$worktree_path"
  export BRANCH_NAME="$branch_name"
  export BASE_BRANCH="$base_branch"
  export MAIN_WORKTREE="$main_worktree"
  export EDITOR="$editor"
  export GTR_ACTION="$gtr_action"
  export DRY_RUN="$dry_run"
  export FORCE="$force"
  
  # Show what we're about to run
  echo "🔧 Running hook: $hook_name"
  echo "   Base branch: $base_branch"
  echo "   Main worktree: $main_worktree"
  echo "   Hook file: $hook_file"
  echo ""
  
  # Execute the hook
  if "$hook_file" "$gtr_action" "$worktree_name" "$worktree_path" "$editor"; then
    echo "✅ Hook '$hook_name' completed successfully"
    return 0
  else
    local exit_code=$?
    echo "❌ Hook '$hook_name' failed with exit code $exit_code"
    return $exit_code
  fi
}
