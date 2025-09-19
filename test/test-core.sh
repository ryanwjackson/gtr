#!/bin/bash

# test-core.sh - Tests for gtr-core.sh module

# Source the testing framework
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test-helpers/test-utils.sh"
source "$SCRIPT_DIR/test-helpers/mock-git.sh"

# Source the module under test
source "$SCRIPT_DIR/../lib/gtr-core.sh"

# Test version function
test_gtr_print_version() {
  local output
  output=$(_gtr_print_version)
  assert_contains "$output" "gtr version" "Version output should contain 'gtr version'"
}

# Test base directory function
test_gtr_get_base_dir() {
  # Test with default
  unset GTR_BASE_DIR
  local result=$(_gtr_get_base_dir)
  assert_equals "$HOME/Documents/dev/worktrees" "$result" "Should return default base directory"

  # Test with custom environment variable
  export GTR_BASE_DIR="/custom/path"
  result=$(_gtr_get_base_dir)
  assert_equals "/custom/path" "$result" "Should return custom base directory"
}

# Test repository name function
test_gtr_get_repo_name() {
  setup_mock_git_repo
  enable_git_mocking

  local result=$(_gtr_get_repo_name)
  assert_equals "test-repo" "$result" "Should extract repo name from mock git remote"

  disable_git_mocking
  cleanup_mock_git_repo
}

# Test worktree branch name generation
test_gtr_get_worktree_branch_name() {
  export _GTR_USERNAME="testuser"
  setup_mock_git_repo
  enable_git_mocking

  local result=$(_gtr_get_worktree_branch_name "feature-branch")
  assert_equals "worktrees/test-repo/testuser/feature-branch" "$result" "Should generate correct branch name"

  disable_git_mocking
  cleanup_mock_git_repo
  unset _GTR_USERNAME
}

# Test main worktree detection
test_gtr_get_main_worktree() {
  setup_mock_git_repo
  enable_git_mocking

  local result=$(_gtr_get_main_worktree)
  assert_equals "$(pwd)" "$result" "Should return current directory as main worktree"

  disable_git_mocking
  cleanup_mock_git_repo
}

# Test initialization check
test_gtr_is_initialized() {
  setup_mock_git_repo

  # Test without config
  if _gtr_is_initialized; then
    assert_failure "true" "Should return false when no config exists"
  fi

  # Test with global config
  mkdir -p "$HOME/.gtr"
  touch "$HOME/.gtr/config"

  if ! _gtr_is_initialized; then
    assert_failure "false" "Should return true when global config exists"
  fi

  # Cleanup
  rm -rf "$HOME/.gtr"
  cleanup_mock_git_repo
}

# Test help function
test_gtr_show_help() {
  local output
  output=$(_gtr_show_help)
  assert_contains "$output" "USAGE:" "Help should contain usage information"
  assert_contains "$output" "COMMANDS:" "Help should contain commands section"
  assert_contains "$output" "create" "Help should mention create command"
  assert_contains "$output" "remove" "Help should mention remove command"
}

# Run all tests
run_core_tests() {
  init_test_suite "gtr-core.sh"

  setup_test_env

  register_test "test_gtr_print_version" "test_gtr_print_version"
  register_test "test_gtr_get_base_dir" "test_gtr_get_base_dir"
  register_test "test_gtr_get_repo_name" "test_gtr_get_repo_name"
  register_test "test_gtr_get_worktree_branch_name" "test_gtr_get_worktree_branch_name"
  register_test "test_gtr_get_main_worktree" "test_gtr_get_main_worktree"
  register_test "test_gtr_is_initialized" "test_gtr_is_initialized"
  register_test "test_gtr_show_help" "test_gtr_show_help"

  cleanup_test_env

  finish_test_suite
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  run_core_tests
fi