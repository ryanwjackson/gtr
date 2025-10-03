#!/bin/bash

# gtr-hooks.sh - Hook execution and management
# Contains functions for executing hooks during worktree operations

_gtr_execute_hook() {
  local hook_name="$1"
  local hook_dir="$2"
  local hook_args=("${@:3}")
  local hook_file="$hook_dir/$hook_name"
  
  if [[ ! -f "$hook_file" ]]; then
    return 0  # Hook doesn't exist, skip silently
  fi
  
  if [[ ! -x "$hook_file" ]]; then
    # Check if it's a .sample file that needs to be enabled
    if [[ "$hook_file" == *.sample ]]; then
      echo "ℹ️  Hook $hook_name is a sample file, skipping (copy to enable)"
    else
      echo "⚠️  Hook $hook_name is not executable, skipping"
    fi
    return 0
  fi
  
  echo "🔧 Executing hook: $hook_name"
  
  # Execute the hook with the provided arguments
  if "$hook_file" "${hook_args[@]}"; then
    echo "✅ Hook $hook_name completed successfully"
    return 0
  else
    local exit_code=$?
    echo "❌ Hook $hook_name failed with exit code $exit_code"
    return $exit_code
  fi
}

_gtr_find_hooks_dir() {
  local main_worktree="$1"
  local global_hooks_dir="$HOME/.gtr/hooks"
  local local_hooks_dir="$main_worktree/.gtr/hooks"
  
  # Prefer local hooks over global hooks
  if [[ -d "$local_hooks_dir" ]]; then
    echo "$local_hooks_dir"
  elif [[ -d "$global_hooks_dir" ]]; then
    echo "$global_hooks_dir"
  else
    return 1
  fi
}

_gtr_execute_pre_create_hook() {
  local worktree_name="$1"
  local worktree_path="$2"
  local branch_name="$3"
  local base_branch="$4"
  local main_worktree="$5"
  
  local hooks_dir
  if ! hooks_dir="$(_gtr_find_hooks_dir "$main_worktree")"; then
    return 0  # No hooks directory found
  fi
  
  _gtr_execute_hook "pre-create" "$hooks_dir" "create" "$worktree_name" "$worktree_path" "$branch_name" "$base_branch"
}

_gtr_execute_post_create_hook() {
  local worktree_name="$1"
  local worktree_path="$2"
  local branch_name="$3"
  local base_branch="$4"
  local main_worktree="$5"
  
  local hooks_dir
  if ! hooks_dir="$(_gtr_find_hooks_dir "$main_worktree")"; then
    return 0  # No hooks directory found
  fi
  
  _gtr_execute_hook "post-create" "$hooks_dir" "create" "$worktree_name" "$worktree_path" "$branch_name" "$base_branch"
}

_gtr_execute_pre_remove_hook() {
  local worktree_name="$1"
  local worktree_path="$2"
  local branch_name="$3"
  local force="$4"
  local dry_run="$5"
  local main_worktree="$6"
  
  local hooks_dir
  if ! hooks_dir="$(_gtr_find_hooks_dir "$main_worktree")"; then
    return 0  # No hooks directory found
  fi
  
  _gtr_execute_hook "pre-remove" "$hooks_dir" "remove" "$worktree_name" "$worktree_path" "$branch_name" "$force" "$dry_run"
}

_gtr_execute_post_remove_hook() {
  local worktree_name="$1"
  local worktree_path="$2"
  local branch_name="$3"
  local force="$4"
  local dry_run="$5"
  local main_worktree="$6"
  
  local hooks_dir
  if ! hooks_dir="$(_gtr_find_hooks_dir "$main_worktree")"; then
    return 0  # No hooks directory found
  fi
  
  _gtr_execute_hook "post-remove" "$hooks_dir" "remove" "$worktree_name" "$worktree_path" "$branch_name" "$force" "$dry_run"
}

_gtr_execute_pre_prune_hook() {
  local base_branch="$1"
  local dry_run="$2"
  local force="$3"
  local main_worktree="$4"
  
  local hooks_dir
  if ! hooks_dir="$(_gtr_find_hooks_dir "$main_worktree")"; then
    return 0  # No hooks directory found
  fi
  
  _gtr_execute_hook "pre-prune" "$hooks_dir" "prune" "$base_branch" "$dry_run" "$force"
}

_gtr_execute_post_prune_hook() {
  local base_branch="$1"
  local dry_run="$2"
  local force="$3"
  local main_worktree="$4"
  
  local hooks_dir
  if ! hooks_dir="$(_gtr_find_hooks_dir "$main_worktree")"; then
    return 0  # No hooks directory found
  fi
  
  _gtr_execute_hook "post-prune" "$hooks_dir" "prune" "$base_branch" "$dry_run" "$force"
}

_gtr_execute_before_open_hook() {
  local worktree_name="$1"
  local worktree_path="$2"
  local editor="$3"
  local gtr_action="$4"
  local main_worktree="$5"
  
  local hooks_dir
  if ! hooks_dir="$(_gtr_find_hooks_dir "$main_worktree")"; then
    return 0  # No hooks directory found
  fi
  
  _gtr_execute_hook "before-open" "$hooks_dir" "$gtr_action" "$worktree_name" "$worktree_path" "$editor"
}

_gtr_execute_post_open_hook() {
  local worktree_name="$1"
  local worktree_path="$2"
  local editor="$3"
  local gtr_action="$4"
  local main_worktree="$5"
  
  local hooks_dir
  if ! hooks_dir="$(_gtr_find_hooks_dir "$main_worktree")"; then
    return 0  # No hooks directory found
  fi
  
  _gtr_execute_hook "post-open" "$hooks_dir" "$gtr_action" "$worktree_name" "$worktree_path" "$editor"
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
