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
