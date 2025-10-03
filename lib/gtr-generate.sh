#!/bin/bash

# gtr-generate.sh - Generate hooks and other resources command implementation

gtr_generate() {
  local subcommand=""

  # Parse subcommand
  if [[ ${#_GTR_ARGS[@]} -gt 0 ]]; then
    subcommand="${_GTR_ARGS[0]}"
  fi

  case "$subcommand" in
    hook)
      _gtr_generate_hook
      ;;
    *)
      echo "Usage: gtr generate <subcommand>"
      echo ""
      echo "SUBCOMMANDS:"
      echo "  hook                 Generate a new hook from template"
      echo ""
      echo "EXAMPLES:"
      echo "  gtr generate hook"
      echo "  gtr g hook"
      return 1
      ;;
  esac
}

_gtr_get_hook_description() {
  case "$1" in
    pre-create) echo "BEFORE creating a new worktree" ;;
    post-create) echo "AFTER successfully creating a new worktree" ;;
    pre-remove) echo "BEFORE removing a worktree" ;;
    post-remove) echo "AFTER successfully removing a worktree" ;;
    pre-prune) echo "BEFORE pruning merged worktrees" ;;
    post-prune) echo "AFTER successfully pruning merged worktrees" ;;
  esac
}

_gtr_get_hook_args() {
  case "$1" in
    pre-create|post-create)
      echo "#   \$1 - worktree name
#   \$2 - worktree path
#   \$3 - branch name
#   \$4 - base branch"
      ;;
    pre-remove|post-remove)
      echo "#   \$1 - worktree name
#   \$2 - worktree path
#   \$3 - branch name
#   \$4 - force flag (true/false)
#   \$5 - dry run flag (true/false)"
      ;;
    pre-prune|post-prune)
      echo "#   \$1 - base branch
#   \$2 - dry run flag (true/false)
#   \$3 - force flag (true/false)"
      ;;
  esac
}

_gtr_get_hook_vars() {
  case "$1" in
    pre-create|post-create)
      echo "WORKTREE_NAME=\"\$1\"
WORKTREE_PATH=\"\$2\"
BRANCH_NAME=\"\$3\"
BASE_BRANCH=\"\$4\""
      ;;
    pre-remove|post-remove)
      echo "WORKTREE_NAME=\"\$1\"
WORKTREE_PATH=\"\$2\"
BRANCH_NAME=\"\$3\"
FORCE=\"\$4\"
DRY_RUN=\"\$5\""
      ;;
    pre-prune|post-prune)
      echo "BASE_BRANCH=\"\$1\"
DRY_RUN=\"\$2\"
FORCE=\"\$3\""
      ;;
  esac
}

_gtr_get_hook_example_var() {
  case "$1" in
    pre-create|post-create|pre-remove|post-remove) echo "\$WORKTREE_NAME" ;;
    pre-prune|post-prune) echo "\$BASE_BRANCH" ;;
  esac
}

_gtr_generate_hook() {
  # Define valid hooks
  local valid_hooks=("pre-create" "post-create" "pre-remove" "post-remove" "pre-prune" "post-prune")

  # Ask for scope (global vs local)
  echo "📂 Select hook scope:"
  echo ""
  echo "  1) Local (current project only)"
  echo "  2) Global (all projects)"
  echo ""

  local scope_selection
  read -p "Enter number (1-2): " scope_selection

  # Validate scope selection
  if [[ ! "$scope_selection" =~ ^[1-2]$ ]]; then
    echo "❌ Invalid selection"
    return 1
  fi

  local hooks_dir
  local config_file

  if [[ "$scope_selection" == "1" ]]; then
    # Local scope - check if in git repository
    local main_worktree
    if ! main_worktree="$(_gtr_get_main_worktree)"; then
      echo "❌ Not in a git repository"
      return 1
    fi

    hooks_dir="$main_worktree/.gtr/hooks"
    config_file="$main_worktree/.gtr/config"

    # Check if local config exists
    if [[ ! -f "$config_file" ]]; then
      echo "❌ No local gtr configuration found at $config_file"
      echo "💡 Run 'gtr init' to create a local configuration"
      return 1
    fi
  else
    # Global scope
    hooks_dir="$HOME/.gtr/hooks"
    config_file="$HOME/.gtr/config"

    # Check if global config exists
    if [[ ! -f "$config_file" ]]; then
      echo "❌ No global gtr configuration found at $config_file"
      echo "💡 Run 'gtr init' to create a global configuration"
      return 1
    fi
  fi

  # Display hook selection menu
  echo ""
  echo "🔧 Select a hook to generate:"
  echo ""
  local i=1
  for hook in "${valid_hooks[@]}"; do
    echo "  $i) $hook - $(_gtr_get_hook_description "$hook")"
    ((i++))
  done
  echo ""

  # Get user selection
  local selection
  read -p "Enter number (1-${#valid_hooks[@]}): " selection

  # Validate selection
  if [[ ! "$selection" =~ ^[0-9]+$ ]] || [[ "$selection" -lt 1 ]] || [[ "$selection" -gt "${#valid_hooks[@]}" ]]; then
    echo "❌ Invalid selection"
    return 1
  fi

  local hook_name="${valid_hooks[$((selection - 1))]}"
  echo ""
  echo "📝 Generating hook: $hook_name"

  local hook_file="$hooks_dir/$hook_name"

  # Check if hook already exists
  if [[ -f "$hook_file" ]]; then
    echo "⚠️  Hook already exists: $hook_file"
    local overwrite
    read -p "Overwrite existing hook? (y/N): " overwrite

    if [[ "$overwrite" != "y" && "$overwrite" != "Y" ]]; then
      echo "❌ Aborted"
      return 0
    fi
  fi

  # Create hooks directory if it doesn't exist
  if [[ ! -d "$hooks_dir" ]]; then
    mkdir -p "$hooks_dir"
  fi

  # Read template
  local template_file

  # Get the directory containing the gtr script
  local script_dir
  if [[ -n "${BASH_SOURCE[0]}" ]]; then
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  fi

  # Check for template in repository (relative to lib/)
  if [[ -n "$script_dir" && -f "$script_dir/dot_gtr/hooks/template" ]]; then
    template_file="$script_dir/dot_gtr/hooks/template"
  # Check for template in repository (from main worktree)
  elif [[ -f "$main_worktree/dot_gtr/hooks/template" ]]; then
    template_file="$main_worktree/dot_gtr/hooks/template"
  # Check for installed template
  elif [[ -f "/usr/local/share/gtr/hooks/template" ]]; then
    template_file="/usr/local/share/gtr/hooks/template"
  # Check for template in home directory
  elif [[ -f "$HOME/.gtr/hooks/template" ]]; then
    template_file="$HOME/.gtr/hooks/template"
  else
    echo "❌ Hook template not found"
    return 1
  fi

  # Generate hook from template
  local template_content
  template_content=$(cat "$template_file")

  # Replace placeholders
  local hook_description="$(_gtr_get_hook_description "$hook_name")"
  local hook_args="$(_gtr_get_hook_args "$hook_name")"
  local hook_vars="$(_gtr_get_hook_vars "$hook_name")"
  local hook_example_var="$(_gtr_get_hook_example_var "$hook_name")"

  template_content="${template_content//HOOK_NAME/$hook_name}"
  template_content="${template_content//HOOK_DESCRIPTION/$hook_description}"
  template_content="${template_content//HOOK_ARGS/$hook_args}"
  template_content="${template_content//HOOK_VARS/$hook_vars}"
  template_content="${template_content//HOOK_EXAMPLE_VAR/$hook_example_var}"

  # Write hook file
  echo "$template_content" > "$hook_file"
  chmod +x "$hook_file"

  echo "✅ Hook created: $hook_file"
  echo "💡 Edit the hook to add your custom logic"

  return 0
}
