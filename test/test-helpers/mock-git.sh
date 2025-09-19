#!/bin/bash

# mock-git.sh - Mock git commands for testing
# Provides mock implementations of git commands for isolated testing

# Mock git worktree commands
mock_git() {
  local command="$1"
  shift

  case "$command" in
    "worktree")
      mock_git_worktree "$@"
      ;;
    "rev-parse")
      mock_git_rev_parse "$@"
      ;;
    "remote")
      mock_git_remote "$@"
      ;;
    "status")
      mock_git_status "$@"
      ;;
    "show-ref")
      mock_git_show_ref "$@"
      ;;
    "branch")
      mock_git_branch "$@"
      ;;
    "merge-base")
      mock_git_merge_base "$@"
      ;;
    "diff")
      mock_git_diff "$@"
      ;;
    *)
      echo "Mock git: Unhandled command '$command'"
      return 1
      ;;
  esac
}

mock_git_worktree() {
  local subcommand="$1"
  shift

  case "$subcommand" in
    "add")
      local path="$1"
      local options=()

      # Parse options
      while [[ $# -gt 0 ]]; do
        case "$1" in
          -b)
            local branch="$2"
            shift 2
            ;;
          *)
            local base_branch="$1"
            shift
            ;;
        esac
      done

      # Create the worktree directory
      mkdir -p "$path"
      cd "$path"
      git init --quiet
      git config user.name "Test User"
      git config user.email "test@example.com"

      # Create a mock .git/worktrees structure
      local worktree_name=$(basename "$path")
      mkdir -p ".git/worktrees/$worktree_name"
      echo "gitdir: .git/worktrees/$worktree_name" > ".git"

      echo "Mock: Created worktree at $path"
      return 0
      ;;

    "remove")
      local path="$1"
      if [[ -d "$path" ]]; then
        rm -rf "$path"
        echo "Mock: Removed worktree $path"
        return 0
      else
        echo "Mock: Worktree $path not found"
        return 1
      fi
      ;;

    "list")
      if [[ "$1" == "--porcelain" ]]; then
        # Porcelain format
        echo "worktree $(pwd)"
        echo "HEAD abc123"
        echo "branch refs/heads/main"
        echo ""

        # List any mock worktrees
        for dir in */; do
          if [[ -d "$dir" && -f "$dir/.git" ]]; then
            echo "worktree $(pwd)/$dir"
            echo "HEAD def456"
            echo "branch refs/heads/$(basename "$dir")"
            echo ""
          fi
        done
      else
        # Regular format
        echo "$(pwd) (bare)"
        for dir in */; do
          if [[ -d "$dir" && -f "$dir/.git" ]]; then
            echo "$(pwd)/$dir [$(basename "$dir")]"
          fi
        done
      fi
      ;;

    *)
      echo "Mock git worktree: Unhandled subcommand '$subcommand'"
      return 1
      ;;
  esac
}

mock_git_rev_parse() {
  local option="$1"

  case "$option" in
    "--show-toplevel")
      echo "$(pwd)"
      ;;
    "--git-dir")
      if [[ -f ".git" ]]; then
        # We're in a worktree
        echo ".git/worktrees/$(basename "$(pwd)")"
      else
        echo ".git"
      fi
      ;;
    "--abbrev-ref")
      if [[ "$2" == "HEAD" ]]; then
        echo "main"
      fi
      ;;
    *)
      echo "Mock git rev-parse: Unhandled option '$option'"
      return 1
      ;;
  esac
}

mock_git_remote() {
  local subcommand="$1"

  case "$subcommand" in
    "get-url")
      if [[ "$2" == "origin" ]]; then
        echo "https://github.com/test/test-repo.git"
      fi
      ;;
    *)
      echo "Mock git remote: Unhandled subcommand '$subcommand'"
      return 1
      ;;
  esac
}

mock_git_status() {
  local option="$1"

  case "$option" in
    "--porcelain")
      # Return some mock status for testing
      echo " M modified-file.txt"
      echo "?? new-file.txt"
      echo "A  staged-file.txt"
      ;;
    *)
      echo "On branch main"
      echo "Your branch is up to date with 'origin/main'."
      echo ""
      echo "Changes not staged for commit:"
      echo "  modified:   modified-file.txt"
      echo ""
      echo "Untracked files:"
      echo "  new-file.txt"
      ;;
  esac
}

mock_git_show_ref() {
  local options=()
  local ref=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --verify|--quiet)
        options+=("$1")
        shift
        ;;
      *)
        ref="$1"
        shift
        ;;
    esac
  done

  # For testing, assume main branch exists
  if [[ "$ref" == "refs/heads/main" ]]; then
    if [[ " ${options[*]} " =~ " --quiet " ]]; then
      return 0
    else
      echo "abc123 refs/heads/main"
    fi
  else
    # Other branches don't exist by default
    return 1
  fi
}

mock_git_branch() {
  local option="$1"

  case "$option" in
    "--merged")
      local base="$2"
      # For testing, assume no branches are merged
      ;;
    "-d")
      local branch="$2"
      echo "Mock: Deleted branch $branch"
      ;;
    *)
      echo "  main"
      echo "* current-branch"
      ;;
  esac
}

mock_git_merge_base() {
  local option="$1"

  case "$option" in
    "--is-ancestor")
      local branch1="$2"
      local branch2="$3"
      # For testing, assume branches are not ancestors
      return 1
      ;;
    *)
      echo "abc123"
      ;;
  esac
}

mock_git_diff() {
  local option="$1"

  case "$option" in
    "--quiet")
      # For testing, assume files are different
      return 1
      ;;
    "-q")
      # For testing, assume files are different
      return 1
      ;;
    "-u")
      local file1="$2"
      local file2="$3"
      echo "--- $file1"
      echo "+++ $file2"
      echo "@@ -1,1 +1,1 @@"
      echo "-old content"
      echo "+new content"
      ;;
    *)
      echo "Mock git diff: Unhandled option '$option'"
      return 1
      ;;
  esac
}

# Enable git mocking by aliasing git to our mock function
enable_git_mocking() {
  alias git='mock_git'
  export -f mock_git
  export -f mock_git_worktree
  export -f mock_git_rev_parse
  export -f mock_git_remote
  export -f mock_git_status
  export -f mock_git_show_ref
  export -f mock_git_branch
  export -f mock_git_merge_base
  export -f mock_git_diff
}

# Disable git mocking
disable_git_mocking() {
  unalias git 2>/dev/null || true
}

# Create a mock git repository structure for testing
setup_mock_git_repo() {
  local repo_dir="${1:-$(pwd)}"

  cd "$repo_dir"
  mkdir -p .git
  echo "ref: refs/heads/main" > .git/HEAD
  mkdir -p .git/refs/heads
  echo "abc123" > .git/refs/heads/main

  # Create some mock files
  echo "# Test Repository" > README.md
  echo "test content" > .env.local
  mkdir -p .claude
  echo "{\"model\": \"sonnet\"}" > .claude/config.json
}

# Cleanup mock git repository
cleanup_mock_git_repo() {
  local repo_dir="${1:-$(pwd)}"
  rm -rf "$repo_dir/.git" 2>/dev/null || true
}