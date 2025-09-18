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
    # Terminal input available, read user input with timeout to prevent hanging
    if read -r -t 10 reply 2>/dev/null; then
      if [[ -z "$reply" ]]; then
        # Empty input, use default
        echo "$default_value"
      else
        # Use user input
        echo "$reply"
      fi
    else
      # Read timed out or failed, use default
      echo "$default_value"
    fi
  else
    # No interactive input available, but check if there's input to read
    if read -r -t 1 reply 2>/dev/null; then
      # There's input available, use it
      if [[ -z "$reply" ]]; then
        echo "$default_value"
      else
        echo "$reply"
      fi
    else
      # No input available, return default
      echo "$default_value"
    fi
  fi
}