#!/bin/bash

# test-remove.sh - Tests for gtr rm command

# Source the testing framework
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../test-helpers/test-utils.sh"
source "$SCRIPT_DIR/../test-helpers/mock-git.sh"

# Source the module under test
source "$SCRIPT_DIR/../lib/gtr-core.sh"
source "$SCRIPT_DIR/../lib/gtr-hooks.sh"
source "$SCRIPT_DIR/../lib/gtr-git.sh"
source "$SCRIPT_DIR/../lib/gtr-commands.sh"

setup_remove_test_env() {
  # Create a temporary test directory
  TEST_REPO_DIR=$(mktemp -d)
  cd "$TEST_REPO_DIR"

  # Initialize a git repo
  git init > /dev/null 2>&1
  git config user.name "Test User"
  git config user.email "test@example.com"

  # Add a fake remote to get a repo name
  git remote add origin https://github.com/test/test-repo.git

  # Create initial commit
  echo "initial" > README.md
  git add README.md
  git commit -m "Initial commit" > /dev/null 2>&1

  # Set up gtr config
  export _GTR_USERNAME="testuser"
  export GTR_BASE_DIR="$TEST_REPO_DIR/worktrees"
  mkdir -p "$GTR_BASE_DIR"
}

cleanup_remove_test_env() {
  cd "$SCRIPT_DIR"
  if [[ -n "$TEST_REPO_DIR" && -d "$TEST_REPO_DIR" ]]; then
    rm -rf "$TEST_REPO_DIR"
  fi
  unset _GTR_USERNAME
  unset GTR_BASE_DIR
  unset TEST_REPO_DIR
}

# Test removing worktree with diverged branch (should fail without --force)
test_remove_diverged_branch_no_force() {
  setup_remove_test_env

  # Create a worktree with changes
  local worktree_name="test-diverged"
  local worktree_path="$GTR_BASE_DIR/$worktree_name"
  local branch_name="worktrees/test-repo/testuser/$worktree_name"

  # Create worktree
  git worktree add -b "$branch_name" "$worktree_path" > /dev/null 2>&1

  # Add changes to make it diverge
  cd "$worktree_path"
  echo "test change" > test-file.txt
  git add test-file.txt
  git commit -m "Test commit" > /dev/null 2>&1

  # Go back to main repo
  cd "$TEST_REPO_DIR"

  # Set up global args for gtr_remove
  _GTR_ARGS=("$worktree_name")

  # Attempt to remove without force - should fail
  local output
  output=$(echo "n" | gtr_remove 2>&1)

  # Should not remove the worktree
  assert_file_exists "$worktree_path" "Worktree should still exist when branch has changes"
  assert_contains "$output" "Cannot remove worktree" "Should show error message"
  assert_contains "$output" "has changes" "Should mention branch has changes"
  assert_contains "$output" "Use --force" "Should suggest using --force"

  cleanup_remove_test_env
}

# Test removing worktree with diverged branch using --force (should succeed)
test_remove_diverged_branch_with_force() {
  setup_remove_test_env

  # Create a worktree with changes
  local worktree_name="test-diverged-force"
  local worktree_path="$GTR_BASE_DIR/$worktree_name"
  local branch_name="worktrees/test-repo/testuser/$worktree_name"

  # Create worktree
  git worktree add -b "$branch_name" "$worktree_path" > /dev/null 2>&1

  # Add changes to make it diverge
  cd "$worktree_path"
  echo "test change" > test-file.txt
  git add test-file.txt
  git commit -m "Test commit" > /dev/null 2>&1

  # Go back to main repo
  cd "$TEST_REPO_DIR"

  # Set up global args for gtr_remove with --force
  _GTR_ARGS=("$worktree_name" "--force")

  # Remove with force - should succeed
  local output
  output=$(gtr_remove 2>&1)

  # Worktree should be removed but branch should remain
  assert_file_not_exists "$worktree_path" "Worktree should be removed with --force"
  assert_contains "$output" "Removed worktree" "Should show success message"
  assert_contains "$output" "has changes. Not deleting" "Should keep diverged branch"

  # Branch should still exist
  local branch_exists
  branch_exists=$(git show-ref --verify --quiet "refs/heads/$branch_name" && echo "yes" || echo "no")
  assert_equals "yes" "$branch_exists" "Branch should still exist after forced removal"

  cleanup_remove_test_env
}

# Test removing worktree with clean branch (should succeed and offer to delete branch)
test_remove_clean_branch() {
  setup_remove_test_env

  # Create a worktree without changes
  local worktree_name="test-clean"
  local worktree_path="$GTR_BASE_DIR/$worktree_name"
  local branch_name="worktrees/test-repo/testuser/$worktree_name"

  # Create worktree (no additional commits)
  git worktree add -b "$branch_name" "$worktree_path" > /dev/null 2>&1

  # Set up global args for gtr_remove
  _GTR_ARGS=("$worktree_name")

  # Remove worktree (say no to branch deletion)
  local output
  output=$(echo "n" | gtr_remove 2>&1)

  # Worktree should be removed
  assert_file_not_exists "$worktree_path" "Worktree should be removed"
  assert_contains "$output" "Removed worktree" "Should show success message"
  assert_contains "$output" "Delete branch" "Should ask about deleting branch"
  assert_contains "$output" "no changes" "Should mention branch has no changes"

  # Branch should still exist (we said no)
  local branch_exists
  branch_exists=$(git show-ref --verify --quiet "refs/heads/$branch_name" && echo "yes" || echo "no")
  assert_equals "yes" "$branch_exists" "Branch should still exist when user says no"

  cleanup_remove_test_env
}

# Test removing worktree with diverged branch but identical content (squash merge scenario)
test_remove_diverged_but_squashed_branch() {
  setup_remove_test_env

  # Create a worktree with changes
  local worktree_name="test-squashed"
  local worktree_path="$GTR_BASE_DIR/$worktree_name"
  local branch_name="worktrees/test-repo/testuser/$worktree_name"

  # Create worktree
  git worktree add -b "$branch_name" "$worktree_path" > /dev/null 2>&1

  # Add changes to the worktree branch
  cd "$worktree_path"
  echo "feature implementation" > feature.txt
  git add feature.txt
  git commit -m "Add feature" > /dev/null 2>&1

  # Go back to main repo and simulate a squash merge by adding the same content
  cd "$TEST_REPO_DIR"
  echo "feature implementation" > feature.txt
  git add feature.txt
  git commit -m "Squash merge: Add feature" > /dev/null 2>&1

  # Now the branch has diverged but content is identical (squash merge scenario)

  # Set up global args for gtr_remove
  _GTR_ARGS=("$worktree_name")

  # Attempt to remove - should succeed because content is identical
  local output
  output=$(echo "n" | gtr_remove 2>&1)

  # Worktree should be removed because content is identical despite divergence
  assert_file_not_exists "$worktree_path" "Worktree should be removed when content is identical"
  assert_contains "$output" "Removed worktree" "Should show success message"
  assert_contains "$output" "diverged but content is identical" "Should detect squash merge scenario"
  assert_contains "$output" "likely squash merged" "Should mention squash merge"

  # Branch should still exist (we said no to deletion)
  local branch_exists
  branch_exists=$(git show-ref --verify --quiet "refs/heads/$branch_name" && echo "yes" || echo "no")
  assert_equals "yes" "$branch_exists" "Branch should still exist when user says no to deletion"

  cleanup_remove_test_env
}

# Test dry run mode for diverged but squashed branch
test_remove_squashed_branch_dry_run() {
  setup_remove_test_env

  # Create a worktree with changes
  local worktree_name="test-squashed-dry"
  local worktree_path="$GTR_BASE_DIR/$worktree_name"
  local branch_name="worktrees/test-repo/testuser/$worktree_name"

  # Create worktree
  git worktree add -b "$branch_name" "$worktree_path" > /dev/null 2>&1

  # Add changes to the worktree branch
  cd "$worktree_path"
  echo "feature implementation" > feature.txt
  git add feature.txt
  git commit -m "Add feature" > /dev/null 2>&1

  # Go back to main repo and simulate a squash merge by adding the same content
  cd "$TEST_REPO_DIR"
  echo "feature implementation" > feature.txt
  git add feature.txt
  git commit -m "Squash merge: Add feature" > /dev/null 2>&1

  # Set up global args for gtr_remove with --dry-run
  _GTR_ARGS=("$worktree_name" "--dry-run")

  # Run in dry-run mode
  local output
  output=$(gtr_remove 2>&1)

  # Nothing should actually be removed
  assert_file_exists "$worktree_path" "Worktree should still exist in dry run"
  assert_contains "$output" "DRY RUN" "Should show dry run message"
  assert_contains "$output" "Would delete branch" "Should show it would delete branch"
  assert_contains "$output" "diverged but content identical" "Should detect squash merge scenario in dry run"
  assert_contains "$output" "likely squash merged" "Should mention squash merge in dry run"

  cleanup_remove_test_env
}

# Test dry run mode
test_remove_dry_run() {
  setup_remove_test_env

  # Create a worktree with changes
  local worktree_name="test-dry-run"
  local worktree_path="$GTR_BASE_DIR/$worktree_name"
  local branch_name="worktrees/test-repo/testuser/$worktree_name"

  # Create worktree
  git worktree add -b "$branch_name" "$worktree_path" > /dev/null 2>&1

  # Add changes
  cd "$worktree_path"
  echo "test change" > test-file.txt
  git add test-file.txt
  git commit -m "Test commit" > /dev/null 2>&1

  # Go back to main repo
  cd "$TEST_REPO_DIR"

  # Set up global args for gtr_remove with --dry-run
  _GTR_ARGS=("$worktree_name" "--dry-run")

  # Run in dry-run mode
  local output
  output=$(gtr_remove 2>&1)

  # Nothing should actually be removed
  assert_file_exists "$worktree_path" "Worktree should still exist in dry run"
  assert_contains "$output" "DRY RUN" "Should show dry run message"
  assert_contains "$output" "Would skip deletion" "Should show it would skip deletion"
  assert_contains "$output" "has changes" "Should mention branch has changes"

  cleanup_remove_test_env
}

# Run all tests
run_remove_tests() {
  init_test_suite "Remove Command"

  register_test "test_remove_diverged_branch_no_force" "test_remove_diverged_branch_no_force"
  register_test "test_remove_diverged_branch_with_force" "test_remove_diverged_branch_with_force"
  register_test "test_remove_clean_branch" "test_remove_clean_branch"
  register_test "test_remove_diverged_but_squashed_branch" "test_remove_diverged_but_squashed_branch"
  register_test "test_remove_squashed_branch_dry_run" "test_remove_squashed_branch_dry_run"
  register_test "test_remove_dry_run" "test_remove_dry_run"

  finish_test_suite
}

# Allow running this script directly or being called by test runner
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  run_remove_tests
fi