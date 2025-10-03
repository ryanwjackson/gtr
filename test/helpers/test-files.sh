#!/bin/bash

# test-files.sh - Tests for gtr-files.sh module

# Source the testing framework
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test-utils.sh"
source "$SCRIPT_DIR/mock-git.sh"

# Source required modules
source "$SCRIPT_DIR/../../lib/gtr-ui.sh"
source "$SCRIPT_DIR/../../lib/gtr-config.sh"
source "$SCRIPT_DIR/../../lib/gtr-files.sh"

# Test file difference detection
test_gtr_files_different() {
  local file1="$TEST_TEMP_DIR/file1.txt"
  local file2="$TEST_TEMP_DIR/file2.txt"
  local file3="$TEST_TEMP_DIR/file3.txt"

  echo "content" > "$file1"
  echo "content" > "$file2"
  echo "different" > "$file3"

  # Same files should not be different
  if _gtr_files_different "$file1" "$file2"; then
    assert_failure "true" "Same files should not be detected as different"
  fi

  # Different files should be different
  if ! _gtr_files_different "$file1" "$file3"; then
    assert_failure "false" "Different files should be detected as different"
  fi

  # Non-existent file should be different
  if ! _gtr_files_different "$file1" "$TEST_TEMP_DIR/nonexistent.txt"; then
    assert_failure "false" "Non-existent file should be detected as different"
  fi
}

# Test copying local files
test_gtr_copy_local_files() {
  local source_dir="$TEST_TEMP_DIR/source"
  local target_dir="$TEST_TEMP_DIR/target"
  local config_dir="$TEST_TEMP_DIR/.gtr"

  mkdir -p "$source_dir" "$target_dir"
  create_mock_config "$config_dir"

  # Create files matching the patterns
  create_mock_file "$source_dir/.env.local" "env content"
  create_mock_file "$source_dir/.test-file" "test content"
  create_mock_file "$source_dir/other-file.txt" "other content"

  # Copy files
  _gtr_copy_local_files "$source_dir" "$target_dir" "false" "$TEST_TEMP_DIR"

  # Check that matching files were copied
  assert_file_exists "$target_dir/.env.local" "Should copy .env.local file"
  assert_file_exists "$target_dir/.test-file" "Should copy .test-file"
  assert_file_not_exists "$target_dir/other-file.txt" "Should not copy non-matching files"

  # Check content
  local copied_content=$(cat "$target_dir/.env.local")
  assert_equals "env content" "$copied_content" "Copied file should have same content"
}

# Test copying directories
test_gtr_copy_directories() {
  local source_dir="$TEST_TEMP_DIR/source"
  local target_dir="$TEST_TEMP_DIR/target"
  local config_dir="$TEST_TEMP_DIR/.gtr"

  mkdir -p "$source_dir" "$target_dir"

  # Create config with directory pattern
  cat > "$config_dir/config" << 'EOF'
[files_to_copy]
.claude/
EOF

  # Create directory structure
  mkdir -p "$source_dir/.claude"
  create_mock_file "$source_dir/.claude/config.json" '{"model": "sonnet"}'

  # Copy files
  _gtr_copy_local_files "$source_dir" "$target_dir" "false" "$TEST_TEMP_DIR"

  # Check that directory was copied
  assert_dir_exists "$target_dir/.claude" "Should copy .claude directory"
  assert_file_exists "$target_dir/.claude/config.json" "Should copy files in directory"
}

# Test file copying with force flag
test_gtr_copy_files_force() {
  local source_dir="$TEST_TEMP_DIR/source"
  local target_dir="$TEST_TEMP_DIR/target"
  local config_dir="$TEST_TEMP_DIR/.gtr"

  mkdir -p "$source_dir" "$target_dir"
  create_mock_config "$config_dir"

  # Create files
  create_mock_file "$source_dir/.env.local" "new content"
  create_mock_file "$target_dir/.env.local" "old content"

  # Copy with force - should overwrite without prompting
  _gtr_copy_local_files "$source_dir" "$target_dir" "true" "$TEST_TEMP_DIR"

  local content=$(cat "$target_dir/.env.local")
  assert_equals "new content" "$content" "Should overwrite with force flag"
}


# Test show diff function
test_gtr_show_diff() {
  local file1="$TEST_TEMP_DIR/file1.txt"
  local file2="$TEST_TEMP_DIR/file2.txt"

  echo "line1" > "$file1"
  echo "line2" > "$file2"

  local output
  output=$(_gtr_show_diff "$file1" "$file2" 2>&1)
  assert_contains "$output" "Showing diff" "Should show diff header"
}

# Test merge files function
test_gtr_merge_files() {
  local main_file="$TEST_TEMP_DIR/main.txt"
  local worktree_file="$TEST_TEMP_DIR/worktree.txt"
  local target_file="$TEST_TEMP_DIR/target.txt"

  echo "main content" > "$main_file"
  echo "worktree content" > "$worktree_file"

  _gtr_merge_files "$main_file" "$worktree_file" "$target_file"

  assert_file_exists "$target_file" "Should create merged file"
  local content=$(cat "$target_file")
  assert_contains "$content" "main content" "Should contain main file content"
}

# Test recursive file pattern matching
test_recursive_pattern_matching() {
  local source_dir="$TEST_TEMP_DIR/source"
  local target_dir="$TEST_TEMP_DIR/target"
  local config_dir="$TEST_TEMP_DIR/.gtr"

  mkdir -p "$source_dir/subdir" "$target_dir"
  create_mock_config "$config_dir"

  # Create nested files
  create_mock_file "$source_dir/subdir/.env.local" "nested env"
  create_mock_file "$source_dir/subdir/sub2/.env.local" "deep nested env"

  # Copy files
  _gtr_copy_local_files "$source_dir" "$target_dir" "false" "$TEST_TEMP_DIR"

  # Check that nested files were found and copied
  assert_file_exists "$target_dir/subdir/.env.local" "Should copy nested files"
  assert_file_exists "$target_dir/subdir/sub2/.env.local" "Should copy deeply nested files"
}

# Run all tests
run_files_tests() {
  init_test_suite "gtr-files.sh"

  setup_test_env

  register_test "test_gtr_files_different" "test_gtr_files_different"
  register_test "test_gtr_copy_local_files" "test_gtr_copy_local_files"
  register_test "test_gtr_copy_directories" "test_gtr_copy_directories"
  register_test "test_gtr_copy_files_force" "test_gtr_copy_files_force"
  register_test "test_gtr_show_diff" "test_gtr_show_diff"
  register_test "test_gtr_merge_files" "test_gtr_merge_files"
  register_test "test_recursive_pattern_matching" "test_recursive_pattern_matching"

  cleanup_test_env

  finish_test_suite
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  run_files_tests
fi