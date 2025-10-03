#!/bin/bash

# gtr-claude.sh - Run claude in worktree command implementation

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

  local dir=""

  # First try to find existing worktree
  local worktree_path="$(_gtr_get_worktree_path "$name")"

  if [[ -d "$worktree_path" ]]; then
    dir="$worktree_path"
  else
    # Search for worktree by name across all repos
    local matches=()
    while IFS= read -r match; do
      matches+=("$match")
    done < <(_gtr_find_worktree_by_name "$name")

    if [[ ${#matches[@]} -gt 0 ]]; then
      dir=$(_gtr_select_from_matches "${matches[@]}") || return 1
    else
      # If not found, try to create it
      dir=$(_gtr_find_or_create_worktree "$name") || return 1
    fi
  fi

  if [[ ${#claude_args[@]} -gt 0 ]]; then
    ( cd "$dir" && claude "${claude_args[@]}" )
  else
    ( cd "$dir" && claude )
  fi
}

