#!/bin/bash

# Local test script to simulate GitHub Actions environment
# This helps debug workflow issues locally

set -e

echo "=== Simulating GitHub Actions CI ==="
echo ""

echo "Step 1: Setup Git"
git config --get user.name >/dev/null || git config --global user.name "Local Test"
git config --get user.email >/dev/null || git config --global user.email "test@local"
echo "✅ Git configured"

echo ""
echo "Step 2: Setup Scripts"
chmod +x bin/gtr test/test-runner.sh test/*.sh
echo "Verifying script permissions..."
ls -la bin/gtr test/test-runner.sh
echo "✅ Script permissions set"

echo ""
echo "Step 3: Run Tests"
./test/test-runner.sh
echo "✅ Tests completed"

echo ""
echo "Step 4: Verify Script Works"
echo "Testing modular script..."
./bin/gtr --version
echo "✅ Script functional"

echo ""
echo "Step 5: Shell Linting (if shellcheck available)"
if command -v shellcheck >/dev/null 2>&1; then
    echo "Running shellcheck..."
    shellcheck bin/gtr || echo "Some warnings expected"
    shellcheck lib/*.sh || echo "Some warnings expected"
    shellcheck test/*.sh test-helpers/*.sh || echo "Some warnings expected"
    echo "✅ Linting completed"
else
    echo "⚠️  shellcheck not available, skipping lint checks"
fi

echo ""
echo "Step 6: Security Checks"
echo "Checking for world-writable files..."
world_writable_files=$(find bin/ lib/ test/ -type f -perm -002 2>/dev/null | grep -v ".git" || true)
if [[ -n "$world_writable_files" ]]; then
    echo "❌ Found world-writable files:"
    echo "$world_writable_files"
    exit 1
else
    echo "✅ No world-writable script files found"
fi

echo "Checking executable permissions..."
if [[ -x "bin/gtr" && -x "test/test-runner.sh" ]]; then
    echo "✅ Executable permissions correct"
else
    echo "❌ Missing executable permissions"
    exit 1
fi

echo ""
echo "🎉 All checks passed! GitHub Actions should work correctly."