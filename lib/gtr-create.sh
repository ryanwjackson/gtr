#!/bin/bash

# gtr-create.sh - Create worktree command implementation

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

  # Validate hooks before proceeding
  local main_worktree="$(_gtr_get_main_worktree)"
  if [[ -n "$main_worktree" ]]; then
    # Show which hooks will be executed
    _gtr_show_hooks_for_command "create" "$main_worktree"
    
    # Validate hooks (only if not dry run)
    if [[ "$dry_run" == "false" ]]; then
      if ! _gtr_validate_hooks_for_command "create" "$main_worktree"; then
        echo "❌ Hook validation failed. Please fix the issues above before proceeding."
        return 1
      fi
    fi
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

