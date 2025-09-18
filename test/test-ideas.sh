#!/bin/bash

# test-ideas.sh - Test suite for idea management functionality
# Tests idea creation, listing, and filtering features

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source testing framework
source "$SCRIPT_DIR/../test-helpers/test-utils.sh"

# Source gtr modules
source "$SCRIPT_DIR/../lib/gtr-core.sh"
source "$SCRIPT_DIR/../lib/gtr-ui.sh"
source "$SCRIPT_DIR/../lib/gtr-config.sh"
source "$SCRIPT_DIR/../lib/gtr-files.sh"
source "$SCRIPT_DIR/../lib/gtr-git.sh"
source "$SCRIPT_DIR/../lib/gtr-commands.sh"

# Test configuration
TEST_DIR=""
IDEAS_DIR=""
ORIGINAL_PWD=""

# Setup test environment
setup_test_environment() {
  # Create temporary test directory
  TEST_DIR=$(mktemp -d)
  ORIGINAL_PWD=$(pwd)
  cd "$TEST_DIR" || exit 1
  
  # Initialize git repository
  git init >/dev/null 2>&1
  git config user.name "Test User" >/dev/null 2>&1
  git config user.email "test@example.com" >/dev/null 2>&1
  echo "test" > README.md
  git add README.md >/dev/null 2>&1
  git commit -m "Initial commit" >/dev/null 2>&1
  
  # Set up remote
  git remote add origin "https://github.com/test/repo.git" >/dev/null 2>&1
  
  # Create .gtr directory
  mkdir -p .gtr
  IDEAS_DIR="$TEST_DIR/.gtr/ideas"
  
  # Set test environment variables
  export _GTR_USERNAME="testuser"
  export _GTR_EDITOR="cursor"  # Use cursor as default editor
}

# Cleanup test environment
cleanup_test_environment() {
  if [[ -n "$ORIGINAL_PWD" ]]; then
    cd "$ORIGINAL_PWD" || true
  fi
  if [[ -n "$TEST_DIR" && -d "$TEST_DIR" ]]; then
    rm -rf "$TEST_DIR"
  fi
}

# Test helper functions
test_get_ideas_dir() {
  local result
  result=$(_gtr_get_ideas_dir)
  
  # The function should return the ideas directory relative to the main worktree
  # Since we're in a worktree, it will return the main repo's .gtr/ideas
  assert_contains "$result" ".gtr/ideas" "get_ideas_dir should contain .gtr/ideas"
}

test_ensure_ideas_dir() {
  # Test creating ideas directory
  assert_success "_gtr_ensure_ideas_dir" "ensure_ideas_dir should succeed"
  assert_dir_exists "$IDEAS_DIR" "ideas directory should be created"
  
  # Test when directory already exists
  assert_success "_gtr_ensure_ideas_dir" "ensure_ideas_dir should handle existing directory"
}

test_generate_idea_filename() {
  local result
  result=$(_gtr_generate_idea_filename "Test Idea")
  
  # Check format: YYYYMMDDTHHMMSSZ_username_sanitized-summary.md
  if [[ "$result" =~ ^[0-9]{8}T[0-9]{6}Z_testuser_Test-Idea\.md$ ]]; then
    return 0
  else
    echo "ASSERTION FAILED: generate_idea_filename format"
    echo "  Expected: YYYYMMDDTHHMMSSZ_testuser_Test-Idea.md"
    echo "  Actual:   $result"
    return 1
  fi
}

test_generate_idea_filename_special_chars() {
  local result
  result=$(_gtr_generate_idea_filename "Test & Idea!@#$%")
  
  # Check that special characters are sanitized
  if [[ "$result" =~ ^[0-9]{8}T[0-9]{6}Z_testuser_Test---Idea-----\.md$ ]]; then
    return 0
  else
    echo "ASSERTION FAILED: generate_idea_filename special character sanitization"
    echo "  Expected: YYYYMMDDTHHMMSSZ_testuser_Test---Idea-----.md"
    echo "  Actual:   $result"
    return 1
  fi
}

test_get_repo_info() {
  local result
  result=$(_gtr_get_repo_info)
  
  IFS='|' read -r repo_name repo_url current_branch latest_commit <<< "$result"
  
  assert_equals "repo" "$repo_name" "repo_name should be 'repo'"
  assert_equals "https://github.com/test/repo.git" "$repo_url" "repo_url should be correct"
  assert_equals "main" "$current_branch" "current_branch should be 'main'"
}

test_create_idea_content() {
  local content
  content=$(_gtr_create_idea_content "Test Idea" "test-repo" "https://github.com/test/repo.git" "main" "abc123")
  
  assert_contains "$content" "summary: \"Test Idea\"" "content should contain summary"
  assert_contains "$content" "author: \"testuser\"" "content should contain author"
  assert_contains "$content" "repo_name: \"test-repo\"" "content should contain repo_name"
  assert_contains "$content" "status: \"TODO\"" "content should contain status"
  assert_contains "$content" "# Test Idea" "content should contain title"
}

test_idea_create_with_summary() {
  # Test creating idea with summary argument
  _GTR_ARGS=("Test Feature Idea" "--less")
  local output
  output=$(gtr_idea_create 2>&1)
  
  assert_contains "$output" "Created idea:" "should show creation message"
  assert_contains "$output" "Location:" "should show location message"
  assert_contains "$output" "Opening with less" "should show less opening message"
  
  # Check that file was created
  local files_found=0
  for file in "$IDEAS_DIR"/*_testuser_Test-Feature-Idea.md; do
    if [[ -f "$file" ]]; then
      files_found=1
      break
    fi
  done
  
  if [[ $files_found -eq 1 ]]; then
    return 0
  else
    echo "ASSERTION FAILED: idea file was not created"
    return 1
  fi
}

test_idea_create_without_summary() {
  # Test creating idea without summary (should prompt)
  # We'll simulate this by providing empty input
  local output
  output=$(echo "" | gtr_idea_create 2>&1)
  
  assert_contains "$output" "No summary provided" "should show error for empty summary"
}

test_idea_list_empty() {
  # Test listing when no ideas exist
  local output
  output=$(gtr_idea_list 2>&1)
  
  assert_contains "$output" "No ideas directory found" "should show message when no ideas directory exists"
}

test_idea_list_with_ideas() {
  # Create a test idea file
  local test_file="$IDEAS_DIR/20240101T120000Z_testuser_Test-Idea.md"
  cat > "$test_file" << 'EOF'
---
summary: "Test Idea"
author: "testuser"
datetime: "2024-01-01T12:00:00Z"
repo_name: "test-repo"
repo_url: "https://github.com/test/repo.git"
current_branch_name: "main"
latest_commit: "abc123"
status: "TODO"
---

# Test Idea

## Description

Test idea description.
EOF

  local output
  output=$(gtr_idea_list 2>&1)
  
  assert_contains "$output" "Test Idea" "should show idea summary"
  assert_contains "$output" "testuser" "should show author"
  assert_contains "$output" "TODO" "should show status"
}

test_idea_list_mine_filter() {
  # Create test ideas with different authors
  local test_file1="$IDEAS_DIR/20240101T120000Z_testuser_My-Idea.md"
  local test_file2="$IDEAS_DIR/20240101T120000Z_otheruser_Other-Idea.md"
  
  # Create my idea
  cat > "$test_file1" << 'EOF'
---
summary: "My Idea"
author: "testuser"
datetime: "2024-01-01T12:00:00Z"
repo_name: "test-repo"
repo_url: "https://github.com/test/repo.git"
current_branch_name: "main"
latest_commit: "abc123"
status: "TODO"
---
# My Idea
EOF

  # Create other user's idea
  cat > "$test_file2" << 'EOF'
---
summary: "Other Idea"
author: "otheruser"
datetime: "2024-01-01T12:00:00Z"
repo_name: "test-repo"
repo_url: "https://github.com/test/repo.git"
current_branch_name: "main"
latest_commit: "abc123"
status: "TODO"
---
# Other Idea
EOF

  _GTR_ARGS=("--mine")
  local output
  output=$(gtr_idea_list 2>&1)
  
  assert_contains "$output" "My Idea" "should show my idea"
  assert_not_contains "$output" "Other Idea" "should not show other user's idea"
}

test_idea_list_todo_filter() {
  # Create test ideas with different statuses
  local test_file1="$IDEAS_DIR/20240101T120000Z_testuser_Todo-Idea.md"
  local test_file2="$IDEAS_DIR/20240101T120000Z_testuser_Done-Idea.md"
  
  # Create TODO idea
  cat > "$test_file1" << 'EOF'
---
summary: "Todo Idea"
author: "testuser"
datetime: "2024-01-01T12:00:00Z"
repo_name: "test-repo"
repo_url: "https://github.com/test/repo.git"
current_branch_name: "main"
latest_commit: "abc123"
status: "TODO"
---
# Todo Idea
EOF

  # Create DONE idea
  cat > "$test_file2" << 'EOF'
---
summary: "Done Idea"
author: "testuser"
datetime: "2024-01-01T12:00:00Z"
repo_name: "test-repo"
repo_url: "https://github.com/test/repo.git"
current_branch_name: "main"
latest_commit: "abc123"
status: "DONE"
---
# Done Idea
EOF

  _GTR_ARGS=("--todo")
  local output
  output=$(gtr_idea_list 2>&1)
  
  assert_contains "$output" "Todo Idea" "should show TODO idea"
  assert_not_contains "$output" "Done Idea" "should not show DONE idea"
}

test_idea_list_status_filter() {
  # Create test ideas with different statuses
  local test_file1="$IDEAS_DIR/20240101T120000Z_testuser_In-Progress-Idea.md"
  local test_file2="$IDEAS_DIR/20240101T120000Z_testuser_Blocked-Idea.md"
  
  # Create IN_PROGRESS idea
  cat > "$test_file1" << 'EOF'
---
summary: "In Progress Idea"
author: "testuser"
datetime: "2024-01-01T12:00:00Z"
repo_name: "test-repo"
repo_url: "https://github.com/test/repo.git"
current_branch_name: "main"
latest_commit: "abc123"
status: "IN_PROGRESS"
---
# In Progress Idea
EOF

  # Create BLOCKED idea
  cat > "$test_file2" << 'EOF'
---
summary: "Blocked Idea"
author: "testuser"
datetime: "2024-01-01T12:00:00Z"
repo_name: "test-repo"
repo_url: "https://github.com/test/repo.git"
current_branch_name: "main"
latest_commit: "abc123"
status: "BLOCKED"
---
# Blocked Idea
EOF

  _GTR_ARGS=("--status=IN_PROGRESS")
  local output
  output=$(gtr_idea_list 2>&1)
  
  assert_contains "$output" "In Progress Idea" "should show IN_PROGRESS idea"
  assert_not_contains "$output" "Blocked Idea" "should not show BLOCKED idea"
}

test_idea_list_content_filter() {
  # Create test ideas with different content
  local test_file1="$IDEAS_DIR/20240101T120000Z_testuser_Performance-Idea.md"
  local test_file2="$IDEAS_DIR/20240101T120000Z_testuser_UI-Idea.md"
  
  # Create performance idea
  cat > "$test_file1" << 'EOF'
---
summary: "Performance Idea"
author: "testuser"
datetime: "2024-01-01T12:00:00Z"
repo_name: "test-repo"
repo_url: "https://github.com/test/repo.git"
current_branch_name: "main"
latest_commit: "abc123"
status: "TODO"
---

# Performance Idea

## Description

This idea is about optimizing database performance.
EOF

  # Create UI idea
  cat > "$test_file2" << 'EOF'
---
summary: "UI Idea"
author: "testuser"
datetime: "2024-01-01T12:00:00Z"
repo_name: "test-repo"
repo_url: "https://github.com/test/repo.git"
current_branch_name: "main"
latest_commit: "abc123"
status: "TODO"
---

# UI Idea

## Description

This idea is about improving the user interface.
EOF

  _GTR_ARGS=("--filter=performance")
  local output
  output=$(gtr_idea_list 2>&1)
  
  assert_contains "$output" "Performance Idea" "should show performance idea"
  assert_not_contains "$output" "UI Idea" "should not show UI idea"
}

test_idea_list_content_filter_case_insensitive() {
  # Create test ideas with different content
  local test_file1="$IDEAS_DIR/20240101T120000Z_testuser_Database-Idea.md"
  local test_file2="$IDEAS_DIR/20240101T120000Z_testuser_Frontend-Idea.md"
  
  # Create database idea
  cat > "$test_file1" << 'EOF'
---
summary: "Database Idea"
author: "testuser"
datetime: "2024-01-01T12:00:00Z"
repo_name: "test-repo"
repo_url: "https://github.com/test/repo.git"
current_branch_name: "main"
latest_commit: "abc123"
status: "TODO"
---

# Database Idea

## Description

This idea is about database optimization.
EOF

  # Create frontend idea
  cat > "$test_file2" << 'EOF'
---
summary: "Frontend Idea"
author: "testuser"
datetime: "2024-01-01T12:00:00Z"
repo_name: "test-repo"
repo_url: "https://github.com/test/repo.git"
current_branch_name: "main"
latest_commit: "abc123"
status: "TODO"
---

# Frontend Idea

## Description

This idea is about frontend improvements.
EOF

  _GTR_ARGS=("--filter=DATABASE")
  local output
  output=$(gtr_idea_list 2>&1)
  
  assert_contains "$output" "Database Idea" "should show database idea (case-insensitive)"
  assert_not_contains "$output" "Frontend Idea" "should not show frontend idea"
}

test_idea_command_help() {
  local output
  output=$(gtr_idea 2>&1)
  
  assert_contains "$output" "Usage: gtr idea" "should show usage"
  assert_contains "$output" "create, c" "should show create command"
  assert_contains "$output" "list, l" "should show list command"
  assert_contains "$output" "open, o" "should show open command"
}

test_idea_command_create() {
  _GTR_ARGS=("create" "Test Command Idea" "--less")
  local output
  output=$(gtr_idea 2>&1)
  
  assert_contains "$output" "Created idea:" "should show creation message"
  assert_contains "$output" "Opening with less" "should show less opening message"
  
  # Check that file was created
  local files_found=0
  for file in "$IDEAS_DIR"/*_testuser_Test-Command-Idea.md; do
    if [[ -f "$file" ]]; then
      files_found=1
      break
    fi
  done
  
  if [[ $files_found -eq 1 ]]; then
    return 0
  else
    echo "ASSERTION FAILED: idea file was not created"
    return 1
  fi
}

test_idea_command_list() {
  # Create a test idea first
  local test_file="$IDEAS_DIR/20240101T120000Z_testuser_Command-Test-Idea.md"
  cat > "$test_file" << 'EOF'
---
summary: "Command Test Idea"
author: "testuser"
datetime: "2024-01-01T12:00:00Z"
repo_name: "test-repo"
repo_url: "https://github.com/test/repo.git"
current_branch_name: "main"
latest_commit: "abc123"
status: "TODO"
---
# Command Test Idea
EOF

  _GTR_ARGS=("list")
  local output
  output=$(gtr_idea 2>&1)
  
  assert_contains "$output" "Command Test Idea" "should show idea in list"
}

test_idea_command_open() {
  # Create a test idea first
  local test_file="$IDEAS_DIR/20240101T120000Z_testuser_Open-Test-Idea.md"
  cat > "$test_file" << 'EOF'
---
summary: "Open Test Idea"
author: "testuser"
datetime: "2024-01-01T12:00:00Z"
repo_name: "test-repo"
repo_url: "https://github.com/test/repo.git"
current_branch_name: "main"
latest_commit: "abc123"
status: "TODO"
---
# Open Test Idea

This is a test idea for the open command.
EOF

  # Test opening with less
  _GTR_ARGS=("open" "20240101T120000Z_testuser_Open-Test-Idea.md" "--less")
  local output
  output=$(gtr_idea 2>&1)
  
  # The output should contain the file content since less will display it
  assert_contains "$output" "Open Test Idea" "should show idea content"
  assert_contains "$output" "This is a test idea" "should show idea description"
}

test_idea_command_open_not_found() {
  # Test opening non-existent idea
  _GTR_ARGS=("open" "nonexistent-idea.md")
  local output
  output=$(gtr_idea 2>&1)
  
  assert_contains "$output" "Idea file not found" "should show error for missing file"
  assert_contains "$output" "Available ideas" "should show available ideas"
}

# Main test execution
main() {
  # Initialize test suite
  init_test_suite "Idea Management"
  
  # Setup
  setup_test_environment
  
  # Run tests
  register_test "get_ideas_dir" test_get_ideas_dir
  register_test "idea_list_empty" test_idea_list_empty
  register_test "ensure_ideas_dir" test_ensure_ideas_dir
  register_test "generate_idea_filename" test_generate_idea_filename
  register_test "generate_idea_filename_special_chars" test_generate_idea_filename_special_chars
  register_test "get_repo_info" test_get_repo_info
  register_test "create_idea_content" test_create_idea_content
  register_test "idea_create_with_summary" test_idea_create_with_summary
  register_test "idea_create_without_summary" test_idea_create_without_summary
  register_test "idea_list_with_ideas" test_idea_list_with_ideas
  register_test "idea_list_mine_filter" test_idea_list_mine_filter
  register_test "idea_list_todo_filter" test_idea_list_todo_filter
  register_test "idea_list_status_filter" test_idea_list_status_filter
  register_test "idea_list_content_filter" test_idea_list_content_filter
  register_test "idea_list_content_filter_case_insensitive" test_idea_list_content_filter_case_insensitive
  register_test "idea_command_help" test_idea_command_help
  register_test "idea_command_create" test_idea_command_create
  register_test "idea_command_list" test_idea_command_list
  register_test "idea_command_open" test_idea_command_open
  register_test "idea_command_open_not_found" test_idea_command_open_not_found
  
  # Cleanup
  cleanup_test_environment
  
  # Show results
  finish_test_suite
}

# Run main if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi