#!/bin/bash

# gtr-config.sh - Configuration management functions
# Contains all functions related to reading, writing, and managing gtr configuration

_gtr_read_config() {
  local main_worktree="$1"
  local global_config_file="$HOME/.gtr/config"
  local local_config_file="$main_worktree/.gtr/config"
  local config_file=""
  local patterns=()

  # Check for global config first, then local config overrides it
  if [[ -f "$global_config_file" ]]; then
    config_file="$global_config_file"
  fi
  if [[ -f "$local_config_file" ]]; then
    config_file="$local_config_file"
  fi

  if [[ -n "$config_file" && -f "$config_file" ]]; then
    local in_files_section=false
    local line_count=0
    local max_lines=1000  # Prevent infinite loops
    local error_count=0
    local max_errors=10   # Stop after too many errors

    while IFS= read -r line && (( line_count++ < max_lines )) && (( error_count < max_errors )); do
      # Check for section headers - use string matching instead of regex to avoid escaping issues
      if [[ "$line" == "[files_to_copy]" ]]; then
        in_files_section=true
        continue
      elif [[ "$line" =~ ^\[ ]]; then
        in_files_section=false
        continue
      fi

      # Only process lines in the [files_to_copy] section
      if [[ "$in_files_section" == "true" ]]; then
        # Skip comments and empty lines - use safer pattern matching
        if [[ -n "$line" && ! "$line" =~ ^[[:space:]]*# ]]; then
          # Basic validation - skip lines that look like section headers or malformed content
          if [[ ! "$line" =~ ^\[ && ! "$line" =~ ^[[:space:]]*\[ ]]; then
            patterns+=("$line")
          else
            ((error_count++))
            echo "Warning: Skipping malformed line in config: $line" >&2
          fi
        fi
      fi
    done < "$config_file"

    # If we hit the line limit, something might be wrong
    if (( line_count >= max_lines )); then
      echo "Warning: Config file too large or malformed" >&2
    fi

    # If we hit too many errors, the config file might be corrupted
    if (( error_count >= max_errors )); then
      echo "Error: Too many malformed lines in config file. Consider recreating it." >&2
      echo "Run 'gtr init' to recreate the configuration file." >&2
      return 1
    fi
  fi

  # Fallback to default patterns if none found
  if [[ ${#patterns[@]} -eq 0 ]]; then
    patterns=(".env*local*" ".claude/" ".anthropic/" ".gtr/hooks/")
  fi

  echo "${patterns[@]}"
}

_gtr_read_config_setting() {
  local main_worktree="$1"
  local section="$2"
  local key="$3"
  local default="$4"
  local global_config_file="$HOME/.gtr/config"
  local local_config_file="$main_worktree/.gtr/config"
  local config_file=""

  # Check for global config first, then local config overrides it
  if [[ -f "$global_config_file" ]]; then
    config_file="$global_config_file"
  fi
  if [[ -f "$local_config_file" ]]; then
    config_file="$local_config_file"
  fi

  if [[ -z "$config_file" || ! -f "$config_file" ]]; then
    echo "$default"
    return
  fi

  # Validate inputs to prevent issues
  if [[ -z "$section" || -z "$key" ]]; then
    echo "$default"
    return
  fi

  local in_section=false
  local line_count=0
  local max_lines=1000  # Prevent infinite loops
  local error_count=0
  local max_errors=5     # Stop after too many errors

  while IFS= read -r line && (( line_count++ < max_lines )) && (( error_count < max_errors )); do
    # Check for section headers - use string matching instead of regex to avoid escaping issues
    if [[ "$line" == "[$section]" ]]; then
      in_section=true
      continue
    elif [[ "$line" =~ ^\[ ]]; then
      in_section=false
      continue
    fi

    # Only process lines in the target section
    if [[ "$in_section" == "true" ]]; then
      # Skip comments and empty lines - use safer pattern matching
      if [[ -n "$line" && ! "$line" =~ ^[[:space:]]*# ]]; then
        # Use string matching with prefix check instead of regex
        if [[ "$line" == "$key="* ]]; then
          echo "${line#*=}"
          return
        fi
      fi
    fi
  done < "$config_file" 2>/dev/null || {
    echo "Warning: Error reading config file, using default value" >&2
    echo "$default"
    return
  }

  # If we hit the line limit, something might be wrong
  if (( line_count >= max_lines )); then
    echo "Warning: Config file too large or malformed, using default value" >&2
  fi

  # If we hit too many errors, the config file might be corrupted
  if (( error_count >= max_errors )); then
    echo "Warning: Config file appears corrupted, using default value" >&2
  fi

  echo "$default"
}

_gtr_handle_malformed_config() {
  local main_worktree="$1"
  local config_file="$main_worktree/.gtr/config"

  echo "❌ The existing .gtr/config file appears to be malformed or corrupted."
  echo ""
  echo "This can happen when:"
  echo "  • The config file was manually edited with invalid syntax"
  echo "  • The config file was created with an older version of gtr"
  echo "  • The file was corrupted during editing"
  echo ""
  echo "Options:"
  echo "  1. Overwrite with a fresh default configuration"
  echo "  2. Show diff between current and default config"
  echo "  3. Try to merge/repair the existing config"
  echo "  4. Exit and fix manually"
  echo ""

  while true; do
    local choice
    choice=$(_gtr_ask_user "Choose an option (1-4): " "4")
    case $choice in
      1)
        echo "🔄 Creating fresh configuration..."
        _gtr_init_config "$main_worktree" "$(dirname "$config_file")" "$config_file"
        return 0
        ;;
      2)
        echo "📋 Showing diff between current and default config:"
        echo "--- Current config ---"
        cat "$config_file" 2>/dev/null || echo "(unable to read current config)"
        echo ""
        echo "--- Default config ---"
        _gtr_generate_default_config
        return 1
        ;;
      3)
        echo "🔧 Attempting to repair existing config..."
        _gtr_repair_config "$config_file"
        return $?
        ;;
      4)
        echo "ℹ️  Exiting. You can manually edit $config_file and try again."
        return 1
        ;;
      *)
        echo "Invalid option. Please choose 1-4."
        ;;
    esac
  done
}

_gtr_generate_default_config() {
  cat << 'EOF'
# gtr configuration file
# This file defines gtr behavior and which files should be copied to worktrees

[files_to_copy]
# File patterns to copy (glob patterns, one per line)
# Default patterns for local environment files
.env*local*
.env.*local*

# Claude settings directories
.claude/
.anthropic/

# gtr hooks directory
.gtr/hooks/

# Add more patterns as needed
# Example:
# config/local.json
# secrets/*.local

[settings]
# Default editor to open worktrees
editor=cursor



# Whether to open editor after creating worktree
auto_open=true

# Base directory for worktrees (relative to main repo or absolute path)
# worktree_base=../worktrees

[doctor]
# Whether to show detailed diff information
show_detailed_diffs=false

# Whether to auto-fix missing files without prompts
auto_fix=false
EOF
}

_gtr_repair_config() {
  local config_file="$1"
  local backup_file="${config_file}.backup.$(date +%s)"

  # Create backup
  cp "$config_file" "$backup_file" 2>/dev/null || {
    echo "❌ Unable to create backup of config file"
    return 1
  }

  echo "📋 Created backup: $backup_file"

  # Try to extract valid patterns from the existing config
  local patterns=()
  local in_files_section=false

  while IFS= read -r line; do
    if [[ "$line" == "[files_to_copy]" ]]; then
      in_files_section=true
      continue
    elif [[ "$line" == "["* ]]; then
      in_files_section=false
      continue
    fi

    if [[ "$in_files_section" == "true" ]]; then
      # Skip empty lines, comments, and section headers
      if [[ -n "$line" && "$line" != "#"* && "$line" != "["* ]]; then
        patterns+=("$line")
      fi
    fi
  done < "$config_file"

  # Generate new config with extracted patterns
  {
    echo "# gtr configuration file (repaired)"
    echo "# This file defines gtr behavior and which files should be copied to worktrees"
    echo ""
    echo "[files_to_copy]"
    echo "# File patterns to copy (glob patterns, one per line)"
    if [[ ${#patterns[@]} -gt 0 ]]; then
      echo "# Extracted from previous config:"
      for pattern in "${patterns[@]}"; do
        echo "$pattern"
      done
    else
      echo "# Default patterns for local environment files"
      echo ".env*local*"
      echo ".env.*local*"
      echo ""
      echo "# Claude settings directories"
      echo ".claude/"
      echo ".anthropic/"
      echo ""
      echo "# gtr hooks directory"
      echo ".gtr/hooks/"
    fi
    echo ""
    echo "[settings]"
    echo "editor=cursor"
    echo "auto_open=true"
    echo ""
    echo "[doctor]"
    echo "show_detailed_diffs=false"
    echo "auto_fix=false"
  } > "$config_file"

  echo "✅ Config file repaired successfully"
  echo "📋 Extracted ${#patterns[@]} patterns from the original config"
  return 0
}

_gtr_init_global_config() {
  local global_config_dir="$1"
  local global_config_file="$2"

  echo "🔧 Initializing global gtr configuration..."

  # Create ~/.gtr directory
  if [[ ! -d "$global_config_dir" ]]; then
    mkdir -p "$global_config_dir"
    echo "📁 Created ~/.gtr directory"
  fi

  # Create global config file
  _gtr_create_default_config "$global_config_file"
  echo "📝 Created global configuration file at $global_config_file"
  
  # Copy hooks to global config
  _gtr_copy_hooks_to_global "$global_config_dir"
  
  echo "✅ Global gtr configuration initialized!"
}

_gtr_init_config_with_options() {
  local config_dir="$1"
  local config_file="$2"
  local config_type="$3"  # "global" or "local"

  echo "🔧 Initializing $config_type gtr configuration..."

  # Create directory if it doesn't exist
  if [[ ! -d "$config_dir" ]]; then
    mkdir -p "$config_dir"
    echo "📁 Created $config_dir directory"
  fi

  # Handle existing config file
  if [[ -f "$config_file" ]]; then
    echo "⚠️  Configuration file already exists: $config_file"
    echo ""
    echo "What would you like to do?"
    echo "  [o]verwrite - Replace with default configuration"
    echo "  [d]iff      - Show diff between current and default"
    echo "  [m]erge     - Merge default settings into current config"
    echo "  [s]kip      - Keep existing configuration"
    echo ""

    while true; do
      printf "Choose [overwrite/diff/merge/skip]: "
      read -r choice
      if [[ -z "$choice" ]]; then
        choice="skip"
      fi

      case "$choice" in
        [oO]|overwrite)
          echo "🔄 Overwriting configuration file..."
          _gtr_create_default_config "$config_file"
          echo "✅ Configuration file overwritten"
          break
          ;;
        [dD]|diff)
          _gtr_show_config_diff "$config_file"
          # Ask again after showing diff
          ;;
        [mM]|merge)
          _gtr_merge_config "$config_file"
          echo "✅ Configuration file merged"
          break
          ;;
        [sS]|skip)
          echo "⏭️  Keeping existing configuration"
          break
          ;;
        *)
          echo "Invalid choice. Please choose overwrite, diff, merge, or skip."
          ;;
      esac
    done
  else
    _gtr_create_default_config "$config_file"
    echo "📝 Created default $config_type configuration file"
  fi

  # Copy hooks if this is a global config initialization
  if [[ "$config_type" == "global" ]]; then
    _gtr_copy_hooks_to_global "$config_dir"
  fi

  echo "✅ $config_type gtr configuration initialized successfully!"
  echo "   Config file: $config_file"
  echo "   Edit this file to customize gtr behavior"
}

_gtr_init_config() {
  local main_worktree="$1"
  local config_dir="$2"
  local config_file="$3"

  echo "🔧 Initializing gtr configuration..."

  # Create .gtr directory
  if [[ ! -d "$config_dir" ]]; then
    mkdir -p "$config_dir"
    echo "📁 Created .gtr directory"
  fi

  # Handle existing config file
  if [[ -f "$config_file" ]]; then
    echo "⚠️  Configuration file already exists: $config_file"
    echo ""
    echo "What would you like to do?"
    echo "  [o]verwrite - Replace with default configuration"
    echo "  [d]iff      - Show diff between current and default"
    echo "  [m]erge     - Merge default settings into current config"
    echo "  [s]kip      - Keep existing configuration"
    echo ""

    while true; do
      printf "Choose [overwrite/diff/merge/skip]: "
      read -r choice
      if [[ -z "$choice" ]]; then
        choice="skip"
      fi

      case "$choice" in
        [oO]|overwrite)
          echo "🔄 Overwriting configuration file..."
          _gtr_create_default_config "$config_file"
          echo "✅ Configuration file overwritten"
          break
          ;;
        [dD]|diff)
          _gtr_show_config_diff "$config_file"
          # Ask again after showing diff
          ;;
        [mM]|merge)
          _gtr_merge_config "$config_file"
          echo "✅ Configuration file merged"
          break
          ;;
        [sS]|skip)
          echo "⏭️  Keeping existing configuration"
          break
          ;;
        *)
          echo "Invalid choice. Please choose overwrite, diff, merge, or skip."
          ;;
      esac
    done
  else
    _gtr_create_default_config "$config_file"
    echo "📝 Created default configuration file"
  fi

  # Copy hooks if this is a local config initialization
  _gtr_copy_hooks_to_local "$main_worktree" "$config_dir"

  echo "✅ gtr configuration initialized successfully!"
  echo "   Config file: $config_file"
  echo "   Edit this file to customize gtr behavior"
}

_gtr_create_default_config() {
  local config_file="$1"
  cat > "$config_file" << 'EOF'
# gtr configuration file
# This file defines gtr behavior and which files should be copied to worktrees

[files_to_copy]
# File patterns to copy (glob patterns, one per line)
# Default patterns for local environment files
.env*local*
.env.*local*

# Claude settings directories
.claude/
.anthropic/

# gtr hooks directory
.gtr/hooks/

# Add more patterns as needed
# Example:
# config/local.json
# secrets/*.local

[settings]
# Default editor to open worktrees
editor=cursor



# Whether to open editor after creating worktree
auto_open=true

# Base directory for worktrees (relative to main repo or absolute path)
# worktree_base=../worktrees

[doctor]
# Whether to show detailed diff information
show_detailed_diffs=false

# Whether to auto-fix missing files without prompts
auto_fix=false
EOF
}

_gtr_show_config_diff() {
  local config_file="$1"
  local temp_file=$(mktemp)

  _gtr_create_default_config "$temp_file"

  echo "📋 Showing diff between current and default configuration:"
  echo "  Current: $config_file"
  echo "  Default: (temporary)"
  echo ""

  if command -v diff >/dev/null 2>&1; then
    diff -u "$config_file" "$temp_file" || true
  else
    echo "⚠️  diff command not available"
  fi

  rm -f "$temp_file"
  echo ""
}

_gtr_merge_config() {
  local config_file="$1"
  local temp_file=$(mktemp)
  local backup_file="${config_file}.backup.$(date +%s)"

  # Create backup
  cp "$config_file" "$backup_file"
  echo "📋 Created backup: $backup_file"

  # Create default config
  _gtr_create_default_config "$temp_file"

  # Merge using diff3 if available, otherwise simple append
  if command -v diff3 >/dev/null 2>&1; then
    if diff3 -m "$config_file" "$temp_file" "$config_file" > "${config_file}.merged" 2>/dev/null; then
      mv "${config_file}.merged" "$config_file"
      echo "✅ Successfully merged using diff3"
    else
      echo "⚠️  diff3 merge failed, using simple merge strategy"
      _gtr_simple_merge_config "$config_file" "$temp_file"
    fi
  else
    echo "📝 Using simple merge strategy"
    _gtr_simple_merge_config "$config_file" "$temp_file"
  fi

  rm -f "$temp_file"
}

_gtr_simple_merge_config() {
  local config_file="$1"
  local temp_file="$2"

  # Simple merge: append missing sections from default config
  echo "" >> "$config_file"
  echo "# Merged settings from default configuration" >> "$config_file"

  # Check if [files_to_copy] section exists
  if ! grep -q "^\[files_to_copy\]" "$config_file"; then
    echo "" >> "$config_file"
    echo "[files_to_copy]" >> "$config_file"
    sed -n '/^\[files_to_copy\]/,/^\[/p' "$temp_file" | grep -v "^\[" | grep -v "^$" >> "$config_file"
  fi

  # Check if [settings] section exists
  if ! grep -q "^\[settings\]" "$config_file"; then
    echo "" >> "$config_file"
    echo "[settings]" >> "$config_file"
    sed -n '/^\[settings\]/,/^\[/p' "$temp_file" | grep -v "^\[" | grep -v "^$" >> "$config_file"
  fi

  # Check if [doctor] section exists
  if ! grep -q "^\[doctor\]" "$config_file"; then
    echo "" >> "$config_file"
    echo "[doctor]" >> "$config_file"
    sed -n '/^\[doctor\]/,/^\[/p' "$temp_file" | grep -v "^\[" | grep -v "^$" >> "$config_file"
  fi

  echo "✅ Configuration merged (manual review recommended)"
}

_gtr_init_doctor() {
  local main_worktree="$1"
  local config_file="$2"
  local init_fix="$3"

  echo "🔍 Checking gtr configuration..."

  if [[ ! -f "$config_file" ]]; then
    echo "❌ No configuration file found at $config_file"
    echo "   Run 'gtr init' first to create the configuration"
    return 1
  fi

  # Test if the config file can be read without errors
  local test_patterns
  local error_output
  error_output=$(_gtr_read_config "$main_worktree" 2>&1)
  local exit_code=$?

  # Check if there were regex errors in the output
  if [[ "$error_output" == *"failed to compile regex"* ]] || [[ $exit_code -ne 0 ]]; then
    echo "❌ The configuration file appears to be malformed or corrupted."
    echo "🔧 Automatically repairing the configuration file..."

    if _gtr_repair_config "$config_file"; then
      echo "✅ Configuration file has been repaired. Continuing with doctor check..."
    else
      echo "❌ Unable to repair configuration file. Please resolve the issue manually."
      return 1
    fi
  fi

  # Read configuration patterns
  local config_patterns=($(_gtr_read_config "$main_worktree"))

  if [[ ${#config_patterns[@]} -eq 0 ]]; then
    echo "⚠️  No patterns found in configuration file"
    return 1
  fi

  echo "📋 Current configuration patterns:"
  for pattern in "${config_patterns[@]}"; do
    echo "  - $pattern"
  done
  echo ""

  # Find all local files that match patterns
  local matching_files=()
  local unmatched_files=()

  for pattern in "${config_patterns[@]}"; do
    while IFS= read -r -d '' file; do
      if [[ -f "$file" ]]; then
        local relative_path="${file#$main_worktree/}"
        matching_files+=("$relative_path")
      fi
    done < <(find "$main_worktree" -name "$pattern" -type f -print0 2>/dev/null)
  done

  # Find all local files that don't match any pattern (exclude common directories)
  while IFS= read -r -d '' file; do
    if [[ -f "$file" ]]; then
      local relative_path="${file#$main_worktree/}"
      # Skip common directories that shouldn't be copied
      if [[ "$relative_path" == *node_modules/* ||
            "$relative_path" == */.next/* ||
            "$relative_path" == .git/* ||
            "$relative_path" == dist/* ||
            "$relative_path" == build/* ||
            "$relative_path" == */.pnpm/* ]]; then
        continue
      fi

      local matched=false
      for pattern in "${config_patterns[@]}"; do
        if [[ "$relative_path" == $pattern || "$(basename "$relative_path")" == $pattern ]]; then
          matched=true
          break
        fi
      done
      if [[ "$matched" == "false" ]]; then
        unmatched_files+=("$relative_path")
      fi
    fi
  done < <(find "$main_worktree" -name "*local*" -type f -print0 2>/dev/null)

  echo "📊 Analysis results:"
  echo "  Files matching config: ${#matching_files[@]}"
  echo "  Local files not in config: ${#unmatched_files[@]}"
  echo ""

  if [[ ${#matching_files[@]} -gt 0 ]]; then
    echo "✅ Files that will be copied to worktrees:"
    for file in "${matching_files[@]}"; do
      echo "  - $file"
    done
    echo ""
  fi

  if [[ ${#unmatched_files[@]} -gt 0 ]]; then
    echo "⚠️  Local files that won't be copied (not in config):"
    for file in "${unmatched_files[@]}"; do
      echo "  - $file"
    done
    echo ""

    if [[ "$init_fix" == "true" ]]; then
      echo "🔧 Adding unmatched files to configuration..."
      for file in "${unmatched_files[@]}"; do
        echo "$file" >> "$config_file"
        echo "  Added: $file"
      done
      echo "✅ Configuration updated!"
    else
      echo "💡 To add these files to the configuration, run:"
      echo "   gtr init --doctor --fix"
    fi
  else
    echo "✅ All local files are covered by the configuration"
  fi
}

_gtr_copy_hooks_to_global() {
  local global_config_dir="$1"
  local hooks_dir="$global_config_dir/hooks"
  local source_hooks_dir=""
  
  # Find the source hooks directory (from the gtr installation)
  # Try to find it relative to the current script location
  local script_dir=""
  if [[ -n "${BASH_SOURCE[0]}" ]]; then
    script_dir="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
  else
    # Fallback: try to find it from the current working directory
    script_dir="$(pwd)"
  fi
  
  # Look for hooks in common locations
  # First try relative to script location
  for potential_dir in "$script_dir/../dot_gtr/hooks" "$script_dir/../../dot_gtr/hooks" "$(dirname "$script_dir")/dot_gtr/hooks"; do
    if [[ -d "$potential_dir" ]]; then
      source_hooks_dir="$potential_dir"
      break
    fi
  done
  
  # If not found, try to find gtr installation directory
  if [[ -z "$source_hooks_dir" ]]; then
    local gtr_script=""
    if command -v gtr >/dev/null 2>&1; then
      gtr_script="$(which gtr)"
      if [[ -L "$gtr_script" ]]; then
        gtr_script="$(readlink "$gtr_script")"
      fi
      local gtr_dir="$(dirname "$gtr_script")"
      for potential_dir in "$gtr_dir/../dot_gtr/hooks" "$gtr_dir/../../dot_gtr/hooks" "$(dirname "$gtr_dir")/dot_gtr/hooks"; do
        if [[ -d "$potential_dir" ]]; then
          source_hooks_dir="$potential_dir"
          break
        fi
      done
    fi
  fi
  
  # Final fallback: look in current directory and common development locations
  if [[ -z "$source_hooks_dir" ]]; then
    for potential_dir in "$(pwd)/dot_gtr/hooks" "/Users/ryanwjackson/Documents/dev/worktrees/init-hooks/dot_gtr/hooks"; do
      if [[ -d "$potential_dir" ]]; then
        source_hooks_dir="$potential_dir"
        break
      fi
    done
  fi
  
  if [[ -z "$source_hooks_dir" || ! -d "$source_hooks_dir" ]]; then
    echo "⚠️  Could not find source hooks directory, skipping hooks setup"
    return 0
  fi
  
  # Create hooks directory in global config
  if [[ ! -d "$hooks_dir" ]]; then
    mkdir -p "$hooks_dir"
    echo "📁 Created hooks directory: $hooks_dir"
  fi
  
  # Copy sample hooks
  local copied_hooks=()
  for hook_file in "$source_hooks_dir"/*.sample; do
    if [[ -f "$hook_file" ]]; then
      local hook_name="$(basename "$hook_file" .sample)"
      local target_file="$hooks_dir/$hook_name"
      
      if [[ ! -f "$target_file" ]]; then
        if cp "$hook_file" "$target_file" 2>/dev/null; then
          # Don't make executable by default - users must explicitly enable hooks
          copied_hooks+=("$hook_name")
        fi
      fi
    fi
  done
  
  if [[ ${#copied_hooks[@]} -gt 0 ]]; then
    echo "🔧 Copied sample hooks to global config:"
    for hook in "${copied_hooks[@]}"; do
      echo "  - $hook"
    done
    echo "   To enable a hook: cp $hooks_dir/$hook.sample $hooks_dir/$hook && chmod +x $hooks_dir/$hook"
    echo "   Edit hooks in: $hooks_dir"
  else
    echo "📋 Hooks already exist in global config"
  fi
}

_gtr_copy_hooks_to_local() {
  local main_worktree="$1"
  local config_dir="$2"
  local hooks_dir="$config_dir/hooks"
  local source_hooks_dir=""
  
  # Find the source hooks directory (from the gtr installation)
  # Try to find it relative to the current script location
  local script_dir=""
  if [[ -n "${BASH_SOURCE[0]}" ]]; then
    script_dir="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
  else
    # Fallback: try to find it from the current working directory
    script_dir="$(pwd)"
  fi
  
  # Look for hooks in common locations
  # First try relative to script location
  for potential_dir in "$script_dir/../dot_gtr/hooks" "$script_dir/../../dot_gtr/hooks" "$(dirname "$script_dir")/dot_gtr/hooks"; do
    if [[ -d "$potential_dir" ]]; then
      source_hooks_dir="$potential_dir"
      break
    fi
  done
  
  # If not found, try to find gtr installation directory
  if [[ -z "$source_hooks_dir" ]]; then
    local gtr_script=""
    if command -v gtr >/dev/null 2>&1; then
      gtr_script="$(which gtr)"
      if [[ -L "$gtr_script" ]]; then
        gtr_script="$(readlink "$gtr_script")"
      fi
      local gtr_dir="$(dirname "$gtr_script")"
      for potential_dir in "$gtr_dir/../dot_gtr/hooks" "$gtr_dir/../../dot_gtr/hooks" "$(dirname "$gtr_dir")/dot_gtr/hooks"; do
        if [[ -d "$potential_dir" ]]; then
          source_hooks_dir="$potential_dir"
          break
        fi
      done
    fi
  fi
  
  # Final fallback: look in current directory and common development locations
  if [[ -z "$source_hooks_dir" ]]; then
    for potential_dir in "$(pwd)/dot_gtr/hooks" "/Users/ryanwjackson/Documents/dev/worktrees/init-hooks/dot_gtr/hooks"; do
      if [[ -d "$potential_dir" ]]; then
        source_hooks_dir="$potential_dir"
        break
      fi
    done
  fi
  
  if [[ -z "$source_hooks_dir" || ! -d "$source_hooks_dir" ]]; then
    echo "⚠️  Could not find source hooks directory, skipping hooks setup"
    return 0
  fi
  
  # Create hooks directory in local config
  if [[ ! -d "$hooks_dir" ]]; then
    mkdir -p "$hooks_dir"
    echo "📁 Created hooks directory: $hooks_dir"
  fi
  
  # Copy sample hooks
  local copied_hooks=()
  for hook_file in "$source_hooks_dir"/*.sample; do
    if [[ -f "$hook_file" ]]; then
      local hook_name="$(basename "$hook_file" .sample)"
      local target_file="$hooks_dir/$hook_name"
      
      if [[ ! -f "$target_file" ]]; then
        if cp "$hook_file" "$target_file" 2>/dev/null; then
          # Don't make executable by default - users must explicitly enable hooks
          copied_hooks+=("$hook_name")
        fi
      fi
    fi
  done
  
  if [[ ${#copied_hooks[@]} -gt 0 ]]; then
    echo "🔧 Copied sample hooks to local config:"
    for hook in "${copied_hooks[@]}"; do
      echo "  - $hook"
    done
    echo "   To enable a hook: cp $hooks_dir/$hook.sample $hooks_dir/$hook && chmod +x $hooks_dir/$hook"
    echo "   Edit hooks in: $hooks_dir"
  else
    echo "📋 Hooks already exist in local config"
  fi
}