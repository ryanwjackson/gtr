#!/bin/bash

# test-runner.sh - Main test runner for all gtr modules
# Executes all test suites and reports aggregate results

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source testing framework
source "$SCRIPT_DIR/../test-helpers/test-utils.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Global test tracking
TOTAL_SUITES=0
PASSED_SUITES=0
FAILED_SUITES=0
TOTAL_TESTS=0
TOTAL_PASSED=0
TOTAL_FAILED=0

# Function to run a test suite
run_test_suite() {
  local test_file="$1"
  local suite_name="$2"

  echo -e "${BLUE}Running $suite_name...${NC}"
  ((TOTAL_SUITES++))

  if [[ -f "$test_file" ]]; then
    # Make test file executable
    chmod +x "$test_file"

    # Run the test suite and capture results
    if "$test_file"; then
      ((PASSED_SUITES++))
      echo -e "${GREEN}✅ $suite_name passed${NC}"
    else
      ((FAILED_SUITES++))
      echo -e "${RED}❌ $suite_name failed${NC}"
    fi
  else
    echo -e "${RED}❌ Test file not found: $test_file${NC}"
    ((FAILED_SUITES++))
  fi

  echo ""
}

# Function to show final summary
show_final_summary() {
  echo -e "${YELLOW}===========================================${NC}"
  echo -e "${YELLOW}           FINAL TEST SUMMARY${NC}"
  echo -e "${YELLOW}===========================================${NC}"
  echo ""
  echo -e "Test Suites:"
  echo -e "  Total:  $TOTAL_SUITES"
  echo -e "  Passed: ${GREEN}$PASSED_SUITES${NC}"
  echo -e "  Failed: ${RED}$FAILED_SUITES${NC}"
  echo ""

  if [[ $FAILED_SUITES -eq 0 ]]; then
    echo -e "${GREEN}🎉 All test suites passed!${NC}"
    return 0
  else
    echo -e "${RED}💥 Some test suites failed!${NC}"
    return 1
  fi
}

# Function to run all tests
run_all_tests() {
  echo -e "${YELLOW}===========================================${NC}"
  echo -e "${YELLOW}           GTR TEST RUNNER${NC}"
  echo -e "${YELLOW}===========================================${NC}"
  echo ""

  # Run each test suite in order
  run_test_suite "$SCRIPT_DIR/test-core.sh" "Core Functions"
  run_test_suite "$SCRIPT_DIR/test-config.sh" "Configuration Management"
  run_test_suite "$SCRIPT_DIR/test-files.sh" "File Operations"
  run_test_suite "$SCRIPT_DIR/test-hooks.sh" "Hook Execution"
  run_test_suite "$SCRIPT_DIR/test-init.sh" "Init Command"
  run_test_suite "$SCRIPT_DIR/test-ideas.sh" "Idea Management"

  # Show final summary
  show_final_summary
}

# Function to run specific test
run_specific_test() {
  local test_name="$1"

  case "$test_name" in
    core)
      run_test_suite "$SCRIPT_DIR/test-core.sh" "Core Functions"
      ;;
    config)
      run_test_suite "$SCRIPT_DIR/test-config.sh" "Configuration Management"
      ;;
    files)
      run_test_suite "$SCRIPT_DIR/test-files.sh" "File Operations"
      ;;
    hooks)
      run_test_suite "$SCRIPT_DIR/test-hooks.sh" "Hook Execution"
      ;;
    init)
      run_test_suite "$SCRIPT_DIR/test-init.sh" "Init Command"
      ;;
    ideas)
      run_test_suite "$SCRIPT_DIR/test-ideas.sh" "Idea Management"
      ;;
    *)
      echo -e "${RED}Unknown test: $test_name${NC}"
      echo "Available tests: core, config, files, hooks, init, ideas"
      return 1
      ;;
  esac
}

# Function to list available tests
list_tests() {
  echo "Available test suites:"
  echo "  core    - Core functions and utilities"
  echo "  config  - Configuration management"
  echo "  files   - File operations and copying"
  echo "  hooks   - Hook execution and management"
  echo "  init    - Init command functionality"
  echo "  ideas   - Idea management functionality"
  echo ""
  echo "Usage:"
  echo "  $0              # Run all tests"
  echo "  $0 <test-name>  # Run specific test"
  echo "  $0 --list       # List available tests"
  echo "  $0 --help       # Show this help"
}

# Function to check prerequisites
check_prerequisites() {
  # Check if we have required commands
  local missing_commands=()

  if ! command -v find >/dev/null 2>&1; then
    missing_commands+=("find")
  fi

  if ! command -v grep >/dev/null 2>&1; then
    missing_commands+=("grep")
  fi

  if ! command -v diff >/dev/null 2>&1; then
    missing_commands+=("diff")
  fi

  if [[ ${#missing_commands[@]} -gt 0 ]]; then
    echo -e "${RED}Missing required commands: ${missing_commands[*]}${NC}"
    echo "Please install these commands to run the tests."
    return 1
  fi

  # Check if lib directory exists
  if [[ ! -d "$SCRIPT_DIR/../lib" ]]; then
    echo -e "${RED}lib directory not found at $SCRIPT_DIR/../lib${NC}"
    echo "Please ensure the gtr modules have been extracted."
    return 1
  fi

  return 0
}

# Function to validate modules exist
validate_modules() {
  local modules=(
    "gtr-core.sh"
    "gtr-ui.sh"
    "gtr-config.sh"
    "gtr-files.sh"
    "gtr-git.sh"
    "gtr-commands.sh"
  )

  local missing_modules=()

  for module in "${modules[@]}"; do
    if [[ ! -f "$SCRIPT_DIR/../lib/$module" ]]; then
      missing_modules+=("$module")
    fi
  done

  if [[ ${#missing_modules[@]} -gt 0 ]]; then
    echo -e "${RED}Missing modules: ${missing_modules[*]}${NC}"
    echo "Please ensure all modules have been extracted from the monolithic script."
    return 1
  fi

  return 0
}

# Function to setup test environment
setup_test_environment() {
  # Set test mode environment variables
  export GTR_TEST_MODE=1
  export GTR_NO_INTERACTIVE=1

  # Create temporary test directory if needed
  if [[ ! -d "$SCRIPT_DIR/../tmp" ]]; then
    mkdir -p "$SCRIPT_DIR/../tmp"
  fi
}

# Main execution
main() {
  local command="${1:-all}"

  # Check prerequisites first
  if ! check_prerequisites; then
    exit 1
  fi

  # Validate modules exist
  if ! validate_modules; then
    exit 1
  fi

  # Setup test environment
  setup_test_environment

  case "$command" in
    --help|-h)
      list_tests
      ;;
    --list|-l)
      list_tests
      ;;
    all|"")
      run_all_tests
      ;;
    *)
      run_specific_test "$command"
      ;;
  esac
}

# Run main if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi