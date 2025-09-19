#!/bin/bash

# test-prune.sh - Tests for gtr prune functionality

# Source the testing framework
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test-helpers/test-utils.sh"
source "$SCRIPT_DIR/test-helpers/mock-git.sh"

# Source the module under test
source "$SCRIPT_DIR/../lib/gtr-core.sh"
source "$SCRIPT_DIR/../lib/gtr-git.sh"
source "$SCRIPT_DIR/../lib/gtr-ui.sh"

# Test the _gtr_ask_user function with timeout
test_gtr_ask_user_timeout() {
  # Test that the function doesn't hang when input is not available
  local result
  result=$(_gtr_ask_user "Test prompt: " "default" < /dev/null 2>/dev/null)
  # Remove the prompt from the result for comparison
  result="${result#Test prompt: }"
  assert_equals "default" "$result" "Should return default value when no input available"
}

# Test the _gtr_ask_user function with input
test_gtr_ask_user_with_input() {
  local result
  result=$(echo "yes" | _gtr_ask_user "Test prompt: " "default")
  # Remove the prompt from the result for comparison
  result="${result#Test prompt: }"
  assert_equals "yes" "$result" "Should return user input when provided"
}

# Test the _gtr_ask_user function with empty input
test_gtr_ask_user_empty_input() {
  local result
  result=$(echo "" | _gtr_ask_user "Test prompt: " "default")
  # Remove the prompt from the result for comparison
  result="${result#Test prompt: }"
  assert_equals "default" "$result" "Should return default value when input is empty"
}

# Test prune functionality with dry run
test_gtr_prune_dry_run() {
  setup_mock_git_repo
  enable_git_mocking
  
  # Mock git worktree list to return some worktrees
  mock_git_worktree_list() {
    echo "worktree /tmp/test1"
    echo "branch refs/heads/feature1"
    echo "worktree /tmp/test2"
    echo "branch refs/heads/feature2"
  }
  
  # Mock git branch --merged to return merged branches
  mock_git_branch_merged() {
    echo "  feature1"
    echo "  main"
  }
  
  # Test dry run
  local result
  result=$(GTR_BASE_DIR="/tmp" _GTR_DRY_RUN="true" _gtr_prune_worktrees 2>&1)
  assert_contains "$result" "DRY RUN" "Should show dry run output"
  
  disable_git_mocking
  cleanup_mock_git_repo
}

# Test prune functionality with squash merged branches (diverged but identical content)
test_gtr_prune_squash_merged() {
  setup_mock_git_repo
  enable_git_mocking

  # Mock git worktree list to return some worktrees
  mock_git_worktree_list() {
    echo "worktree /tmp/test-squashed"
    echo "branch refs/heads/feature-squashed"
  }

  # Mock git branch --merged to return NO merged branches (simulating diverged history)
  mock_git_branch_merged() {
    echo "  main"
  }

  # Mock git merge-base --is-ancestor to return false (not an ancestor)
  mock_git_merge_base_is_ancestor() {
    return 1  # Not an ancestor
  }

  # Mock git rev-list to return some commits (simulating diverged commits)
  mock_git_rev_list() {
    echo "commit1"
    echo "commit2"
  }

  # Mock git diff --quiet to return success (content is identical)
  mock_git_diff_quiet() {
    return 0  # Content is identical
  }

  # Test dry run with squash merged branch
  local result
  result=$(GTR_BASE_DIR="/tmp" _GTR_DRY_RUN="true" _gtr_prune_worktrees 2>&1)
  assert_contains "$result" "DRY RUN" "Should show dry run output"
  assert_contains "$result" "likely squash merged" "Should detect squash merge scenario"

  disable_git_mocking
  cleanup_mock_git_repo
}

# Test prune functionality with force
test_gtr_prune_force() {
  setup_mock_git_repo
  enable_git_mocking
  
  # Mock git worktree list to return some worktrees
  mock_git_worktree_list() {
    echo "worktree /tmp/test1"
    echo "branch refs/heads/feature1"
  }
  
  # Mock git branch --merged to return merged branches
  mock_git_branch_merged() {
    echo "  feature1"
    echo "  main"
  }
  
  # Test force mode
  local result
  result=$(GTR_BASE_DIR="/tmp" _GTR_FORCE="true" _gtr_prune_worktrees 2>&1)
  assert_contains "$result" "Removing" "Should show removal output in force mode"
  
  disable_git_mocking
  cleanup_mock_git_repo
}

# Run all tests
run_prune_tests() {
  init_test_suite "gtr-prune.sh"

  setup_test_env

  register_test "test_gtr_ask_user_timeout" "test_gtr_ask_user_timeout"
  register_test "test_gtr_ask_user_with_input" "test_gtr_ask_user_with_input"
  register_test "test_gtr_ask_user_empty_input" "test_gtr_ask_user_empty_input"
  register_test "test_gtr_prune_dry_run" "test_gtr_prune_dry_run"
  register_test "test_gtr_prune_squash_merged" "test_gtr_prune_squash_merged"
  register_test "test_gtr_prune_force" "test_gtr_prune_force"

  cleanup_test_env

  finish_test_suite
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  run_prune_tests
fi
