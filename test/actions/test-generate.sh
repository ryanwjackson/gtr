#!/bin/bash

# test-generate.sh - Tests for gtr generate command functionality

# Source the testing framework
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../helpers/test-utils.sh"

# Source the modules under test
source "$SCRIPT_DIR/../../lib/gtr-core.sh"
source "$SCRIPT_DIR/../../lib/gtr-ui.sh"
source "$SCRIPT_DIR/../../lib/gtr-config.sh"
source "$SCRIPT_DIR/../../lib/gtr-files.sh"
source "$SCRIPT_DIR/../../lib/gtr-hooks.sh"
source "$SCRIPT_DIR/../../lib/gtr-git.sh"
source "$SCRIPT_DIR/../../lib/gtr-commands.sh"

# Test generate command help
test_gtr_generate_help() {
  local result
  result=$(run_gtr_test generate 2>&1) || true

  assert_contains "$result" "generate" "Help should contain 'generate'"
  assert_contains "$result" "hook" "Help should contain 'hook' subcommand"
  assert_not_empty "$result" "Help should produce output"
}

# Test generate hook basic functionality (with simulated input)
test_gtr_generate_hook_basic() {
  # Create temporary test directory
  local test_dir
  test_dir=$(mktemp -d)

  cd "$test_dir" || return 1
  git init >/dev/null 2>&1

  # Initialize gtr config
  _GTR_ARGS=()
  gtr_init >/dev/null 2>&1

  # Simulate user input: select scope 1 (local), then hook #1 (pre-create)
  local result
  result=$(echo -e "1\n1" | _gtr_generate_hook 2>&1)
  local exit_code=$?

  assert_equals "0" "$exit_code" "Generate hook should succeed"
  assert_contains "$result" "pre-create" "Should indicate pre-create hook generation"
  assert_contains "$result" "Hook created" "Should confirm hook creation"

  # Verify hook file was created
  assert_file_exists "$test_dir/.gtr/hooks/pre-create" "Hook file should be created"

  # Verify hook is executable
  if [[ -f "$test_dir/.gtr/hooks/pre-create" ]]; then
    if [[ -x "$test_dir/.gtr/hooks/pre-create" ]]; then
      echo "✓ Hook is executable"
    else
      fail "Hook file should be executable"
    fi
  fi

  # Cleanup
  cd /
  rm -rf "$test_dir"
}

# Test generate hook with existing hook (abort)
test_gtr_generate_hook_existing_abort() {
  local test_dir
  test_dir=$(mktemp -d)

  cd "$test_dir" || return 1
  git init >/dev/null 2>&1

  # Initialize gtr config
  _GTR_ARGS=()
  gtr_init >/dev/null 2>&1

  # Create initial hook (scope 1=local, hook 1=pre-create)
  echo -e "1\n1" | _gtr_generate_hook >/dev/null 2>&1

  # Try to generate same hook again with abort response (scope 1, hook 1, decline overwrite)
  local result
  result=$(echo -e "1\n1\nN" | _gtr_generate_hook 2>&1)

  assert_contains "$result" "already exists" "Should detect existing hook"
  assert_contains "$result" "Aborted" "Should abort when user declines overwrite"

  # Cleanup
  cd /
  rm -rf "$test_dir"
}

# Test generate hook with existing hook (overwrite)
test_gtr_generate_hook_existing_overwrite() {
  local test_dir
  test_dir=$(mktemp -d)

  cd "$test_dir" || return 1
  git init >/dev/null 2>&1

  # Initialize gtr config
  _GTR_ARGS=()
  gtr_init >/dev/null 2>&1

  # Create initial hook with custom content
  mkdir -p "$test_dir/.gtr/hooks"
  echo "#!/bin/bash" > "$test_dir/.gtr/hooks/post-create"
  echo "echo OLD HOOK" >> "$test_dir/.gtr/hooks/post-create"
  chmod +x "$test_dir/.gtr/hooks/post-create"

  # Overwrite with new hook (scope 1=local, hook 2=post-create, confirm overwrite)
  local result
  result=$(echo -e "1\n2\ny" | _gtr_generate_hook 2>&1)

  assert_contains "$result" "already exists" "Should detect existing hook"
  assert_contains "$result" "Hook created" "Should confirm hook creation after overwrite"

  # Verify new content
  local hook_content
  hook_content=$(cat "$test_dir/.gtr/hooks/post-create")
  assert_contains "$hook_content" "post-create hook" "Hook should have new template content"
  assert_not_contains "$hook_content" "OLD HOOK" "Old content should be replaced"

  # Cleanup
  cd /
  rm -rf "$test_dir"
}

# Test generate hook template variables
test_gtr_generate_hook_template_vars() {
  local test_dir
  test_dir=$(mktemp -d)

  cd "$test_dir" || return 1
  git init >/dev/null 2>&1

  # Initialize gtr config
  _GTR_ARGS=()
  gtr_init >/dev/null 2>&1

  # Generate pre-remove hook (scope 1=local, hook 3=pre-remove, has different vars than pre-create)
  echo -e "1\n3" | _gtr_generate_hook >/dev/null 2>&1

  # Verify hook contains expected variables
  local hook_content
  hook_content=$(cat "$test_dir/.gtr/hooks/pre-remove")

  assert_contains "$hook_content" "WORKTREE_NAME" "Hook should define WORKTREE_NAME"
  assert_contains "$hook_content" "WORKTREE_PATH" "Hook should define WORKTREE_PATH"
  assert_contains "$hook_content" "BRANCH_NAME" "Hook should define BRANCH_NAME"
  assert_contains "$hook_content" "FORCE" "Hook should define FORCE"
  assert_contains "$hook_content" "DRY_RUN" "Hook should define DRY_RUN"
  assert_contains "$hook_content" "pre-remove hook" "Hook should reference hook name"

  # Cleanup
  cd /
  rm -rf "$test_dir"
}

# Test generate hook invalid selection
test_gtr_generate_hook_invalid_selection() {
  local test_dir
  test_dir=$(mktemp -d)

  cd "$test_dir" || return 1
  git init >/dev/null 2>&1

  # Initialize gtr config
  _GTR_ARGS=()
  gtr_init >/dev/null 2>&1

  # Try invalid selections
  local result
  result=$(echo -e "1\n99" | _gtr_generate_hook 2>&1) || true
  assert_contains "$result" "Invalid selection" "Should reject out of range selection"

  result=$(echo -e "1\nabc" | _gtr_generate_hook 2>&1) || true
  assert_contains "$result" "Invalid selection" "Should reject non-numeric selection"

  # Cleanup
  cd /
  rm -rf "$test_dir"
}

# Test all hook types can be generated
test_gtr_generate_all_hook_types() {
  local test_dir
  test_dir=$(mktemp -d)

  cd "$test_dir" || return 1
  git init >/dev/null 2>&1

  # Initialize gtr config
  _GTR_ARGS=()
  gtr_init >/dev/null 2>&1

  # Generate each hook type (all local scope)
  local hook_names=("pre-create" "post-create" "pre-remove" "post-remove" "pre-prune" "post-prune")

  for i in {1..6}; do
    echo -e "1\n$i" | _gtr_generate_hook >/dev/null 2>&1
    local hook_name="${hook_names[$((i-1))]}"
    assert_file_exists "$test_dir/.gtr/hooks/$hook_name" "Hook $hook_name should be created"
  done

  # Cleanup
  cd /
  rm -rf "$test_dir"
}

# Main function to run all tests
main() {
  init_test_suite "Generate Command Tests"

  register_test "gtr_generate_help" test_gtr_generate_help
  register_test "gtr_generate_hook_basic" test_gtr_generate_hook_basic
  register_test "gtr_generate_hook_existing_abort" test_gtr_generate_hook_existing_abort
  register_test "gtr_generate_hook_existing_overwrite" test_gtr_generate_hook_existing_overwrite
  register_test "gtr_generate_hook_template_vars" test_gtr_generate_hook_template_vars
  register_test "gtr_generate_hook_invalid_selection" test_gtr_generate_hook_invalid_selection
  register_test "gtr_generate_all_hook_types" test_gtr_generate_all_hook_types

  finish_test_suite
}

# Run main if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
