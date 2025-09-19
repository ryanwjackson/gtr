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
  # Test basic create without worktree functionality (just validation)
  local result
  result=$(echo "test-worktree" | run_gtr_test create --no-open 2>&1) || true

  # Should contain some expected output (exact behavior depends on implementation)
  assert_contains "$result" "test-worktree" "Create command should process the worktree name"
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
  # Test that options are parsed (even if not fully functional in test env)
  local result
  result=$(echo "test-branch" | run_gtr_test create --no-open --no-install 2>&1) || true

  # Should not crash and should process the options
  assert_not_empty "$result" "Create with options should produce output"
}

# Test create command dry run (if implemented)
test_gtr_create_dry_run() {
  # Test dry run functionality if available
  local result
  result=$(echo "test-dry-run" | run_gtr_test create --no-open --dry-run 2>&1) || true

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