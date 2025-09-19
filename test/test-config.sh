#!/bin/bash

# test-config.sh - Tests for gtr-config.sh module

# Source the testing framework
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test-helpers/test-utils.sh"
source "$SCRIPT_DIR/test-helpers/mock-git.sh"

# Source required modules
source "$SCRIPT_DIR/../lib/gtr-ui.sh"
source "$SCRIPT_DIR/../lib/gtr-config.sh"

# Test reading configuration
test_gtr_read_config() {
  local config_dir="$TEST_TEMP_DIR/.gtr"
  create_mock_config "$config_dir"

  local patterns=($(_gtr_read_config "$TEST_TEMP_DIR"))
  assert_equals "2" "${#patterns[@]}" "Should read 2 patterns from config"
  assert_equals ".env*local*" "${patterns[0]}" "First pattern should be .env*local*"
  assert_equals ".test-file" "${patterns[1]}" "Second pattern should be .test-file"
}

# Test reading configuration with fallback
test_gtr_read_config_fallback() {
  # Create a new clean temp directory for this test
  local clean_temp_dir=$(mktemp -d -t gtr-test-fallback-XXXXXX)

  # Test without config file - should use defaults
  local patterns=($(_gtr_read_config "$clean_temp_dir"))
  assert_equals "3" "${#patterns[@]}" "Should return 3 default patterns"
  assert_equals ".env*local*" "${patterns[0]}" "First default should be .env*local*"
  assert_equals ".claude/" "${patterns[1]}" "Second default should be .claude/"
  assert_equals ".anthropic/" "${patterns[2]}" "Third default should be .anthropic/"

  # Cleanup
  rm -rf "$clean_temp_dir"
}

# Test reading configuration settings
test_gtr_read_config_setting() {
  local config_dir="$TEST_TEMP_DIR/.gtr"
  create_mock_config "$config_dir"

  local editor=$(_gtr_read_config_setting "$TEST_TEMP_DIR" "settings" "editor" "default")
  assert_equals "test-editor" "$editor" "Should read editor setting"

  local run_pnpm=$(_gtr_read_config_setting "$TEST_TEMP_DIR" "settings" "run_pnpm" "false")
  assert_equals "true" "$run_pnpm" "Should read run_pnpm setting"

  local nonexistent=$(_gtr_read_config_setting "$TEST_TEMP_DIR" "settings" "nonexistent" "default")
  assert_equals "default" "$nonexistent" "Should return default for nonexistent setting"
}

# Test generating default config
test_gtr_generate_default_config() {
  local output
  output=$(_gtr_generate_default_config)
  assert_contains "$output" "[files_to_copy]" "Should contain files_to_copy section"
  assert_contains "$output" "[settings]" "Should contain settings section"
  assert_contains "$output" "[doctor]" "Should contain doctor section"
  assert_contains "$output" ".env*local*" "Should contain default env pattern"
  assert_contains "$output" ".claude/" "Should contain claude directory"
}

# Test creating default config file
test_gtr_create_default_config() {
  local config_file="$TEST_TEMP_DIR/test-config"
  _gtr_create_default_config "$config_file"

  assert_file_exists "$config_file" "Config file should be created"

  local content=$(cat "$config_file")
  assert_contains "$content" "[files_to_copy]" "Config should contain files_to_copy section"
  assert_contains "$content" "editor=cursor" "Config should contain default editor setting"
}

# Test config repair function
test_gtr_repair_config() {
  local config_file="$TEST_TEMP_DIR/broken-config"

  # Create a malformed config
  cat > "$config_file" << 'EOF'
[files_to_copy]
.env*local*
malformed line without proper formatting
.test-file
[invalid section
EOF

  _gtr_repair_config "$config_file"

  assert_file_exists "$config_file" "Repaired config should exist"
  assert_file_exists "${config_file}.backup."* "Backup should be created"

  local content=$(cat "$config_file")
  assert_contains "$content" ".env*local*" "Should preserve valid patterns"
  assert_contains "$content" ".test-file" "Should preserve valid patterns"
  assert_contains "$content" "[settings]" "Should add missing sections"
}

# Test configuration validation
test_config_validation() {
  local config_dir="$TEST_TEMP_DIR/.gtr"
  mkdir -p "$config_dir"

  # Test empty config file
  touch "$config_dir/config"
  local patterns=($(_gtr_read_config "$TEST_TEMP_DIR"))
  assert_equals "4" "${#patterns[@]}" "Empty config should fall back to defaults"

  # Test config with comments only
  cat > "$config_dir/config" << 'EOF'
# This is a comment
# Another comment
[files_to_copy]
# Just comments in this section
EOF
  patterns=($(_gtr_read_config "$TEST_TEMP_DIR"))
  assert_equals "4" "${#patterns[@]}" "Config with only comments should fall back to defaults"
}

# Test global vs local config precedence
test_config_precedence() {
  # Create global config
  local global_config_dir="$HOME/.gtr"
  mkdir -p "$global_config_dir"
  cat > "$global_config_dir/config" << 'EOF'
[settings]
editor=global-editor
run_pnpm=false
EOF

  # Create local config
  local local_config_dir="$TEST_TEMP_DIR/.gtr"
  mkdir -p "$local_config_dir"
  cat > "$local_config_dir/config" << 'EOF'
[settings]
editor=local-editor
EOF

  # Local should override global
  local editor=$(_gtr_read_config_setting "$TEST_TEMP_DIR" "settings" "editor" "default")
  assert_equals "local-editor" "$editor" "Local config should override global"

  # Global should be used when local doesn't have setting
  local run_pnpm=$(_gtr_read_config_setting "$TEST_TEMP_DIR" "settings" "run_pnpm" "default")
  assert_equals "false" "$run_pnpm" "Should fall back to global config"

  # Cleanup
  rm -rf "$global_config_dir"
}

# Run all tests
run_config_tests() {
  init_test_suite "gtr-config.sh"

  setup_test_env

  register_test "test_gtr_read_config" "test_gtr_read_config"
  register_test "test_gtr_read_config_fallback" "test_gtr_read_config_fallback"
  register_test "test_gtr_read_config_setting" "test_gtr_read_config_setting"
  register_test "test_gtr_generate_default_config" "test_gtr_generate_default_config"
  register_test "test_gtr_create_default_config" "test_gtr_create_default_config"
  register_test "test_gtr_repair_config" "test_gtr_repair_config"
  register_test "test_config_validation" "test_config_validation"
  register_test "test_config_precedence" "test_config_precedence"

  cleanup_test_env

  finish_test_suite
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  run_config_tests
fi