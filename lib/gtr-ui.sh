#!/bin/bash

# gtr-ui.sh - User interaction functions
# Contains functions for user input and interaction

# Helper function for interactive user input
# Usage: _gtr_ask_user "prompt" "default_value"
# Returns: user input or default value if no interactive input available
_gtr_ask_user() {
  local prompt="$1"
  local default_value="${2:-}"

  printf "%s" "$prompt"

  if [[ -t 0 ]]; then
    # Terminal input available, read user input
    read -r reply
    if [[ -z "$reply" ]]; then
      # Empty input, use default
      echo "$default_value"
    else
      # Use user input
      echo "$reply"
    fi
  else
    # No interactive input available, return default
    echo "$default_value"
  fi
}