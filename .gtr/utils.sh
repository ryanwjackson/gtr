#!/bin/bash

# gtr utils.sh - Utility functions for gtr hooks
# This file provides helper functions that can be sourced by gtr hooks
# to perform common operations like copying files to worktrees.

# Global variables that will be set by the hook system
# These are populated when the hook is called
GTR_ACTION=""
GTR_WORKTREE_NAME=""
GTR_WORKTREE_PATH=""
GTR_BRANCH_NAME=""
GTR_BASE_BRANCH=""
GTR_MAIN_WORKTREE=""
GTR_EDITOR=""
GTR_NO_OPEN=""

# Initialize gtr context from hook arguments
# This function should be called at the beginning of hooks that use these utilities
gtr_init_context() {
  # Set global variables based on hook arguments
  # Different hooks receive different arguments, so we need to handle them appropriately
  
  # Common arguments for most hooks
  GTR_ACTION="${1:-}"
  GTR_WORKTREE_NAME="${2:-}"
  GTR_WORKTREE_PATH="${3:-}"
  
  # Additional arguments for specific hooks
  case "$GTR_ACTION" in
    "create")
      GTR_BRANCH_NAME="${4:-}"
      GTR_BASE_BRANCH="${5:-}"
      ;;
    "cd"|"open")
      GTR_EDITOR="${4:-}"
      ;;
  esac
  
  # Determine the main worktree directory
  GTR_MAIN_WORKTREE=$(git rev-parse --show-toplevel 2>/dev/null)
  if [[ "$(git rev-parse --git-dir 2>/dev/null)" == *"/.git/worktrees/"* ]]; then
    # We're in a worktree, get the main repository
    local main_git_dir=$(dirname "$(dirname "$(git rev-parse --git-dir)")")
    GTR_MAIN_WORKTREE=$(dirname "$main_git_dir")
  fi
  
  # Set environment variables if available
  GTR_EDITOR="${GTR_EDITOR:-$GTR_EDITOR}"
  GTR_NO_OPEN="${GTR_NO_OPEN:-$GTR_NO_OPEN}"
}

# Copy files from main worktree to current worktree
# Usage: copy_to_worktree "pattern" [force]
# Examples:
#   copy_to_worktree "apps/web/.env.local"
#   copy_to_worktree "**/.env.*local*"
#   copy_to_worktree "**/.env.*local*" true  # force overwrite
copy_to_worktree() {
  local pattern="$1"
  local force="${2:-false}"
  local copied_files=()
  
  # Ensure context is initialized
  if [[ -z "$GTR_MAIN_WORKTREE" || -z "$GTR_WORKTREE_PATH" ]]; then
    echo "❌ Error: gtr context not initialized. Call gtr_init_context first."
    return 1
  fi
  
  # Check if source and target directories exist
  if [[ ! -d "$GTR_MAIN_WORKTREE" ]]; then
    echo "❌ Error: Main worktree directory not found: $GTR_MAIN_WORKTREE"
    return 1
  fi
  
  if [[ ! -d "$GTR_WORKTREE_PATH" ]]; then
    echo "❌ Error: Target worktree directory not found: $GTR_WORKTREE_PATH"
    return 1
  fi
  
  # Handle directory patterns (ending with /)
  if [[ "$pattern" == */ ]]; then
    local dir_name="${pattern%/}"
    if [[ -d "$GTR_MAIN_WORKTREE/$dir_name" ]]; then
      if cp -r "$GTR_MAIN_WORKTREE/$dir_name" "$GTR_WORKTREE_PATH/" 2>/dev/null; then
        copied_files+=("$dir_name/")
      fi
    fi
  else
    # Handle file patterns with glob support
    if [[ "$pattern" == **/* ]]; then
      # Pattern contains directory separators, use -path
      local find_pattern="${pattern#**/}"
      while IFS= read -r -d '' file; do
        if [[ -f "$file" || -L "$file" ]]; then
          local relative_path="${file#$GTR_MAIN_WORKTREE/}"
          local target_path="$GTR_WORKTREE_PATH/$relative_path"
          local target_dir_path=$(dirname "$target_path")
          
          # Create target directory if it doesn't exist
          mkdir -p "$target_dir_path" 2>/dev/null
          
          # Check if target file exists and handle conflicts
          if [[ -f "$target_path" ]]; then
            if [[ "$force" == "true" ]]; then
              # Force overwrite
              if cp -P "$file" "$target_path" 2>/dev/null; then
                copied_files+=("$relative_path")
              fi
            else
              # Check if files are different
              if ! diff -q "$file" "$target_path" >/dev/null 2>&1; then
                echo "⚠️  File already exists and is different: $relative_path"
                echo "   Use force=true to overwrite or handle manually"
                continue
              fi
            fi
          else
            # File doesn't exist, safe to copy
            if cp -P "$file" "$target_path" 2>/dev/null; then
              copied_files+=("$relative_path")
            fi
          fi
        fi
      done < <(find "$GTR_MAIN_WORKTREE" -path "*/$find_pattern" \( -type f -o -type l \) -print0 2>/dev/null)
    else
      # Simple pattern, use -name
      while IFS= read -r -d '' file; do
        if [[ -f "$file" || -L "$file" ]]; then
          local relative_path="${file#$GTR_MAIN_WORKTREE/}"
          local target_path="$GTR_WORKTREE_PATH/$relative_path"
          local target_dir_path=$(dirname "$target_path")
          
          # Create target directory if it doesn't exist
          mkdir -p "$target_dir_path" 2>/dev/null
          
          # Check if target file exists and handle conflicts
          if [[ -f "$target_path" ]]; then
            if [[ "$force" == "true" ]]; then
              # Force overwrite
              if cp -P "$file" "$target_path" 2>/dev/null; then
                copied_files+=("$relative_path")
              fi
            else
              # Check if files are different
              if ! diff -q "$file" "$target_path" >/dev/null 2>&1; then
                echo "⚠️  File already exists and is different: $relative_path"
                echo "   Use force=true to overwrite or handle manually"
                continue
              fi
            fi
          else
            # File doesn't exist, safe to copy
            if cp -P "$file" "$target_path" 2>/dev/null; then
              copied_files+=("$relative_path")
            fi
          fi
        fi
      done < <(find "$GTR_MAIN_WORKTREE" -name "$pattern" \( -type f -o -type l \) -print0 2>/dev/null)
    fi
  fi
  
  # Report what was copied
  if [[ ${#copied_files[@]} -gt 0 ]]; then
    echo "📋 Copied files: ${copied_files[*]}"
  else
    echo "ℹ️  No files found matching pattern: $pattern"
  fi
}

# Copy multiple files/patterns to worktree
# Usage: copy_multiple_to_worktree "pattern1" "pattern2" ... [force]
# Example: copy_multiple_to_worktree "**/.env.*local*" ".claude/" "true"
copy_multiple_to_worktree() {
  local force="false"
  local patterns=()
  
  # Check if last argument is force flag
  if [[ "${@: -1}" == "true" ]]; then
    force="true"
    patterns=("${@:1:$#-1}")
  else
    patterns=("$@")
  fi
  
  for pattern in "${patterns[@]}"; do
    copy_to_worktree "$pattern" "$force"
  done
}

# Get current action context
# Returns the current gtr action (create, cd, open, etc.)
gtr_get_action() {
  echo "$GTR_ACTION"
}

# Get worktree name
gtr_get_worktree_name() {
  echo "$GTR_WORKTREE_NAME"
}

# Get worktree path
gtr_get_worktree_path() {
  echo "$GTR_WORKTREE_PATH"
}

# Get main worktree path
gtr_get_main_worktree() {
  echo "$GTR_MAIN_WORKTREE"
}

# Check if we're in a specific action
# Usage: gtr_is_action "create"
gtr_is_action() {
  local action="$1"
  [[ "$GTR_ACTION" == "$action" ]]
}

# Check if opening is disabled
gtr_is_no_open() {
  [[ "$GTR_NO_OPEN" == "true" ]]
}

# Log a message with gtr context
# Usage: gtr_log "message"
gtr_log() {
  local message="$1"
  echo "[gtr:$GTR_ACTION] $message"
}
