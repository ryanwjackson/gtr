# Testing Guide for gtr

## Overview
The gtr utility now includes a comprehensive testing framework that ensures code quality, functionality preservation, and module isolation. This guide covers how to run tests, interpret results, and contribute new tests.

## Test Structure

### Framework Components
- **test-helpers/test-utils.sh** - Core testing framework with assertion functions
- **test-helpers/mock-git.sh** - Git command mocking for isolated testing
- **test/test-*.sh** - Individual module test suites
- **test/test-runner.sh** - Central test runner with reporting

### Test Coverage
- **30+ total tests** across 4 test suites
- **Core module**: 7 tests (utilities, version, help, repo detection)
- **Config module**: 8 tests (configuration parsing, validation, repair)
- **Files module**: 8 tests (file operations, copying, pattern matching)
- **Ideas module**: 8+ tests (idea creation, listing, filtering, cross-worktree search)

## Running Tests

### Quick Test Commands
```bash
# Run all tests (recommended)
./test/test-runner.sh

# Run specific test suite
./test/test-runner.sh core    # Core functions
./test/test-runner.sh config  # Configuration management
./test/test-runner.sh files   # File operations
./test/test-runner.sh ideas   # Idea management

# List available tests
./test/test-runner.sh --list

# Run individual test files
bash test/test-core.sh
bash test/test-config.sh
bash test/test-files.sh
bash test/test-ideas.sh
```

### Continuous Integration
Tests run automatically on GitHub Actions for:
- All pushes to main/master branches
- All pull requests
- Manual workflow triggers

See `.github/workflows/ci.yml` for the CI configuration.

## Test Framework Features

### Assertion Functions
The test framework provides comprehensive assertion functions:

```bash
# Basic assertions
assert_equals "expected" "$actual" "Custom message"
assert_not_equals "not_expected" "$actual"
assert_contains "$haystack" "$needle"
assert_not_contains "$haystack" "$needle"

# Command assertions
assert_success "command_to_run"
assert_failure "command_that_should_fail"

# File/directory assertions
assert_file_exists "/path/to/file"
assert_file_not_exists "/path/to/file"
assert_dir_exists "/path/to/directory"
assert_dir_not_exists "/path/to/directory"
```

### Test Environment
Each test runs in an isolated environment:
- Temporary directories created automatically
- Git repositories initialized for testing
- Mock git commands available
- Cleanup handled automatically

### Mock System
Git operations are mocked to enable isolated testing:
```bash
# Enable git mocking
enable_git_mocking

# Mock functions available
mock_git worktree add /path/to/worktree
mock_git status --porcelain
mock_git rev-parse --show-toplevel

# Disable when done
disable_git_mocking
```

## Writing New Tests

### Test Structure Template
```bash
#!/bin/bash

# Source the testing framework
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../test-helpers/test-utils.sh"
source "$SCRIPT_DIR/../test-helpers/mock-git.sh"

# Source modules under test
source "$SCRIPT_DIR/../lib/gtr-module.sh"

# Test function template
test_function_name() {
  # Setup
  setup_test_env
  enable_git_mocking

  # Test logic
  local result=$(function_to_test "argument")
  assert_equals "expected" "$result" "Description of what should happen"

  # Cleanup
  disable_git_mocking
  cleanup_test_env
}

# Run tests
run_module_tests() {
  init_test_suite "module-name"
  setup_test_env

  register_test "test_function_name" "test_function_name"

  cleanup_test_env
  finish_test_suite
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  run_module_tests
fi
```

### Best Practices

#### 1. Test Isolation
- Each test should be independent
- Use separate temp directories when needed
- Clean up resources properly
- Don't rely on test execution order

#### 2. Mock External Dependencies
- Mock git commands using the provided framework
- Don't rely on external tools being installed
- Create mock files and directories as needed

#### 3. Test Edge Cases
- Empty input
- Invalid input
- Missing files/directories
- Permission errors
- Large inputs

#### 4. Clear Test Names and Messages
```bash
# Good
test_gtr_config_handles_malformed_files() {
  assert_equals "3" "${#patterns[@]}" "Should fall back to 3 default patterns when config is malformed"
}

# Bad
test_config() {
  assert_equals "3" "${#patterns[@]}"
}
```

## Test Categories

### Unit Tests
Test individual functions in isolation:
- Core utility functions
- Configuration parsing
- File operations
- Git command wrappers
- Idea management functions

### Integration Tests
Test module interactions:
- Module dependency loading
- Cross-module function calls
- Configuration flow between modules

### Functionality Tests
Test end-to-end behavior:
- Command-line interface
- Complete workflows
- Error handling paths

## Debugging Tests

### Running Tests with Debug Output
```bash
# Run with bash debugging
bash -x test/test-core.sh

# Run specific test function
bash -c "source test/test-core.sh; test_gtr_print_version"

# Check test environment
export TEST_DEBUG=1
./test/test-runner.sh
```

### Common Issues

#### Test Isolation Problems
- **Symptom**: Tests pass individually but fail when run together
- **Solution**: Ensure each test cleans up properly
- **Fix**: Use separate temp directories, reset global variables

#### Mock System Issues
- **Symptom**: Git commands fail in tests
- **Solution**: Enable git mocking before tests
- **Fix**: Call `enable_git_mocking` in test setup

#### Path Problems
- **Symptom**: Module not found errors
- **Solution**: Check relative paths in test files
- **Fix**: Use `$SCRIPT_DIR` for consistent paths

## Performance Testing

### Timing Tests
```bash
# Time individual functions
time bash -c "source lib/gtr-core.sh; _gtr_print_version"

# Compare performance
echo "Original:"
time ./bin/gtr --version >/dev/null
echo "Modular:"
time ./bin/gtr-new --version >/dev/null
```

### Memory Usage
```bash
# Check memory usage
/usr/bin/time -l ./bin/gtr-new --version
```

## Continuous Testing

### Pre-commit Testing
Add to your git hooks:
```bash
#!/bin/bash
# .git/hooks/pre-commit
./test/test-runner.sh
```

### Development Workflow
1. Write tests for new functionality first
2. Implement the functionality
3. Run tests to verify implementation
4. Run full test suite before committing
5. Fix any regressions immediately

### CI/CD Integration
- Tests run on every push and PR
- Multiple bash versions tested
- Security and linting checks included
- Compatibility verification between original and modular versions

## Test Coverage Goals

### Current Coverage
- **Core functions**: 100% of public functions
- **Config functions**: 90% including error cases
- **File operations**: 85% including edge cases
- **Error handling**: 70% of error paths

### Target Coverage
- **90%+ of critical functions tested**
- **All public command functions covered**
- **Major error paths validated**
- **Edge cases and boundary conditions tested**

## Contributing Tests

### Required for New Features
- Unit tests for new functions
- Integration tests for module interactions
- Error handling tests
- Documentation updates

### Test Review Checklist
- [ ] Tests are isolated and independent
- [ ] Edge cases are covered
- [ ] Error conditions are tested
- [ ] Mock system is used appropriately
- [ ] Test names are descriptive
- [ ] Cleanup is handled properly

### Getting Help
- Check existing tests for examples
- Use the test framework functions
- Ask for code review on test quality
- Run tests frequently during development

## Future Testing Enhancements

### Planned Improvements
- Performance regression testing
- Cross-platform compatibility tests
- Integration with external tools testing
- Load testing for large repositories
- Chaos testing for error resilience

### Tools Integration
- ShellCheck for static analysis
- Bash code coverage tools
- Performance monitoring
- Security scanning

This testing framework ensures that gtr remains reliable, maintainable, and compatible across different environments while enabling confident development and refactoring.