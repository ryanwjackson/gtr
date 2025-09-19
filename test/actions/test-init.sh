#!/bin/bash

# test-init.sh - Tests for gtr init command functionality

# Source the testing framework
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../helpers/test-utils.sh"
source "$SCRIPT_DIR/../helpers/mock-git.sh"

# Source required modules
source "$SCRIPT_DIR/../../lib/gtr-ui.sh"
source "$SCRIPT_DIR/../../lib/gtr-config.sh"
source "$SCRIPT_DIR/../../lib/gtr-commands.sh"

# The commands are available through the module sources above

# Test init in current directory (not main worktree)
test_gtr_init_current_directory() {
  local test_dir="$TEST_TEMP_DIR/init-test"
  mkdir -p "$test_dir"
  
  # Initialize git repo
  (cd "$test_dir" && git init >/dev/null 2>&1 && git commit --allow-empty -m "Initial commit" >/dev/null 2>&1)
  
  # Create a mock main worktree (simulate being in a worktree)
  local main_worktree="$TEST_TEMP_DIR/main-worktree"
  mkdir -p "$main_worktree"
  (cd "$main_worktree" && git init >/dev/null 2>&1 && git commit --allow-empty -m "Main commit" >/dev/null 2>&1)
  
  # Create a worktree
  (cd "$main_worktree" && git worktree add "$test_dir" -b "worktrees/test/ryanwjackson/init-test" >/dev/null 2>&1)
  
  # Test init in the worktree directory
  (cd "$test_dir" && printf "keep\ny\n" | gtr_init >/dev/null 2>&1)
  
  # Verify config was created in current directory (worktree), not main worktree
  assert_file_exists "$test_dir/.gtr/config" "Config should be created in current directory"
  assert_file_not_exists "$main_worktree/.gtr/config" "Config should NOT be created in main worktree"
  
  # Verify hooks were copied to current directory
  assert_file_exists "$test_dir/.gtr/hooks" "Hooks directory should be created in current directory"
  assert_file_exists "$test_dir/.gtr/hooks/pre-create" "Pre-create hook should be copied"
  assert_file_exists "$test_dir/.gtr/hooks/post-create" "Post-create hook should be copied"
  
  # Cleanup
  rm -rf "$test_dir" "$main_worktree"
}

# Test init in main repository
test_gtr_init_main_repository() {
  local test_dir="$TEST_TEMP_DIR/main-repo"
  mkdir -p "$test_dir"
  
  # Initialize git repo
  (cd "$test_dir" && git init >/dev/null 2>&1 && git commit --allow-empty -m "Initial commit" >/dev/null 2>&1)
  
  # Mock user input for init
  (cd "$test_dir" && printf "keep\ny\n" | gtr_init >/dev/null 2>&1)
  
  # Verify config was created in current directory
  assert_file_exists "$test_dir/.gtr/config" "Config should be created in current directory"
  
  # Verify hooks were copied
  assert_file_exists "$test_dir/.gtr/hooks" "Hooks directory should be created"
  assert_file_exists "$test_dir/.gtr/hooks/pre-create" "Pre-create hook should be copied"
  assert_file_exists "$test_dir/.gtr/hooks/post-create" "Post-create hook should be copied"
  
  # Cleanup
  rm -rf "$test_dir"
}

# Test init with existing local config
test_gtr_init_existing_local_config() {
  local test_dir="$TEST_TEMP_DIR/existing-config"
  mkdir -p "$test_dir"
  
  # Initialize git repo
  (cd "$test_dir" && git init >/dev/null 2>&1 && git commit --allow-empty -m "Initial commit" >/dev/null 2>&1)
  
  # Create existing config
  mkdir -p "$test_dir/.gtr"
  cat > "$test_dir/.gtr/config" << 'EOF'
[files_to_copy]
.existing-file
EOF
  
  # Mock user input for init (skip existing config)
  (cd "$test_dir" && printf "keep\nskip\n" | gtr_init >/dev/null 2>&1)
  
  # Verify config still exists
  assert_file_exists "$test_dir/.gtr/config" "Existing config should still exist"
  
  # Verify hooks were still copied
  assert_file_exists "$test_dir/.gtr/hooks" "Hooks directory should be created"
  assert_file_exists "$test_dir/.gtr/hooks/pre-create" "Pre-create hook should be copied"
  
  # Cleanup
  rm -rf "$test_dir"
}

# Test init with hooks copying functionality
test_gtr_init_hooks_copying() {
  local test_dir="$TEST_TEMP_DIR/hooks-test"
  mkdir -p "$test_dir"
  
  # Initialize git repo
  (cd "$test_dir" && git init >/dev/null 2>&1 && git commit --allow-empty -m "Initial commit" >/dev/null 2>&1)
  
  # Mock user input for init
  (cd "$test_dir" && printf "keep\ny\n" | gtr_init >/dev/null 2>&1)
  
  # Verify all hooks were copied
  local expected_hooks=("pre-create" "post-create" "pre-remove" "post-remove" "pre-prune" "post-prune")
  for hook in "${expected_hooks[@]}"; do
    assert_file_exists "$test_dir/.gtr/hooks/$hook" "Hook $hook should be copied"
    assert_executable "$test_dir/.gtr/hooks/$hook" "Hook $hook should be executable"
  done
  
  # Verify hooks directory structure
  assert_directory_exists "$test_dir/.gtr/hooks" "Hooks directory should exist"
  
  # Cleanup
  rm -rf "$test_dir"
}

# Test init with global config only (no local config)
test_gtr_init_global_only() {
  local test_dir="$TEST_TEMP_DIR/global-only"
  mkdir -p "$test_dir"
  
  # Initialize git repo
  (cd "$test_dir" && git init >/dev/null 2>&1 && git commit --allow-empty -m "Initial commit" >/dev/null 2>&1)
  
  # Mock user input for init (no local config)
  (cd "$test_dir" && printf "keep\nn\n" | gtr_init >/dev/null 2>&1)
  
  # Verify no local config was created
  assert_file_not_exists "$test_dir/.gtr/config" "No local config should be created"
  assert_directory_not_exists "$test_dir/.gtr" "No .gtr directory should be created"
  
  # Cleanup
  rm -rf "$test_dir"
}

# Test init doctor mode
test_gtr_init_doctor_mode() {
  local test_dir="$TEST_TEMP_DIR/doctor-test"
  mkdir -p "$test_dir"
  
  # Initialize git repo
  (cd "$test_dir" && git init >/dev/null 2>&1 && git commit --allow-empty -m "Initial commit" >/dev/null 2>&1)
  
  # Create some local files
  echo "test" > "$test_dir/.env.local"
  mkdir -p "$test_dir/.claude"
  echo "test" > "$test_dir/.claude/settings.json"
  
  # Mock user input for init doctor
  (cd "$test_dir" && printf "keep\n" | _GTR_INIT_DOCTOR=true gtr_init >/dev/null 2>&1)
  
  # Verify doctor mode ran (should not create local config)
  assert_file_not_exists "$test_dir/.gtr/config" "Doctor mode should not create local config"
  
  # Cleanup
  rm -rf "$test_dir"
}

# Test hooks copying function directly
test_gtr_copy_hooks_to_local() {
  local test_dir="$TEST_TEMP_DIR/hooks-copy-test"
  mkdir -p "$test_dir"
  
  # Initialize git repo
  (cd "$test_dir" && git init >/dev/null 2>&1 && git commit --allow-empty -m "Initial commit" >/dev/null 2>&1)
  
  # Create .gtr directory
  mkdir -p "$test_dir/.gtr"
  
  # Test hooks copying function directly
  _gtr_copy_hooks_to_local "$test_dir" "$test_dir/.gtr"
  
  # Verify hooks were copied
  assert_directory_exists "$test_dir/.gtr/hooks" "Hooks directory should be created"
  assert_file_exists "$test_dir/.gtr/hooks/pre-create" "Pre-create hook should be copied"
  assert_file_exists "$test_dir/.gtr/hooks/post-create" "Post-create hook should be copied"
  assert_executable "$test_dir/.gtr/hooks/pre-create" "Pre-create hook should be executable"
  assert_executable "$test_dir/.gtr/hooks/post-create" "Post-create hook should be executable"
  
  # Cleanup
  rm -rf "$test_dir"
}

# Test init with different worktree scenarios
test_gtr_init_worktree_scenarios() {
  local main_repo="$TEST_TEMP_DIR/main-repo"
  local worktree1="$TEST_TEMP_DIR/worktree1"
  local worktree2="$TEST_TEMP_DIR/worktree2"
  
  # Create main repository
  mkdir -p "$main_repo"
  (cd "$main_repo" && git init >/dev/null 2>&1 && git commit --allow-empty -m "Initial commit" >/dev/null 2>&1)
  
  # Create worktrees
  (cd "$main_repo" && git worktree add "$worktree1" -b "worktrees/test/ryanwjackson/worktree1" >/dev/null 2>&1)
  (cd "$main_repo" && git worktree add "$worktree2" -b "worktrees/test/ryanwjackson/worktree2" >/dev/null 2>&1)
  
  # Test init in worktree1
  (cd "$worktree1" && printf "keep\ny\n" | gtr_init >/dev/null 2>&1)
  assert_file_exists "$worktree1/.gtr/config" "Config should be created in worktree1"
  assert_file_exists "$worktree1/.gtr/hooks/pre-create" "Hooks should be copied to worktree1"
  
  # Test init in worktree2
  (cd "$worktree2" && printf "keep\ny\n" | gtr_init >/dev/null 2>&1)
  assert_file_exists "$worktree2/.gtr/config" "Config should be created in worktree2"
  assert_file_exists "$worktree2/.gtr/hooks/pre-create" "Hooks should be copied to worktree2"
  
  # Test init in main repo
  (cd "$main_repo" && printf "keep\ny\n" | gtr_init >/dev/null 2>&1)
  assert_file_exists "$main_repo/.gtr/config" "Config should be created in main repo"
  assert_file_exists "$main_repo/.gtr/hooks/pre-create" "Hooks should be copied to main repo"
  
  # Verify each has its own config (not shared)
  assert_file_different "$worktree1/.gtr/config" "$worktree2/.gtr/config" "Worktrees should have separate configs"
  assert_file_different "$worktree1/.gtr/config" "$main_repo/.gtr/config" "Worktree and main should have separate configs"
  
  # Cleanup
  rm -rf "$main_repo" "$worktree1" "$worktree2"
}

# Test init with path resolution for hooks
test_gtr_init_hooks_path_resolution() {
  local test_dir="$TEST_TEMP_DIR/path-test"
  mkdir -p "$test_dir"
  
  # Initialize git repo
  (cd "$test_dir" && git init >/dev/null 2>&1 && git commit --allow-empty -m "Initial commit" >/dev/null 2>&1)
  
  # Mock user input for init
  (cd "$test_dir" && printf "keep\ny\n" | gtr_init >/dev/null 2>&1)
  
  # Verify hooks were found and copied (should work from any directory)
  assert_file_exists "$test_dir/.gtr/hooks" "Hooks directory should be created"
  assert_file_exists "$test_dir/.gtr/hooks/pre-create" "Pre-create hook should be copied"
  
  # Verify hook content is not empty
  local hook_content=$(cat "$test_dir/.gtr/hooks/pre-create")
  assert_not_empty "$hook_content" "Hook should have content"
  
  # Cleanup
  rm -rf "$test_dir"
}

# Run all tests
run_init_tests() {
  init_test_suite "gtr-init.sh"
  
  setup_test_env
  
  register_test "test_gtr_init_current_directory" "test_gtr_init_current_directory"
  register_test "test_gtr_init_main_repository" "test_gtr_init_main_repository"
  register_test "test_gtr_init_existing_local_config" "test_gtr_init_existing_local_config"
  register_test "test_gtr_init_hooks_copying" "test_gtr_init_hooks_copying"
  register_test "test_gtr_init_global_only" "test_gtr_init_global_only"
  register_test "test_gtr_init_doctor_mode" "test_gtr_init_doctor_mode"
  register_test "test_gtr_copy_hooks_to_local" "test_gtr_copy_hooks_to_local"
  register_test "test_gtr_init_worktree_scenarios" "test_gtr_init_worktree_scenarios"
  register_test "test_gtr_init_hooks_path_resolution" "test_gtr_init_hooks_path_resolution"
  
  cleanup_test_env
  
  finish_test_suite
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  run_init_tests
fi
