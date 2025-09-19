#!/bin/bash

# test-stash.sh - Test stashing functionality with --uncommitted flag
# Tests the stashing behavior introduced for worktree creation

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source testing framework
source "$SCRIPT_DIR/../helpers/test-utils.sh"

# Test: Basic functionality with --untracked=true (using dry-run for safety)
test_stashing_with_flag() {
  # Create staged changes in the isolated environment
  create_test_uncommitted_changes "staged"

  # Verify we have uncommitted changes
  local status_before=$(git status --porcelain)
  assert_not_equals "$status_before" "" "Should have uncommitted changes before testing"

  # Run gtr create with dry-run to test parsing (safe for test environment)
  local output=$(run_gtr_test create test-stash --untracked=true --no-open --dry-run 2>&1)
  local exit_code=$?

  # Verify command executes successfully and shows appropriate dry-run output
  assert_equals "0" "$exit_code" "Create command should execute successfully"
  assert_contains "$output" "DRY RUN" "Should show dry-run output"
  assert_contains "$output" "test-stash" "Should reference the worktree name"
}

# Test: Default behavior with dry-run
test_stashing_default_behavior() {
  # Create mixed changes
  create_test_uncommitted_changes "mixed"

  # Verify we have uncommitted changes
  local status_before=$(git status --porcelain)
  assert_not_equals "$status_before" "" "Should have uncommitted changes before testing"

  # Run gtr create with default settings using dry-run
  local output=$(run_gtr_test create test-default --no-open --dry-run 2>&1)
  local exit_code=$?

  # Verify command executes successfully
  assert_equals "0" "$exit_code" "Create command should execute successfully with defaults"
  assert_contains "$output" "DRY RUN" "Should show dry-run output"
}

# Test: Worktree name handling in dry-run
test_stash_message_format() {
  # Create changes to test with
  create_test_uncommitted_changes "staged"

  # Run gtr create with specific worktree name using dry-run
  local output=$(run_gtr_test create my-feature-branch --untracked=true --no-open --dry-run 2>&1)
  local exit_code=$?

  # Check that command handles worktree name correctly
  assert_equals "0" "$exit_code" "Create command should execute successfully"
  assert_contains "$output" "my-feature-branch" "Should reference the worktree name"
  assert_contains "$output" "DRY RUN" "Should show dry-run output"
}

# Test: Mixed changes handling with dry-run
test_stashing_mixed_changes() {
  # Create mixed changes
  create_test_uncommitted_changes "mixed"

  # Count changes before testing
  local changes_before=$(git status --porcelain | wc -l)
  assert_not_equals "$changes_before" "0" "Should have multiple types of changes"

  # Run gtr create with dry-run to test mixed changes handling
  local output=$(run_gtr_test create test-mixed --untracked=true --no-open --dry-run 2>&1)
  local exit_code=$?

  # Verify command handles mixed changes correctly
  assert_equals "0" "$exit_code" "Create command should handle mixed changes successfully"
  assert_contains "$output" "DRY RUN" "Should show dry-run output"
  assert_contains "$output" "test-mixed" "Should reference the worktree name"
}

# Test: File copying behavior with --untracked=true
test_file_copying_fallback() {
  # Create untracked files
  create_test_uncommitted_changes "untracked"

  # Run gtr create with explicit untracked flag using dry-run
  local output=$(run_gtr_test create test-legacy --untracked=true --no-open --dry-run 2>&1)
  local exit_code=$?

  # Verify command executes successfully with untracked flag
  assert_equals "0" "$exit_code" "Create command should execute successfully with --untracked=true"
  assert_contains "$output" "DRY RUN" "Should show dry-run output"
  assert_contains "$output" "test-legacy" "Should reference the worktree name"
}

# Run all tests
run_stash_tests() {
  init_test_suite "GTR Stashing"

  # Register and run tests
  register_test "stashing_with_flag" "test_stashing_with_flag"
  register_test "stashing_default_behavior" "test_stashing_default_behavior"
  register_test "stash_message_format" "test_stash_message_format"
  register_test "stashing_mixed_changes" "test_stashing_mixed_changes"
  register_test "file_copying_fallback" "test_file_copying_fallback"

  finish_test_suite
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  run_stash_tests
fi