#!/bin/bash

# gtr-init.sh - Initialize gtr configuration command implementation

gtr_init() {
  local init_doctor="${_GTR_INIT_DOCTOR:-false}"
  local init_fix="${_GTR_INIT_FIX:-false}"
  local current_dir="$(pwd)"
  local global_config_dir="$HOME/.gtr"
  local global_config_file="$global_config_dir/config"
  local local_config_dir="$current_dir/.gtr"
  local local_config_file="$local_config_dir/config"
  
  if [[ "$init_doctor" == "true" ]]; then
    # For doctor mode, check the config that would be used
    local config_file="$local_config_file"
    if [[ ! -f "$local_config_file" && -f "$global_config_file" ]]; then
      config_file="$global_config_file"
    fi
    _gtr_init_doctor "$current_dir" "$config_file" "$init_fix"
  else
    # Ask about global config first
    if [[ ! -f "$global_config_file" ]]; then
      echo "🔧 No global gtr configuration found at ~/.gtr/config"
      echo ""
      printf "Create global config? [Y/n] "
      read -r choice
      if [[ -z "$choice" ]]; then
        choice="Y"
      fi
      case "$choice" in
        [nN]|[nN][oO])
          echo "⏭️  Skipping global configuration"
          ;;
        *)
          _gtr_init_global_config "$global_config_dir" "$global_config_file"
          ;;
      esac
    else
      echo "📋 Global config already exists: $global_config_file"
      echo ""
      echo "What would you like to do with the global config?"
      echo "  [k]eep    - Keep existing global configuration"
      echo "  [u]pdate  - Update/recreate global configuration"
      echo "  [d]iff    - Show diff between current and default"
      echo ""

      printf "Choose [keep/update/diff]: "
      read -r choice
      if [[ -z "$choice" ]]; then
        choice="keep"
      fi
      case "$choice" in
        [uU]|update)
          _gtr_init_config_with_options "$global_config_dir" "$global_config_file" "global"
          ;;
        [dD]|diff)
          _gtr_show_config_diff "$global_config_file"
          ;;
        *)
          echo "✅ Keeping existing global configuration"
          ;;
      esac
    fi

    echo ""

    # Ask about local config
    if [[ ! -f "$local_config_file" ]]; then
      echo "🤔 Would you like to create a local .gtr/config for this repository?"
      echo "   This will override the global config (~/.gtr/config) for this repo only."
      echo ""

      printf "Create local config? [y/N] "
      read -r choice
      if [[ -z "$choice" ]]; then
        choice="N"
      fi
      case "$choice" in
        [yY]|[yY][eE][sS])
          _gtr_init_config "$current_dir" "$local_config_dir" "$local_config_file"
          ;;
        *)
          echo "✅ Using global configuration at $global_config_file"
          ;;
      esac
    else
      echo "📋 Local config already exists: $local_config_file"
      _gtr_init_config "$current_dir" "$local_config_dir" "$local_config_file"
    fi
  fi
}

