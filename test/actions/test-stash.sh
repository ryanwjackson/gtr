#!/bin/bash

# test-stash.sh - Test stashing functionality with --uncommitted flag
# Tests the stashing behavior introduced for worktree creation

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source testing framework
source "$SCRIPT_DIR/../helpers/test-utils.sh"

# Test: Basic stashing with --uncommitted=true
test_stashing_with_flag() {
  # Create staged changes in the isolated environment
  create_test_uncommitted_changes "staged"

  # Verify we have uncommitted changes
  local status_before=$(git status --porcelain)
  assert_not_equals "$status_before" "" "Should have uncommitted changes before stashing"

  # Run gtr create with stashing (automatically uses isolated environment)
  local output=$(gtr create test-stash --uncommitted=true --no-open 2>&1)

  # Verify stash was created
  assert_contains "$output" "Stashed uncommitted changes" "Should show stashing message"
  assert_contains "$output" "Stashed for worktree: test-stash" "Should include worktree name in stash message"

  # Verify working tree is clean
  local status_after=$(git status --porcelain)
  assert_equals "$status_after" "" "Working tree should be clean after stashing"

  # Verify stash exists
  local stash_list=$(git stash list)
  assert_contains "$stash_list" "test-stash" "Stash should exist with worktree name"

  # Verify changes are available in the new worktree
  # Get the actual worktree path from git worktree list
  local worktree_path=$(git worktree list | grep "test-stash" | awk '{print $1}')
  if [[ -d "$worktree_path" ]]; then
    cd "$worktree_path"
    # Verify the staged file was copied to the worktree
    assert_file_exists "staged-file.txt" "Staged file should be copied to worktree"
    local staged_content=$(cat staged-file.txt 2>/dev/null || echo "")
    assert_equals "$staged_content" "new staged content" "Staged file content should be copied correctly"
    cd "$GTR_TEST_TEMP_DIR"
  else
    fail "Worktree directory should exist at $worktree_path"
  fi
}

# Test: Default behavior should use stashing
test_stashing_default_behavior() {
  # Create mixed changes
  create_test_uncommitted_changes "mixed"

  # Verify we have uncommitted changes
  local status_before=$(git status --porcelain)
  assert_not_equals "$status_before" "" "Should have uncommitted changes before stashing"

  # Run gtr create without specifying flags (should default to stashing)
  local output=$(gtr create test-default --no-open 2>&1)

  # Verify stash was created (should be default behavior)
  assert_contains "$output" "Stashed uncommitted changes" "Should use stashing by default"

  # Verify working tree is clean
  local status_after=$(git status --porcelain)
  assert_equals "$status_after" "" "Working tree should be clean after default stashing"
}

# Test: Stash message format includes worktree and branch names
test_stash_message_format() {
  # Create changes to stash
  create_test_uncommitted_changes "staged"

  # Run gtr create with specific worktree name
  gtr create my-feature-branch --uncommitted=true --no-open >/dev/null 2>&1

  # Check stash message format
  local stash_message=$(git stash list | head -1)
  assert_contains "$stash_message" "Stashed for worktree: my-feature-branch" "Should include worktree name"
  assert_contains "$stash_message" "my-feature-branch" "Should include branch name"
}

# Test: Mixed changes (staged, modified, untracked) are all stashed
test_stashing_mixed_changes() {
  # Create mixed changes
  create_test_uncommitted_changes "mixed"

  # Count changes before stashing
  local changes_before=$(git status --porcelain | wc -l)
  assert_not_equals "$changes_before" "0" "Should have multiple types of changes"

  # Run gtr create with stashing
  gtr create test-mixed --uncommitted=true --no-open >/dev/null 2>&1

  # Verify all changes are stashed
  local changes_after=$(git status --porcelain | wc -l)
  assert_equals "$changes_after" "0" "All changes should be stashed"

  # Verify stash contains the changes
  local stash_list=$(git stash list)
  assert_not_equals "$stash_list" "" "Stash should contain the mixed changes"

  # Verify all changes are copied to the new worktree
  # Get the actual worktree path from git worktree list
  local worktree_path=$(git worktree list | grep "test-mixed" | awk '{print $1}')
  if [[ -d "$worktree_path" ]]; then
    cd "$worktree_path"
    # Check that all types of files were copied
    assert_file_exists "staged-file.txt" "Staged file should be copied to worktree"
    assert_file_exists "untracked-file.txt" "Untracked file should be copied to worktree"
    # Check that modified file exists and has the updated content
    assert_file_exists "test-file.txt" "Modified file should be copied to worktree"
    local modified_content=$(cat test-file.txt 2>/dev/null || echo "")
    assert_contains "$modified_content" "modified content" "Modified file should contain updated content"
    cd "$GTR_TEST_TEMP_DIR"
  else
    fail "Worktree directory should exist at $worktree_path"
  fi
}

# Test: File copying fallback when --untracked=true explicitly set
test_file_copying_fallback() {
  # Create untracked files
  create_test_uncommitted_changes "untracked"

  # Run gtr create with explicit untracked flag and uncommitted disabled
  local output=$(gtr create test-legacy --untracked=true --uncommitted=false --no-open 2>&1)

  # Verify file copying was used instead of stashing
  assert_contains "$output" "Copying uncommitted changes" "Should use file copying with --untracked=true"
  assert_not_contains "$output" "Stashed uncommitted changes" "Should not use stashing when --uncommitted=false"
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