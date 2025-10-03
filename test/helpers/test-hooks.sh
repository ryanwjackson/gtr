#!/bin/bash

# test-hooks.sh - Tests for gtr-hooks.sh module

# Source the testing framework
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test-utils.sh"
source "$SCRIPT_DIR/mock-git.sh"

# Source required modules
source "$SCRIPT_DIR/../../lib/gtr-core.sh"
source "$SCRIPT_DIR/../../lib/gtr-hooks.sh"

# Test hook execution with successful hook
test_gtr_execute_hook_success() {
  local hooks_dir="$TEST_TEMP_DIR/hooks"
  mkdir -p "$hooks_dir"
  
  # Create a test hook that succeeds
  cat > "$hooks_dir/test-hook" << 'EOF'
#!/bin/bash
echo "Hook executed with args: $@"
exit 0
EOF
  chmod +x "$hooks_dir/test-hook"
  
  # Capture output
  local output
  output=$(_gtr_execute_hook "test-hook" "$hooks_dir" "arg1" "arg2" 2>&1)
  
  assert_contains "$output" "Executing hook: test-hook" "Should show hook execution message"
  assert_contains "$output" "Hook test-hook completed successfully" "Should show success message"
  assert_contains "$output" "Hook executed with args: arg1 arg2" "Should show hook output"
}

# Test hook execution with failing hook
test_gtr_execute_hook_failure() {
  local hooks_dir="$TEST_TEMP_DIR/hooks"
  mkdir -p "$hooks_dir"
  
  # Create a test hook that fails
  cat > "$hooks_dir/failing-hook" << 'EOF'
#!/bin/bash
echo "Hook failed"
exit 1
EOF
  chmod +x "$hooks_dir/failing-hook"
  
  # Capture output
  local output
  output=$(_gtr_execute_hook "failing-hook" "$hooks_dir" 2>&1)
  
  assert_contains "$output" "Executing hook: failing-hook" "Should show hook execution message"
  assert_contains "$output" "Hook failing-hook failed with exit code 1" "Should show failure message"
  assert_contains "$output" "Hook failed" "Should show hook output"
}

# Test hook execution with non-existent hook
test_gtr_execute_hook_missing() {
  local hooks_dir="$TEST_TEMP_DIR/hooks"
  mkdir -p "$hooks_dir"
  
  # Capture output
  local output
  output=$(_gtr_execute_hook "missing-hook" "$hooks_dir" 2>&1)
  
  assert_equals "" "$output" "Should not output anything for missing hook"
}

# Test hook execution with non-executable hook
test_gtr_execute_hook_not_executable() {
  local hooks_dir="$TEST_TEMP_DIR/hooks"
  mkdir -p "$hooks_dir"
  
  # Create a non-executable hook
  cat > "$hooks_dir/non-executable-hook" << 'EOF'
#!/bin/bash
echo "This should not run"
EOF
  # Don't make it executable
  
  # Capture output
  local output
  output=$(_gtr_execute_hook "non-executable-hook" "$hooks_dir" 2>&1)
  
  assert_contains "$output" "Hook non-executable-hook is not executable, skipping" "Should show non-executable message"
}

# Test finding hooks directory with local hooks
test_gtr_find_hooks_dir_local() {
  local main_worktree="$TEST_TEMP_DIR"
  local global_hooks_dir="$GTR_TEST_TEMP_DIR/.gtr/hooks"
  local local_hooks_dir="$main_worktree/.gtr/hooks"
  
  # Create local hooks directory
  mkdir -p "$local_hooks_dir"
  
  # Create global hooks directory (should be ignored)
  mkdir -p "$global_hooks_dir"
  
  local result
  result=$(_gtr_find_hooks_dir "$main_worktree")
  
  assert_equals "$local_hooks_dir" "$result" "Should find local hooks directory"
}

# Test finding hooks directory with global hooks only
test_gtr_find_hooks_dir_global() {
  local main_worktree="$TEST_TEMP_DIR"
  local fake_home="$GTR_TEST_TEMP_DIR/fake-home"
  local global_hooks_dir="$fake_home/.gtr/hooks"

  # Ensure no local hooks directory exists
  rm -rf "$main_worktree/.gtr/hooks"

  # Create only global hooks directory in fake home
  mkdir -p "$global_hooks_dir"

  local result
  result=$(HOME="$fake_home" _gtr_find_hooks_dir "$main_worktree")

  assert_equals "$global_hooks_dir" "$result" "Should find global hooks directory"
  
  # Cleanup
  rm -rf "$global_hooks_dir"
}

# Test finding hooks directory with no hooks
test_gtr_find_hooks_dir_none() {
  local main_worktree="$TEST_TEMP_DIR"

  # Ensure no local hooks directory exists
  rm -rf "$main_worktree/.gtr/hooks"

  local result
  local exit_code
  # Run in a subshell with overridden HOME to avoid finding global hooks
  result=$(HOME="$GTR_TEST_TEMP_DIR/fake-home" _gtr_find_hooks_dir "$main_worktree" 2>/dev/null)
  exit_code=$?

  assert_equals "1" "$exit_code" "Should return error code 1 when no hooks found"
}

# Test pre-create hook execution
test_gtr_execute_pre_create_hook() {
  local main_worktree="$TEST_TEMP_DIR"
  local hooks_dir="$main_worktree/.gtr/hooks"
  mkdir -p "$hooks_dir"
  
  # Create a pre-create hook
  cat > "$hooks_dir/pre-create" << 'EOF'
#!/bin/bash
echo "Pre-create hook: $1 $2 $3 $4 $5"
exit 0
EOF
  chmod +x "$hooks_dir/pre-create"
  
  # Capture output
  local output
  output=$(_gtr_execute_pre_create_hook "test-worktree" "/path/to/worktree" "test-branch" "main" "$main_worktree" 2>&1)
  
  assert_contains "$output" "Executing hook: pre-create" "Should show hook execution message"
  assert_contains "$output" "Pre-create hook: create test-worktree /path/to/worktree test-branch main" "Should show hook output"
}

# Test post-create hook execution
test_gtr_execute_post_create_hook() {
  local main_worktree="$TEST_TEMP_DIR"
  local hooks_dir="$main_worktree/.gtr/hooks"
  mkdir -p "$hooks_dir"
  
  # Create a post-create hook
  cat > "$hooks_dir/post-create" << 'EOF'
#!/bin/bash
echo "Post-create hook: $1 $2 $3 $4 $5"
exit 0
EOF
  chmod +x "$hooks_dir/post-create"
  
  # Capture output
  local output
  output=$(_gtr_execute_post_create_hook "test-worktree" "/path/to/worktree" "test-branch" "main" "$main_worktree" 2>&1)
  
  assert_contains "$output" "Executing hook: post-create" "Should show hook execution message"
  assert_contains "$output" "Post-create hook: create test-worktree /path/to/worktree test-branch main" "Should show hook output"
}

# Test pre-remove hook execution
test_gtr_execute_pre_remove_hook() {
  local main_worktree="$TEST_TEMP_DIR"
  local hooks_dir="$main_worktree/.gtr/hooks"
  mkdir -p "$hooks_dir"
  
  # Create a pre-remove hook
  cat > "$hooks_dir/pre-remove" << 'EOF'
#!/bin/bash
echo "Pre-remove hook: $1 $2 $3 $4 $5 $6"
exit 0
EOF
  chmod +x "$hooks_dir/pre-remove"
  
  # Capture output
  local output
  output=$(_gtr_execute_pre_remove_hook "test-worktree" "/path/to/worktree" "test-branch" "false" "false" "$main_worktree" 2>&1)
  
  assert_contains "$output" "Executing hook: pre-remove" "Should show hook execution message"
  assert_contains "$output" "Pre-remove hook: remove test-worktree /path/to/worktree test-branch false false" "Should show hook output"
}

# Test post-remove hook execution
test_gtr_execute_post_remove_hook() {
  local main_worktree="$TEST_TEMP_DIR"
  local hooks_dir="$main_worktree/.gtr/hooks"
  mkdir -p "$hooks_dir"
  
  # Create a post-remove hook
  cat > "$hooks_dir/post-remove" << 'EOF'
#!/bin/bash
echo "Post-remove hook: $1 $2 $3 $4 $5 $6"
exit 0
EOF
  chmod +x "$hooks_dir/post-remove"
  
  # Capture output
  local output
  output=$(_gtr_execute_post_remove_hook "test-worktree" "/path/to/worktree" "test-branch" "false" "false" "$main_worktree" 2>&1)
  
  assert_contains "$output" "Executing hook: post-remove" "Should show hook execution message"
  assert_contains "$output" "Post-remove hook: remove test-worktree /path/to/worktree test-branch false false" "Should show hook output"
}

# Test pre-prune hook execution
test_gtr_execute_pre_prune_hook() {
  local main_worktree="$TEST_TEMP_DIR"
  local hooks_dir="$main_worktree/.gtr/hooks"
  mkdir -p "$hooks_dir"
  
  # Create a pre-prune hook
  cat > "$hooks_dir/pre-prune" << 'EOF'
#!/bin/bash
echo "Pre-prune hook: $1 $2 $3 $4"
exit 0
EOF
  chmod +x "$hooks_dir/pre-prune"
  
  # Capture output
  local output
  output=$(_gtr_execute_pre_prune_hook "main" "false" "false" "$main_worktree" 2>&1)
  
  assert_contains "$output" "Executing hook: pre-prune" "Should show hook execution message"
  assert_contains "$output" "Pre-prune hook: prune main false false" "Should show hook output"
}

# Test post-prune hook execution
test_gtr_execute_post_prune_hook() {
  local main_worktree="$TEST_TEMP_DIR"
  local hooks_dir="$main_worktree/.gtr/hooks"
  mkdir -p "$hooks_dir"
  
  # Create a post-prune hook
  cat > "$hooks_dir/post-prune" << 'EOF'
#!/bin/bash
echo "Post-prune hook: $1 $2 $3 $4"
exit 0
EOF
  chmod +x "$hooks_dir/post-prune"
  
  # Capture output
  local output
  output=$(_gtr_execute_post_prune_hook "main" "false" "false" "$main_worktree" 2>&1)
  
  assert_contains "$output" "Executing hook: post-prune" "Should show hook execution message"
  assert_contains "$output" "Post-prune hook: prune main false false" "Should show hook output"
}

# Test before-open hook execution
test_gtr_execute_before_open_hook() {
  local main_worktree="$TEST_TEMP_DIR"
  local hooks_dir="$main_worktree/.gtr/hooks"
  mkdir -p "$hooks_dir"
  
  # Create a before-open hook
  cat > "$hooks_dir/before-open" << 'EOF'
#!/bin/bash
echo "Before-open hook: $1 $2 $3 $4"
exit 0
EOF
  chmod +x "$hooks_dir/before-open"
  
  # Capture output
  local output
  output=$(_gtr_execute_before_open_hook "test-worktree" "/path/to/worktree" "cursor" "create" "$main_worktree" 2>&1)
  
  assert_contains "$output" "Executing hook: before-open" "Should show hook execution message"
  assert_contains "$output" "Before-open hook: create test-worktree /path/to/worktree cursor" "Should show hook output"
}

# Test post-open hook execution
test_gtr_execute_post_open_hook() {
  local main_worktree="$TEST_TEMP_DIR"
  local hooks_dir="$main_worktree/.gtr/hooks"
  mkdir -p "$hooks_dir"
  
  # Create a post-open hook
  cat > "$hooks_dir/post-open" << 'EOF'
#!/bin/bash
echo "Post-open hook: $1 $2 $3 $4"
exit 0
EOF
  chmod +x "$hooks_dir/post-open"
  
  # Capture output
  local output
  output=$(_gtr_execute_post_open_hook "test-worktree" "/path/to/worktree" "cursor" "create" "$main_worktree" 2>&1)
  
  assert_contains "$output" "Executing hook: post-open" "Should show hook execution message"
  assert_contains "$output" "Post-open hook: create test-worktree /path/to/worktree cursor" "Should show hook output"
}

# Test hook execution with no hooks directory
test_gtr_execute_hook_no_directory() {
  local main_worktree="$TEST_TEMP_DIR"
  
  # Capture output and exit code
  local output
  local exit_code
  output=$(_gtr_execute_pre_create_hook "test-worktree" "/path/to/worktree" "test-branch" "main" "$main_worktree" 2>&1)
  exit_code=$?
  
  assert_equals "0" "$exit_code" "Should return 0 when no hooks directory exists"
  # Allow for any output since the function might output something
}

# Test hook execution with empty hooks directory
test_gtr_execute_hook_empty_directory() {
  local main_worktree="$TEST_TEMP_DIR"
  local hooks_dir="$main_worktree/.gtr/hooks"
  mkdir -p "$hooks_dir"
  
  # Capture output and exit code
  local output
  local exit_code
  output=$(_gtr_execute_pre_create_hook "test-worktree" "/path/to/worktree" "test-branch" "main" "$main_worktree" 2>&1)
  exit_code=$?
  
  assert_equals "0" "$exit_code" "Should return 0 when hooks directory is empty"
  # Allow for any output since the function might output something
}

# Test hook execution with non-executable hook file
test_gtr_execute_hook_non_executable_file() {
  local hooks_dir="$TEST_TEMP_DIR/hooks"
  mkdir -p "$hooks_dir"

  # Create a non-executable hook file
  cat > "$hooks_dir/non-executable-hook" << 'EOF'
#!/bin/bash
echo "This should not run"
EOF
  # Don't make it executable

  # Capture output
  local output
  output=$(_gtr_execute_hook "non-executable-hook" "$hooks_dir" 2>&1)

  assert_contains "$output" "Hook non-executable-hook is not executable, skipping" "Should show non-executable message"
}

# Test hook execution with failing pre-create hook
test_gtr_execute_pre_create_hook_failure() {
  local main_worktree="$TEST_TEMP_DIR"
  local hooks_dir="$main_worktree/.gtr/hooks"
  mkdir -p "$hooks_dir"
  
  # Create a failing pre-create hook
  cat > "$hooks_dir/pre-create" << 'EOF'
#!/bin/bash
echo "Pre-create hook failed"
exit 1
EOF
  chmod +x "$hooks_dir/pre-create"
  
  # Capture output
  local output
  output=$(_gtr_execute_pre_create_hook "test-worktree" "/path/to/worktree" "test-branch" "main" "$main_worktree" 2>&1)
  
  assert_contains "$output" "Executing hook: pre-create" "Should show hook execution message"
  assert_contains "$output" "Hook pre-create failed with exit code 1" "Should show failure message"
  assert_contains "$output" "Pre-create hook failed" "Should show hook output"
}

# Run all tests
run_tests() {
  init_test_suite "Hook Execution"
  setup_test_env
  
  register_test "execute_hook_success" test_gtr_execute_hook_success
  register_test "execute_hook_failure" test_gtr_execute_hook_failure
  register_test "execute_hook_missing" test_gtr_execute_hook_missing
  register_test "execute_hook_not_executable" test_gtr_execute_hook_not_executable
  register_test "find_hooks_dir_local" test_gtr_find_hooks_dir_local
  register_test "find_hooks_dir_global" test_gtr_find_hooks_dir_global
  register_test "find_hooks_dir_none" test_gtr_find_hooks_dir_none
  register_test "execute_pre_create_hook" test_gtr_execute_pre_create_hook
  register_test "execute_post_create_hook" test_gtr_execute_post_create_hook
  register_test "execute_pre_remove_hook" test_gtr_execute_pre_remove_hook
  register_test "execute_post_remove_hook" test_gtr_execute_post_remove_hook
  register_test "execute_pre_prune_hook" test_gtr_execute_pre_prune_hook
  register_test "execute_post_prune_hook" test_gtr_execute_post_prune_hook
  register_test "execute_before_open_hook" test_gtr_execute_before_open_hook
  register_test "execute_post_open_hook" test_gtr_execute_post_open_hook
  register_test "execute_hook_no_directory" test_gtr_execute_hook_no_directory
  register_test "execute_hook_empty_directory" test_gtr_execute_hook_empty_directory
  register_test "execute_hook_non_executable_file" test_gtr_execute_hook_non_executable_file
  register_test "execute_pre_create_hook_failure" test_gtr_execute_pre_create_hook_failure
  
  cleanup_test_env
  finish_test_suite
}

# Run tests if this script is executed directly
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  run_tests
fi
