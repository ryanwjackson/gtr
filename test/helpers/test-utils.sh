#!/bin/bash

# test-utils.sh - Testing utilities and framework
# Provides assertion functions and test management

# Test tracking variables
TEST_COUNT=0
PASSED_COUNT=0
FAILED_COUNT=0
CURRENT_TEST=""
TEST_SUITE=""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Initialize test suite
init_test_suite() {
  local suite_name="$1"
  TEST_SUITE="$suite_name"
  TEST_COUNT=0
  PASSED_COUNT=0
  FAILED_COUNT=0
  echo -e "${YELLOW}=== Running Test Suite: $suite_name ===${NC}"

  # Set up isolated environment for all tests by default
  setup_gtr_test_env
}

# Register and run a test
register_test() {
  local test_name="$1"
  local test_function="$2"

  CURRENT_TEST="$test_name"
  ((TEST_COUNT++))

  echo -n "  $test_name ... "

  # Run test in subshell to isolate environment
  if (set -e; $test_function) >/dev/null 2>&1; then
    echo -e "${GREEN}PASS${NC}"
    ((PASSED_COUNT++))
    return 0
  else
    echo -e "${RED}FAIL${NC}"
    ((FAILED_COUNT++))
    return 1
  fi
}

# Run test with output capture
run_test_with_output() {
  local test_name="$1"
  local test_function="$2"

  CURRENT_TEST="$test_name"
  ((TEST_COUNT++))

  echo -n "  $test_name ... "

  # Capture output
  local output
  local exit_code
  output=$(set -e; $test_function 2>&1)
  exit_code=$?

  if [[ $exit_code -eq 0 ]]; then
    echo -e "${GREEN}PASS${NC}"
    ((PASSED_COUNT++))
    return 0
  else
    echo -e "${RED}FAIL${NC}"
    echo "    Output: $output"
    ((FAILED_COUNT++))
    return 1
  fi
}


# Assertion functions
assert_equals() {
  local expected="$1"
  local actual="$2"
  local message="${3:-Assertion failed}"

  if [[ "$expected" == "$actual" ]]; then
    return 0
  else
    echo "ASSERTION FAILED: $message"
    echo "  Expected: '$expected'"
    echo "  Actual:   '$actual'"
    return 1
  fi
}

assert_not_equals() {
  local expected="$1"
  local actual="$2"
  local message="${3:-Assertion failed}"

  if [[ "$expected" != "$actual" ]]; then
    return 0
  else
    echo "ASSERTION FAILED: $message"
    echo "  Expected NOT: '$expected'"
    echo "  Actual:       '$actual'"
    return 1
  fi
}

assert_file_exists() {
  local file_path="$1"
  local message="${2:-File should exist}"

  if [[ -f "$file_path" ]]; then
    return 0
  else
    echo "ASSERTION FAILED: $message"
    echo "  File does not exist: '$file_path'"
    return 1
  fi
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local message="${3:-String should contain substring}"

  if [[ "$haystack" == *"$needle"* ]]; then
    return 0
  else
    echo "ASSERTION FAILED: $message"
    echo "  String:    '$haystack'"
    echo "  Should contain: '$needle'"
    return 1
  fi
}

assert_not_contains() {
  local haystack="$1"
  local needle="$2"
  local message="${3:-String should not contain substring}"

  if [[ "$haystack" != *"$needle"* ]]; then
    return 0
  else
    echo "ASSERTION FAILED: $message"
    echo "  String:    '$haystack'"
    echo "  Should NOT contain: '$needle'"
    return 1
  fi
}

assert_contains_or() {
  local string="$1"
  local substring1="$2"
  local substring2="$3"
  local message="${4:-String should contain either substring}"

  if [[ "$string" == *"$substring1"* ]] || [[ "$string" == *"$substring2"* ]]; then
    return 0
  else
    echo "ASSERTION FAILED: $message"
    echo "  String: '$string'"
    echo "  Should contain either: '$substring1' or '$substring2'"
    return 1
  fi
}

assert_success() {
  local command="$1"
  local message="${2:-Command should succeed}"

  if eval "$command" >/dev/null 2>&1; then
    return 0
  else
    echo "ASSERTION FAILED: $message"
    echo "  Command: '$command'"
    echo "  Expected: success (exit code 0)"
    echo "  Actual:   failure (exit code $?)"
    return 1
  fi
}

assert_failure() {
  local command="$1"
  local message="${2:-Command should fail}"

  if ! eval "$command" >/dev/null 2>&1; then
    return 0
  else
    echo "ASSERTION FAILED: $message"
    echo "  Command: '$command'"
    echo "  Expected: failure (non-zero exit code)"
    echo "  Actual:   success (exit code 0)"
    return 1
  fi
}

assert_file_exists() {
  local file="$1"
  local message="${2:-File should exist}"

  if [[ -f "$file" ]]; then
    return 0
  else
    echo "ASSERTION FAILED: $message"
    echo "  File: '$file'"
    return 1
  fi
}

assert_file_not_exists() {
  local file="$1"
  local message="${2:-File should not exist}"

  if [[ ! -f "$file" ]]; then
    return 0
  else
    echo "ASSERTION FAILED: $message"
    echo "  File: '$file'"
    return 1
  fi
}

assert_executable() {
  local file="$1"
  local message="${2:-File should be executable}"

  if [[ -f "$file" && -x "$file" ]]; then
    return 0
  else
    echo "ASSERTION FAILED: $message"
    echo "  File: '$file'"
    return 1
  fi
}

assert_directory_exists() {
  local dir="$1"
  local message="${2:-Directory should exist}"

  if [[ -d "$dir" ]]; then
    return 0
  else
    echo "ASSERTION FAILED: $message"
    echo "  Directory: '$dir'"
    return 1
  fi
}

assert_directory_not_exists() {
  local dir="$1"
  local message="${2:-Directory should not exist}"

  if [[ ! -d "$dir" ]]; then
    return 0
  else
    echo "ASSERTION FAILED: $message"
    echo "  Directory: '$dir'"
    return 1
  fi
}

assert_file_different() {
  local file1="$1"
  local file2="$2"
  local message="${3:-Files should be different}"

  if [[ -f "$file1" && -f "$file2" ]]; then
    if ! diff -q "$file1" "$file2" >/dev/null 2>&1; then
      return 0
    else
      echo "ASSERTION FAILED: $message"
      echo "  File1: '$file1'"
      echo "  File2: '$file2'"
      return 1
    fi
  else
    echo "ASSERTION FAILED: $message"
    echo "  File1: '$file1' (exists: $([[ -f "$file1" ]] && echo "yes" || echo "no"))"
    echo "  File2: '$file2' (exists: $([[ -f "$file2" ]] && echo "yes" || echo "no"))"
    return 1
  fi
}

assert_not_empty() {
  local value="$1"
  local message="${2:-Value should not be empty}"

  if [[ -n "$value" ]]; then
    return 0
  else
    echo "ASSERTION FAILED: $message"
    echo "  Value: '$value'"
    return 1
  fi
}

assert_dir_exists() {
  local dir="$1"
  local message="${2:-Directory should exist}"

  if [[ -d "$dir" ]]; then
    return 0
  else
    echo "ASSERTION FAILED: $message"
    echo "  Directory: '$dir'"
    return 1
  fi
}

assert_dir_not_exists() {
  local dir="$1"
  local message="${2:-Directory should not exist}"

  if [[ ! -d "$dir" ]]; then
    return 0
  else
    echo "ASSERTION FAILED: $message"
    echo "  Directory: '$dir'"
    return 1
  fi
}

# Test suite summary
finish_test_suite() {
  echo ""
  echo -e "${YELLOW}=== Test Suite Summary: $TEST_SUITE ===${NC}"
  echo "  Total tests: $TEST_COUNT"
  echo -e "  Passed: ${GREEN}$PASSED_COUNT${NC}"
  if [[ $FAILED_COUNT -eq 0 ]]; then
    echo -e "  Failed: ${GREEN}$FAILED_COUNT${NC}"
  else
    echo -e "  Failed: ${RED}$FAILED_COUNT${NC}"
  fi

  # Clean up isolated test environment
  teardown_gtr_test_env

  if [[ $FAILED_COUNT -eq 0 ]]; then
    echo -e "  ${GREEN}✅ All tests passed!${NC}"
    return 0
  else
    echo -e "  ${RED}❌ Some tests failed!${NC}"
    return 1
  fi
}

# Setup temporary test directory
setup_test_env() {
  export TEST_TEMP_DIR=$(mktemp -d -t gtr-test-XXXXXX)
  export TEST_ORIGINAL_DIR=$(pwd)
  cd "$TEST_TEMP_DIR"

  # Initialize a git repo for testing
  git init --quiet
  git config user.name "Test User"
  git config user.email "test@example.com"

  # Create initial commit
  echo "# Test Repository" > README.md
  git add README.md
  git commit --quiet -m "Initial commit"
}

# Cleanup test environment
cleanup_test_env() {
  cd "$TEST_ORIGINAL_DIR"
  if [[ -n "$TEST_TEMP_DIR" && -d "$TEST_TEMP_DIR" ]]; then
    rm -rf "$TEST_TEMP_DIR"
  fi
}

# Mock git commands for testing
mock_git_worktree() {
  # Simple mock that just creates directories
  local action="$1"
  shift

  case "$action" in
    "add")
      local path="$1"
      mkdir -p "$path"
      echo "Mock: git worktree add $path"
      ;;
    "remove")
      local path="$1"
      rm -rf "$path"
      echo "Mock: git worktree remove $path"
      ;;
    "list")
      find . -maxdepth 2 -type d -name "*worktree*" 2>/dev/null | while read dir; do
        echo "$(realpath "$dir") [mock-branch]"
      done
      ;;
  esac
}

# Test helper to create mock config
create_mock_config() {
  local config_dir="$1"
  local config_file="$config_dir/config"

  mkdir -p "$config_dir"
  cat > "$config_file" << 'EOF'
[files_to_copy]
.env*local*
.test-file

[settings]
editor=test-editor
auto_open=false

[doctor]
show_detailed_diffs=false
auto_fix=false
EOF
}

# Test helper to create mock files
create_mock_file() {
  local file_path="$1"
  local content="${2:-test content}"

  mkdir -p "$(dirname "$file_path")"
  echo "$content" > "$file_path"
}

# Enhanced setup for gtr testing with isolated git repo
setup_gtr_test_env() {
  # Create isolated temporary directory
  export GTR_TEST_TEMP_DIR=$(mktemp -d -t gtr-test-XXXXXX)
  export GTR_TEST_ORIGINAL_DIR=$(pwd)

  # Get absolute path to gtr binary - use the modular version for testing
  if [[ -f "$GTR_TEST_ORIGINAL_DIR/bin/gtr" ]]; then
    export GTR_TEST_GTR_PATH="$GTR_TEST_ORIGINAL_DIR/bin/gtr"
  elif [[ -f "$PWD/bin/gtr" ]]; then
    export GTR_TEST_GTR_PATH="$PWD/bin/gtr"
  else
    # Find gtr in the path or use a fallback (go up two dirs from test/helpers)
    local gtr_script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
    export GTR_TEST_GTR_PATH="$gtr_script_dir/bin/gtr"
  fi

  cd "$GTR_TEST_TEMP_DIR"

  # Initialize a fresh git repository
  git init --quiet
  git config user.name "GTR Test User"
  git config user.email "gtr-test@example.com"

  # Create initial commit with some content
  echo "# GTR Test Repository" > README.md
  echo "test-file-content" > test-file.txt
  git add .
  git commit --quiet -m "Initial test commit"

  # Initialize gtr in this repo (skip interactive prompts)
  echo "s" | "$GTR_TEST_GTR_PATH" --git-root="$GTR_TEST_TEMP_DIR" init >/dev/null 2>&1 || true

  echo "GTR test environment setup at: $GTR_TEST_TEMP_DIR"
}

# Enhanced teardown for gtr testing
teardown_gtr_test_env() {
  # Return to original directory
  cd "$GTR_TEST_ORIGINAL_DIR"

  # Clean up temporary directory
  if [[ -n "$GTR_TEST_TEMP_DIR" && -d "$GTR_TEST_TEMP_DIR" ]]; then
    echo "Cleaning up GTR test environment: $GTR_TEST_TEMP_DIR"
    rm -rf "$GTR_TEST_TEMP_DIR"
  fi

  # Unset environment variables
  unset GTR_TEST_TEMP_DIR
  unset GTR_TEST_ORIGINAL_DIR
  unset GTR_TEST_GTR_PATH
}

# Helper to run gtr commands in the test environment
run_gtr_test() {
  "$GTR_TEST_GTR_PATH" --git-root="$GTR_TEST_TEMP_DIR" "$@"
}

# Alias for backward compatibility - all gtr calls in tests should be isolated
gtr() {
  run_gtr_test "$@"
}

# Helper to create uncommitted changes for testing
create_test_uncommitted_changes() {
  local file_type="${1:-staged}"  # staged, modified, or untracked

  case "$file_type" in
    "staged")
      echo "new staged content" > staged-file.txt
      git add staged-file.txt
      ;;
    "modified")
      echo "modified content" >> test-file.txt
      ;;
    "untracked")
      echo "untracked content" > untracked-file.txt
      ;;
    "mixed")
      echo "new staged content" > staged-file.txt
      git add staged-file.txt
      echo "modified content" >> test-file.txt
      echo "untracked content" > untracked-file.txt
      ;;
  esac
}

# Skip test with reason
skip_test() {
  local reason="$1"
  echo -e "${YELLOW}SKIP${NC} ($reason)"
  return 0
}