#!/bin/bash

# Test script to verify if stashed changes appear in the new worktree

set -e

# Create temp directory
TEST_DIR=$(mktemp -d -t gtr-worktree-test-XXXXXX)
echo "Test directory: $TEST_DIR"

cd "$TEST_DIR"

# Initialize git repo
git init
git config user.name "Test User"
git config user.email "test@example.com"

# Create initial commit
echo "initial content" > README.md
git add README.md
git commit -m "Initial commit"

# Create uncommitted changes
echo "staged content" > staged-file.txt
echo "modified content" >> README.md
echo "untracked content" > untracked-file.txt

# Stage one file
git add staged-file.txt

echo "=== Git Status Before ==="
git status --porcelain

echo "=== Creating Worktree with Stashing ==="
GTR_PATH="/Users/ryanwjackson/Documents/dev/worktrees/gtr/stash-on-create/bin/gtr"
$GTR_PATH --git-root="$TEST_DIR" create test-worktree --uncommitted=true --no-open

echo "=== Git Status in Main Repo After ==="
git status --porcelain

echo "=== Stash List ==="
git stash list

echo "=== Content in New Worktree ==="
# Find the actual worktree directory
WORKTREE_DIR=$(find "/Users/ryanwjackson/Documents/dev/worktrees/gtr*" -name "*test-worktree*" -type d 2>/dev/null | head -1)
echo "Looking for worktree in: $WORKTREE_DIR"

if [[ -d "$WORKTREE_DIR" ]]; then
    echo "Files in worktree:"
    ls -la "$WORKTREE_DIR"

    echo "Git status in worktree:"
    cd "$WORKTREE_DIR"
    git status --porcelain

    echo "Content of files in worktree:"
    if [[ -f "README.md" ]]; then
        echo "README.md content:"
        cat README.md
    fi

    if [[ -f "staged-file.txt" ]]; then
        echo "staged-file.txt content:"
        cat staged-file.txt
    else
        echo "staged-file.txt: NOT FOUND"
    fi

    if [[ -f "untracked-file.txt" ]]; then
        echo "untracked-file.txt content:"
        cat untracked-file.txt
    else
        echo "untracked-file.txt: NOT FOUND"
    fi
else
    echo "Worktree directory not found!"
fi

# Cleanup
cd /
rm -rf "$TEST_DIR"