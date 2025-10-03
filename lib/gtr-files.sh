#!/bin/bash

# gtr-files.sh - File operations and management
# Contains functions for copying, diffing, and managing files between repositories and worktrees

_gtr_copy_local_files() {
  local source_dir="$1"
  local target_dir="$2"
  local force="${3:-false}"
  local main_worktree="${4:-$source_dir}"
  local copied_files=()

  # Read configuration patterns
  local patterns=($(_gtr_read_config "$main_worktree"))

  if [[ -d "$source_dir" ]]; then
    for pattern in "${patterns[@]}"; do
      if [[ "$pattern" == */ ]]; then
        # Directory pattern
        local dir_name="${pattern%/}"
        if [[ -d "$source_dir/$dir_name" ]]; then
          if cp -r "$source_dir/$dir_name" "$target_dir/" 2>/dev/null; then
            copied_files+=("$dir_name/")
          fi
        fi
      else
        # File pattern - use find to search recursively
        while IFS= read -r -d '' file; do
          if [[ -f "$file" ]]; then
            local relative_path="${file#$source_dir/}"
            local target_path="$target_dir/$relative_path"
            local target_dir_path=$(dirname "$target_path")

            # Create target directory if it doesn't exist
            mkdir -p "$target_dir_path" 2>/dev/null

            # Check if target file exists and is different
            if [[ -f "$target_path" ]] && _gtr_files_different "$file" "$target_path"; then
              if _gtr_interactive_overwrite "$file" "$target_path" "$target_path" "$force"; then
                copied_files+=("$relative_path")
              fi
            else
              # File doesn't exist or is the same, safe to copy
              if cp "$file" "$target_path" 2>/dev/null; then
                copied_files+=("$relative_path")
              fi
            fi
          fi
        done < <(find "$source_dir" -name "$pattern" -type f -print0 2>/dev/null)
      fi
    done
  fi

  # Report what was copied
  if [[ ${#copied_files[@]} -gt 0 ]]; then
    echo "📋 Copied local files: ${copied_files[*]}"
  else
    echo "ℹ️  No local files found to copy"
  fi
}


_gtr_files_different() {
  local file1="$1"
  local file2="$2"

  if [[ ! -f "$file1" || ! -f "$file2" ]]; then
    return 1
  fi

  # Use diff to check if files are different
  if diff -q "$file1" "$file2" >/dev/null 2>&1; then
    return 1  # Files are the same
  else
    return 0  # Files are different
  fi
}

_gtr_show_diff() {
  local file1="$1"
  local file2="$2"

  echo "📋 Showing diff between main repo and worktree:"
  echo "  Main repo: $file1"
  echo "  Worktree:  $file2"
  echo ""

  if command -v diff >/dev/null 2>&1; then
    diff -u "$file1" "$file2" || true
  else
    echo "⚠️  diff command not available"
  fi
  echo ""
}

_gtr_merge_files() {
  local main_file="$1"
  local worktree_file="$2"
  local target_file="$3"

  echo "🔀 Merging files..."

  if command -v diff3 >/dev/null 2>&1; then
    # Use diff3 for three-way merge if available
    if diff3 -m "$main_file" "$worktree_file" "$worktree_file" > "$target_file" 2>/dev/null; then
      echo "✅ Successfully merged using diff3"
      return 0
    fi
  fi

  # Fallback: simple merge by appending worktree changes
  echo "📝 Using simple merge strategy..."
  cp "$main_file" "$target_file"
  echo "" >> "$target_file"
  echo "# Worktree-specific changes:" >> "$target_file"
  if command -v diff >/dev/null 2>&1; then
    diff -u "$main_file" "$worktree_file" >> "$target_file" 2>/dev/null || true
  fi

  echo "✅ Files merged (manual review recommended)"
  return 0
}

_gtr_interactive_overwrite() {
  local main_file="$1"
  local worktree_file="$2"
  local target_file="$3"
  local force="$4"

  if [[ "$force" == "true" ]]; then
    echo "🔄 Force overwriting: $(basename "$worktree_file")"
    cp "$main_file" "$target_file"
    return 0
  fi

  echo ""
  echo "⚠️  File already exists and is different: $(basename "$worktree_file")"
  echo "   Main repo: $main_file"
  echo "   Worktree:  $worktree_file"
  echo ""
  echo "What would you like to do?"
  echo "  [y]es  - Overwrite with main repo version"
  echo "  [n]o   - Skip this file"
  echo "  [d]iff - Show diff and ask again"
  echo "  [m]erge - Merge both files"
  echo ""

  while true; do
    local choice
    choice=$(_gtr_ask_user "Choose [y/n/d/m]: " "n")
    case "$choice" in
      [yY]|[yY][eE][sS])
        echo "🔄 Overwriting with main repo version..."
        cp "$main_file" "$target_file"
        return 0
        ;;
      [nN]|[nN][oO])
        echo "⏭️  Skipping file..."
        return 1
        ;;
      [dD]|[dD][iI][fF][fF])
        _gtr_show_diff "$main_file" "$worktree_file"
        # Ask again after showing diff
        ;;
      [mM]|[mM][eE][rR][gG][eE])
        _gtr_merge_files "$main_file" "$worktree_file" "$target_file"
        return 0
        ;;
      *)
        echo "Invalid choice. Please choose y, n, d, or m."
        ;;
    esac
  done
}