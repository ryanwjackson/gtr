#!/bin/bash

# gtr-doctor.sh - Check and fix worktree files command implementation

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

