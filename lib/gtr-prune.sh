#!/bin/bash

# gtr-prune.sh - Prune merged worktrees command implementation

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

