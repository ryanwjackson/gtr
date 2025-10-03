#!/bin/bash

# test-utils.sh - Test the gtr utils.sh functionality

# Source the test utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers/test-utils.sh"

# Source the utils we're testing
source "$SCRIPT_DIR/../dot_gtr/utils.sh"

test_utils_init_context() {
  echo "Testing gtr_init_context..."
  
  # Test basic context initialization
  gtr_init_context "create" "test-worktree" "/tmp/test-path" "test-branch" "main"
  
  if [[ "$GTR_ACTION" != "create" ]]; then
    echo "❌ GTR_ACTION not set correctly: $GTR_ACTION"
    return 1
  fi
  
  if [[ "$GTR_WORKTREE_NAME" != "test-worktree" ]]; then
    echo "❌ GTR_WORKTREE_NAME not set correctly: $GTR_WORKTREE_NAME"
    return 1
  fi
  
  if [[ "$GTR_WORKTREE_PATH" != "/tmp/test-path" ]]; then
    echo "❌ GTR_WORKTREE_PATH not set correctly: $GTR_WORKTREE_PATH"
    return 1
  fi
  
  if [[ "$GTR_BRANCH_NAME" != "test-branch" ]]; then
    echo "❌ GTR_BRANCH_NAME not set correctly: $GTR_BRANCH_NAME"
    return 1
  fi
  
  if [[ "$GTR_BASE_BRANCH" != "main" ]]; then
    echo "❌ GTR_BASE_BRANCH not set correctly: $GTR_BASE_BRANCH"
    return 1
  fi
  
  echo "✅ gtr_init_context works correctly"
  return 0
}

test_utils_helper_functions() {
  echo "Testing helper functions..."
  
  # Test action checking
  GTR_ACTION="create"
  if ! gtr_is_action "create"; then
    echo "❌ gtr_is_action failed for create"
    return 1
  fi
  
  if gtr_is_action "remove"; then
    echo "❌ gtr_is_action incorrectly returned true for remove"
    return 1
  fi
  
  # Test no-open checking
  GTR_NO_OPEN="true"
  if ! gtr_is_no_open; then
    echo "❌ gtr_is_no_open failed"
    return 1
  fi
  
  GTR_NO_OPEN="false"
  if gtr_is_no_open; then
    echo "❌ gtr_is_no_open incorrectly returned true"
    return 1
  fi
  
  # Test getter functions
  GTR_ACTION="test-action"
  GTR_WORKTREE_NAME="test-name"
  GTR_WORKTREE_PATH="/test/path"
  GTR_MAIN_WORKTREE="/main/path"
  
  if [[ "$(gtr_get_action)" != "test-action" ]]; then
    echo "❌ gtr_get_action failed"
    return 1
  fi
  
  if [[ "$(gtr_get_worktree_name)" != "test-name" ]]; then
    echo "❌ gtr_get_worktree_name failed"
    return 1
  fi
  
  if [[ "$(gtr_get_worktree_path)" != "/test/path" ]]; then
    echo "❌ gtr_get_worktree_path failed"
    return 1
  fi
  
  if [[ "$(gtr_get_main_worktree)" != "/main/path" ]]; then
    echo "❌ gtr_get_main_worktree failed"
    return 1
  fi
  
  echo "✅ Helper functions work correctly"
  return 0
}

test_copy_to_worktree_basic() {
  echo "Testing copy_to_worktree basic functionality..."
  
  # Create test directories
  local test_dir=$(mktemp -d)
  local main_dir="$test_dir/main"
  local worktree_dir="$test_dir/worktree"
  
  mkdir -p "$main_dir" "$worktree_dir"
  
  # Set up context
  GTR_MAIN_WORKTREE="$main_dir"
  GTR_WORKTREE_PATH="$worktree_dir"
  
  # Create test files
  echo "test content" > "$main_dir/test.txt"
  echo "env content" > "$main_dir/.env.local"
  mkdir -p "$main_dir/.claude"
  echo "claude content" > "$main_dir/.claude/config.txt"
  
  # Test copying a single file
  copy_to_worktree "test.txt"
  
  if [[ ! -f "$worktree_dir/test.txt" ]]; then
    echo "❌ Single file not copied"
    return 1
  fi
  
  # Test copying with glob pattern
  copy_to_worktree "**/.env.*local*"
  
  if [[ ! -f "$worktree_dir/.env.local" ]]; then
    echo "❌ Glob pattern file not copied"
    return 1
  fi
  
  # Test copying directory
  copy_to_worktree ".claude/"
  
  if [[ ! -d "$worktree_dir/.claude" ]]; then
    echo "❌ Directory not copied"
    return 1
  fi
  
  if [[ ! -f "$worktree_dir/.claude/config.txt" ]]; then
    echo "❌ Directory contents not copied"
    return 1
  fi
  
  # Clean up
  rm -rf "$test_dir"
  
  echo "✅ copy_to_worktree basic functionality works"
  return 0
}

test_copy_multiple_to_worktree() {
  echo "Testing copy_multiple_to_worktree..."
  
  # Create test directories
  local test_dir=$(mktemp -d)
  local main_dir="$test_dir/main"
  local worktree_dir="$test_dir/worktree"
  
  mkdir -p "$main_dir" "$worktree_dir"
  
  # Set up context
  GTR_MAIN_WORKTREE="$main_dir"
  GTR_WORKTREE_PATH="$worktree_dir"
  
  # Create test files
  echo "env1" > "$main_dir/.env.local"
  echo "env2" > "$main_dir/.env.development"
  mkdir -p "$main_dir/.claude"
  echo "claude" > "$main_dir/.claude/config.txt"
  
  # Test copying multiple patterns
  copy_multiple_to_worktree "**/.env.*local*" ".claude/"
  
  if [[ ! -f "$worktree_dir/.env.local" ]]; then
    echo "❌ First pattern not copied"
    return 1
  fi
  
  if [[ ! -d "$worktree_dir/.claude" ]]; then
    echo "❌ Second pattern (directory) not copied"
    return 1
  fi
  
  # Clean up
  rm -rf "$test_dir"
  
  echo "✅ copy_multiple_to_worktree works"
  return 0
}

# Run all tests
run_test_suite() {
  echo "🧪 Running gtr utils tests..."
  
  local tests=(
    "test_utils_init_context"
    "test_utils_helper_functions"
    "test_copy_to_worktree_basic"
    "test_copy_multiple_to_worktree"
  )
  
  local passed=0
  local failed=0
  
  for test in "${tests[@]}"; do
    if $test; then
      ((passed++))
    else
      ((failed++))
    fi
  done
  
  echo ""
  echo "📊 Test Results:"
  echo "  Passed: $passed"
  echo "  Failed: $failed"
  echo "  Total:  $((passed + failed))"
  
  if [[ $failed -eq 0 ]]; then
    echo "✅ All utils tests passed!"
    return 0
  else
    echo "❌ Some utils tests failed!"
    return 1
  fi
}

# Run tests if this script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  run_test_suite
fi
