#!/bin/bash

# test-create.sh - Tests for gtr create command functionality

# Source the testing framework
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../helpers/test-utils.sh"

# Source the modules under test
source "$SCRIPT_DIR/../../lib/gtr-core.sh"
source "$SCRIPT_DIR/../../lib/gtr-ui.sh"
source "$SCRIPT_DIR/../../lib/gtr-config.sh"
source "$SCRIPT_DIR/../../lib/gtr-files.sh"
source "$SCRIPT_DIR/../../lib/gtr-git.sh"
source "$SCRIPT_DIR/../../lib/gtr-commands.sh"
source "$SCRIPT_DIR/../../lib/gtr-hooks.sh"

# Test create command basic functionality
test_gtr_create_basic() {
  # Test basic create functionality with dry-run (safe for test environment)
  local result
  local exit_code
  result=$(run_gtr_test create test-worktree --no-open --dry-run 2>&1)
  exit_code=$?

  # Command should execute successfully and show dry-run output
  assert_equals "0" "$exit_code" "Create command should execute without errors in dry-run"
  assert_contains "$result" "DRY RUN" "Dry run should indicate it's a simulation"
}

# Test create command validation
test_gtr_create_validation() {
  # Test empty name validation
  local result
  result=$(run_gtr_test create "" 2>&1) || true

  # Should handle empty input gracefully
  assert_not_empty "$result" "Create command should produce output for empty input"
}

# Test create command help
test_gtr_create_help() {
  local result
  result=$(run_gtr_test create --help 2>&1) || true

  assert_contains "$result" "create" "Help should contain 'create'"
  # Help output may vary, just check that we get some output
  assert_not_empty "$result" "Help should produce output"
}

# Test create command with options
test_gtr_create_with_options() {
  # Test that options are parsed with dry-run (safe for test environment)
  local result
  local exit_code
  result=$(run_gtr_test create test-branch --no-open --no-install --dry-run 2>&1)
  exit_code=$?

  # Should execute successfully with options in dry-run mode
  assert_equals "0" "$exit_code" "Create with options should execute successfully in dry-run"
  assert_contains "$result" "DRY RUN" "Dry run should indicate it's a simulation"
}

# Test create command dry run (if implemented)
test_gtr_create_dry_run() {
  # Test dry run functionality if available
  local result
  result=$(run_gtr_test create test-dry-run --no-open --dry-run 2>&1) || true

  # Should indicate what would be done without doing it
  assert_not_empty "$result" "Dry run should produce output"
}

# Test create worktree function validation
test_gtr_create_worktree_validation() {
  # Test the underlying create worktree function
  local result

  # Should handle invalid names gracefully
  result=$(_gtr_create_worktree "" 2>&1) || true
  assert_not_empty "$result" "Create worktree should handle empty name"

  # Test with special characters
  result=$(_gtr_create_worktree "invalid/name" 2>&1) || true
  assert_not_empty "$result" "Create worktree should handle invalid characters"
}

# Run all tests
run_create_tests() {
  init_test_suite "Create Command"

  register_test "test_gtr_create_basic" "test_gtr_create_basic"
  register_test "test_gtr_create_validation" "test_gtr_create_validation"
  register_test "test_gtr_create_help" "test_gtr_create_help"
  register_test "test_gtr_create_with_options" "test_gtr_create_with_options"
  register_test "test_gtr_create_dry_run" "test_gtr_create_dry_run"
  register_test "test_gtr_create_worktree_validation" "test_gtr_create_worktree_validation"

  finish_test_suite
}

# Run tests when script is executed directly
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  run_create_tests
fi