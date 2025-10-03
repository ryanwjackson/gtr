#!/bin/bash

# test-run-hook.sh - Test gtr run hook command
# Tests the run hook functionality with proper variable setup

# Source test utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../test-utils.sh"

# Test variables
TEST_HOOK_NAME="test-hook"
TEST_BASE_BRANCH="main"
TEST_WORKTREE_NAME="test-worktree"

# Setup test environment
setup_test_env() {
  # Create temporary directory for test
  GTR_TEST_TEMP_DIR=$(mktemp -d)
  export GTR_TEST_TEMP_DIR
  
  # Create test git repository
  cd "$GTR_TEST_TEMP_DIR" || exit 1
  git init --initial-branch=main
  git config user.name "Test User"
  git config user.email "test@example.com"
  
  # Create initial commit
  echo "Initial commit" > README.md
  git add README.md
  git commit -m "Initial commit"
  
  # Create test branch
  git checkout -b develop
  echo "Develop branch" > develop.md
  git add develop.md
  git commit -m "Add develop file"
  git checkout main
  
  # Create test hooks directory
  mkdir -p .gtr/hooks
  
  # Create test hook
  cat > .gtr/hooks/$TEST_HOOK_NAME << 'EOF'
#!/bin/bash
echo "🔧 Test hook executing for: $WORKTREE_NAME"
echo "   Base branch: $BASE_BRANCH"
echo "   Main worktree: $MAIN_WORKTREE"
echo "   Worktree path: $WORKTREE_PATH"
echo "   Branch name: $BRANCH_NAME"
echo "   Editor: $EDITOR"
echo "   GTR action: $GTR_ACTION"
echo "   Dry run: $DRY_RUN"
echo "   Force: $FORCE"
echo "✅ Test hook completed"
exit 0
EOF
  
  chmod +x .gtr/hooks/$TEST_HOOK_NAME
  
  # Create another test hook for testing multiple hooks
  cat > .gtr/hooks/another-hook << 'EOF'
#!/bin/bash
echo "🔧 Another hook executing"
echo "   Hook name: $(basename "$0")"
echo "✅ Another hook completed"
exit 0
EOF
  
  chmod +x .gtr/hooks/another-hook
  
  # Create a non-executable hook for testing
  cat > .gtr/hooks/non-executable-hook << 'EOF'
#!/bin/bash
echo "This hook should not run"
exit 1
EOF
  # Don't make it executable
  
  # Create a sample hook for testing
  cat > .gtr/hooks/sample-hook.sample << 'EOF'
#!/bin/bash
echo "This is a sample hook"
exit 0
EOF
  chmod +x .gtr/hooks/sample-hook.sample
}

# Cleanup test environment
cleanup_test_env() {
  if [[ -n "$GTR_TEST_TEMP_DIR" && -d "$GTR_TEST_TEMP_DIR" ]]; then
    rm -rf "$GTR_TEST_TEMP_DIR"
  fi
}

# Test run hook with hook name
test_run_hook_with_name() {
  local test_name="run_hook_with_name"
  echo "Testing: $test_name"
  
  local output
  if output=$(cd "$GTR_TEST_TEMP_DIR" && ../../bin/gtr run hook $TEST_HOOK_NAME 2>&1); then
    if echo "$output" | grep -q "Test hook executing for: manual-run" && \
       echo "$output" | grep -q "Base branch: main" && \
       echo "$output" | grep -q "Test hook completed"; then
      echo "✅ $test_name passed"
      return 0
    else
      echo "❌ $test_name failed: Output doesn't match expected"
      echo "Output: $output"
      return 1
    fi
  else
    echo "❌ $test_name failed: Command failed"
    echo "Output: $output"
    return 1
  fi
}

# Test run hook with base branch specified
test_run_hook_with_base() {
  local test_name="run_hook_with_base"
  echo "Testing: $test_name"
  
  local output
  if output=$(cd "$GTR_TEST_TEMP_DIR" && ../../bin/gtr run hook $TEST_HOOK_NAME --base=develop 2>&1); then
    if echo "$output" | grep -q "Test hook executing for: manual-run" && \
       echo "$output" | grep -q "Base branch: develop" && \
       echo "$output" | grep -q "Test hook completed"; then
      echo "✅ $test_name passed"
      return 0
    else
      echo "❌ $test_name failed: Output doesn't match expected"
      echo "Output: $output"
      return 1
    fi
  else
    echo "❌ $test_name failed: Command failed"
    echo "Output: $output"
    return 1
  fi
}

# Test run hook without hook name (should show usage)
test_run_hook_without_name() {
  local test_name="run_hook_without_name"
  echo "Testing: $test_name"
  
  local output
  if output=$(cd "$GTR_TEST_TEMP_DIR" && ../../bin/gtr run hook 2>&1); then
    echo "❌ $test_name failed: Command should have failed"
    return 1
  else
    if echo "$output" | grep -q "Hook name required" && \
       echo "$output" | grep -q "Usage: gtr run hook"; then
      echo "✅ $test_name passed"
      return 0
    else
      echo "❌ $test_name failed: Output doesn't match expected"
      echo "Output: $output"
      return 1
    fi
  fi
}

# Test run hook with non-existent hook
test_run_hook_nonexistent() {
  local test_name="run_hook_nonexistent"
  echo "Testing: $test_name"
  
  local output
  if output=$(cd "$GTR_TEST_TEMP_DIR" && ../../bin/gtr run hook nonexistent-hook 2>&1); then
    echo "❌ $test_name failed: Command should have failed"
    return 1
  else
    if echo "$output" | grep -q "Hook 'nonexistent-hook' not found" && \
       echo "$output" | grep -q "Available hooks:"; then
      echo "✅ $test_name passed"
      return 0
    else
      echo "❌ $test_name failed: Output doesn't match expected"
      echo "Output: $output"
      return 1
    fi
  fi
}

# Test run hook with non-executable hook
test_run_hook_non_executable() {
  local test_name="run_hook_non_executable"
  echo "Testing: $test_name"
  
  local output
  if output=$(cd "$GTR_TEST_TEMP_DIR" && ../../bin/gtr run hook non-executable-hook 2>&1); then
    echo "❌ $test_name failed: Command should have failed"
    return 1
  else
    if echo "$output" | grep -q "Hook 'non-executable-hook' is not executable"; then
      echo "✅ $test_name passed"
      return 0
    else
      echo "❌ $test_name failed: Output doesn't match expected"
      echo "Output: $output"
      return 1
    fi
  fi
}

# Test run hook outside git repository
test_run_hook_outside_git() {
  local test_name="run_hook_outside_git"
  echo "Testing: $test_name"
  
  local temp_dir
  temp_dir=$(mktemp -d)
  
  local output
  if output=$(cd "$temp_dir" && "$GTR_TEST_TEMP_DIR/../../bin/gtr" run hook $TEST_HOOK_NAME 2>&1); then
    echo "❌ $test_name failed: Command should have failed"
    rm -rf "$temp_dir"
    return 1
  else
    if echo "$output" | grep -q "Not in a git repository"; then
      echo "✅ $test_name passed"
      rm -rf "$temp_dir"
      return 0
    else
      echo "❌ $test_name failed: Output doesn't match expected"
      echo "Output: $output"
      rm -rf "$temp_dir"
      return 1
    fi
  fi
}

# Test run hook with sample hook (should be skipped)
test_run_hook_sample() {
  local test_name="run_hook_sample"
  echo "Testing: $test_name"
  
  local output
  if output=$(cd "$GTR_TEST_TEMP_DIR" && ../../bin/gtr run hook sample-hook 2>&1); then
    echo "❌ $test_name failed: Command should have failed"
    return 1
  else
    if echo "$output" | grep -q "Hook 'sample-hook' is not executable"; then
      echo "✅ $test_name passed"
      return 0
    else
      echo "❌ $test_name failed: Output doesn't match expected"
      echo "Output: $output"
      return 1
    fi
  fi
}

# Test run hook with dry run
test_run_hook_dry_run() {
  local test_name="run_hook_dry_run"
  echo "Testing: $test_name"
  
  local output
  if output=$(cd "$GTR_TEST_TEMP_DIR" && ../../bin/gtr run hook $TEST_HOOK_NAME --dry-run 2>&1); then
    if echo "$output" | grep -q "Test hook executing for: manual-run" && \
       echo "$output" | grep -q "Dry run: true" && \
       echo "$output" | grep -q "Test hook completed"; then
      echo "✅ $test_name passed"
      return 0
    else
      echo "❌ $test_name failed: Output doesn't match expected"
      echo "Output: $output"
      return 1
    fi
  else
    echo "❌ $test_name failed: Command failed"
    echo "Output: $output"
    return 1
  fi
}

# Test run hook with force
test_run_hook_force() {
  local test_name="run_hook_force"
  echo "Testing: $test_name"
  
  local output
  if output=$(cd "$GTR_TEST_TEMP_DIR" && ../../bin/gtr run hook $TEST_HOOK_NAME --force 2>&1); then
    if echo "$output" | grep -q "Test hook executing for: manual-run" && \
       echo "$output" | grep -q "Force: true" && \
       echo "$output" | grep -q "Test hook completed"; then
      echo "✅ $test_name passed"
      return 0
    else
      echo "❌ $test_name failed: Output doesn't match expected"
      echo "Output: $output"
      return 1
    fi
  else
    echo "❌ $test_name failed: Command failed"
    echo "Output: $output"
    return 1
  fi
}

# Test run hook with custom editor
test_run_hook_custom_editor() {
  local test_name="run_hook_custom_editor"
  echo "Testing: $test_name"
  
  local output
  if output=$(cd "$GTR_TEST_TEMP_DIR" && ../../bin/gtr run hook $TEST_HOOK_NAME --editor=vim 2>&1); then
    if echo "$output" | grep -q "Test hook executing for: manual-run" && \
       echo "$output" | grep -q "Editor: vim" && \
       echo "$output" | grep -q "Test hook completed"; then
      echo "✅ $test_name passed"
      return 0
    else
      echo "❌ $test_name failed: Output doesn't match expected"
      echo "Output: $output"
      return 1
    fi
  else
    echo "❌ $test_name failed: Command failed"
    echo "Output: $output"
    return 1
  fi
}

# Test run hook with another hook
test_run_hook_another() {
  local test_name="run_hook_another"
  echo "Testing: $test_name"
  
  local output
  if output=$(cd "$GTR_TEST_TEMP_DIR" && ../../bin/gtr run hook another-hook 2>&1); then
    if echo "$output" | grep -q "Another hook executing" && \
       echo "$output" | grep -q "Another hook completed"; then
      echo "✅ $test_name passed"
      return 0
    else
      echo "❌ $test_name failed: Output doesn't match expected"
      echo "Output: $output"
      return 1
    fi
  else
    echo "❌ $test_name failed: Command failed"
    echo "Output: $output"
    return 1
  fi
}

# Test run hook with failing hook
test_run_hook_failing() {
  local test_name="run_hook_failing"
  echo "Testing: $test_name"
  
  # Create a failing hook
  cat > "$GTR_TEST_TEMP_DIR/.gtr/hooks/failing-hook" << 'EOF'
#!/bin/bash
echo "This hook will fail"
exit 1
EOF
  chmod +x "$GTR_TEST_TEMP_DIR/.gtr/hooks/failing-hook"
  
  local output
  if output=$(cd "$GTR_TEST_TEMP_DIR" && ../../bin/gtr run hook failing-hook 2>&1); then
    echo "❌ $test_name failed: Command should have failed"
    return 1
  else
    if echo "$output" | grep -q "This hook will fail" && \
       echo "$output" | grep -q "Hook 'failing-hook' failed with exit code 1"; then
      echo "✅ $test_name passed"
      return 0
    else
      echo "❌ $test_name failed: Output doesn't match expected"
      echo "Output: $output"
      return 1
    fi
  fi
}

# Run all tests
run_tests() {
  init_test_suite "Run Hook Command"
  setup_test_env
  
  register_test "run_hook_with_name" test_run_hook_with_name
  register_test "run_hook_with_base" test_run_hook_with_base
  register_test "run_hook_without_name" test_run_hook_without_name
  register_test "run_hook_nonexistent" test_run_hook_nonexistent
  register_test "run_hook_non_executable" test_run_hook_non_executable
  register_test "run_hook_outside_git" test_run_hook_outside_git
  register_test "run_hook_sample" test_run_hook_sample
  register_test "run_hook_dry_run" test_run_hook_dry_run
  register_test "run_hook_force" test_run_hook_force
  register_test "run_hook_custom_editor" test_run_hook_custom_editor
  register_test "run_hook_another" test_run_hook_another
  register_test "run_hook_failing" test_run_hook_failing
  
  cleanup_test_env
  finish_test_suite
}

# Run tests if this script is executed directly
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  run_tests
fi
