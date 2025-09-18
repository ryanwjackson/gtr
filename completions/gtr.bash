# Bash completion for gtr

_gtr_base_dir() {
  if [[ -n "$GTR_BASE_DIR" ]]; then
    echo "$GTR_BASE_DIR"
  else
    echo "$HOME/Documents/dev/worktrees"
  fi
}

_gtr_list_worktrees() {
  local base
  base="$(_gtr_base_dir)"
  if [[ -d "$base" ]]; then
    command ls -1 "$base" 2>/dev/null
  fi
}

_gtr_subcommands() {
  echo "create c remove rm cd list ls l idea i claude cursor prune doctor init --help -h"
}

_gtr_global_opts() {
  echo "--prefix --username --editor --no-open --no-install --base --uncommitted"
}

_gtr_remove_opts() {
  echo "--force --dry-run"
}

_gtr_prune_opts() {
  echo "--base --dry-run --force"
}

_gtr_doctor_opts() {
  echo "--fix --force"
}

_gtr_init_opts() {
  echo "--doctor --fix"
}

_gtr_idea_subcommands() {
  echo "create c list l"
}

_gtr_idea_list_opts() {
  echo "--mine --todo --status --filter"
}

_gtr_completion() {
  local cur prev words cword
  COMPREPLY=()
  _get_comp_words_by_ref -n = cur prev words cword 2>/dev/null || {
    # Fallback if _get_comp_words_by_ref is unavailable
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
  }

  local subcmd
  subcmd="${COMP_WORDS[1]}"

  # Complete subcommand at position 1
  if [[ $COMP_CWORD -eq 1 ]]; then
    COMPREPLY=( $(compgen -W "$(_gtr_subcommands)" -- "$cur") )
    return 0
  fi

  # If completing an option (starts with -), include global and command-specific options
  if [[ "$cur" == -* ]]; then
    local opts
    opts="$(_gtr_global_opts)"
    case "$subcmd" in
      rm|remove) opts+=" $(_gtr_remove_opts)" ;;
      prune)     opts+=" $(_gtr_prune_opts)" ;;
      doctor)    opts+=" $(_gtr_doctor_opts)" ;;
      init)      opts+=" $(_gtr_init_opts)" ;;
      idea|i)    opts+=" $(_gtr_idea_list_opts)" ;;
    esac
    COMPREPLY=( $(compgen -W "$opts" -- "$cur") )
    return 0
  fi

  # Idea subcommand completion
  if [[ "$subcmd" == "idea" || "$subcmd" == "i" ]]; then
    local idea_subcmd="${COMP_WORDS[2]}"
    if [[ $COMP_CWORD -eq 2 ]]; then
      COMPREPLY=( $(compgen -W "$(_gtr_idea_subcommands)" -- "$cur") )
      return 0
    elif [[ "$idea_subcmd" == "list" || "$idea_subcmd" == "l" ]]; then
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "$(_gtr_idea_list_opts)" -- "$cur") )
        return 0
      fi
    fi
    return 0
  fi

  # Name completion for commands that take worktree names
  case "$subcmd" in
    c|create|rm|remove|cd|claude|cursor|doctor)
      COMPREPLY=( $(compgen -W "$(_gtr_list_worktrees)" -- "$cur") )
      return 0
      ;;
  esac

  # Default to filenames
  COMPREPLY=( $(compgen -f -- "$cur") )
}

complete -F _gtr_completion gtr


