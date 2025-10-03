#!/bin/bash

# gtr-cd.sh - Change directory to worktree command implementation

gtr_cd() {
  local name=""
  if [[ ${#_GTR_ARGS[@]} -gt 0 ]]; then
    name="${_GTR_ARGS[0]}"
  fi

  if [[ -z "$name" ]]; then
    echo "Usage: gtr cd <name>" >&2
    return 1
  fi

  # First try the default worktree path
  local worktree_path="$(_gtr_get_worktree_path "$name")"

  if [[ -d "$worktree_path" ]]; then
    echo "$worktree_path"
    cd "$worktree_path" 2>/dev/null || return 0
    return 0
  fi

  # Search for worktree by name across all repos
  local matches=()
  while IFS= read -r match; do
    matches+=("$match")
  done < <(_gtr_find_worktree_by_name "$name")

  if [[ ${#matches[@]} -gt 0 ]]; then
    local selected_path
    selected_path=$(_gtr_select_from_matches "${matches[@]}") || return 1
    echo "$selected_path"
    cd "$selected_path" 2>/dev/null || return 0
    return 0
  fi

  # Check if it's a branch name in current repo
  if git rev-parse --verify "$name" >/dev/null 2>&1; then
    local main_worktree="$(_gtr_get_main_worktree)"
    echo "$main_worktree"
    cd "$main_worktree" 2>/dev/null || return 0
    return 0
  fi

  echo "No such worktree or branch: $name" >&2
  return 1
}
