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

# Register and run a test with debug output
register_test_with_debug() {
  local test_name="$1"
  local test_function="$2"

  CURRENT_TEST="$test_name"
  ((TEST_COUNT++))

  echo -n "  $test_name ... "

  # Run test in subshell but allow debug output to stderr
  if (set -e; $test_function) 2>&1; then
    echo -e "${GREEN}PASS${NC}"
    ((PASSED_COUNT++))
    return 0
  else
    echo -e "${RED}FAIL${NC}"
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
  echo -e "  Failed: ${RED}$FAILED_COUNT${NC}"

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
run_pnpm=true
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

# Skip test with reason
skip_test() {
  local reason="$1"
  echo -e "${YELLOW}SKIP${NC} ($reason)"
  return 0
}