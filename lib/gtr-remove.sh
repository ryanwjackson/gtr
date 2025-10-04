#!/bin/bash

# gtr-remove.sh - Remove worktree command implementation

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

  # Validate hooks before proceeding
  local main_worktree="$(_gtr_get_main_worktree)"
  if [[ -n "$main_worktree" ]]; then
    # Show which hooks will be executed
    _gtr_show_hooks_for_command "remove" "$main_worktree"
    
    # Validate hooks (only if not dry run)
    if [[ "$dry_run" == "false" ]]; then
      if ! _gtr_validate_hooks_for_command "remove" "$main_worktree"; then
        echo "❌ Hook validation failed. Please fix the issues above before proceeding."
        return 1
      fi
    fi
  fi

  for name in "${names[@]}"; do
    _gtr_remove_worktree "$name" "$force" "$dry_run"
  done

  if [[ "$dry_run" == "true" ]]; then
    echo "🔍 Dry run complete! Use without --dry-run to actually remove worktrees."
  fi
}

