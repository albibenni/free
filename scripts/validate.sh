#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo "🔍 Running pre-commit checks..."

# 1. Check for build errors
echo "🔨 Verifying build..."
# We redirect output to a log file to keep the terminal clean, but show errors if they happen
if ./build.sh > .build_log 2>&1; then
    echo "  ✅ Build passed"
    rm .build_log
else
    echo -e "  ❌ ${RED}Build failed!${NC}"
    cat .build_log
    rm .build_log
    exit 1
fi

# 2. Run unit tests
echo "🧪 Running unit tests..."
if swift test --quiet; then
    echo "  ✅ Tests passed"
else
    echo -e "  ❌ ${RED}Tests failed!${NC}"
    # Run again without quiet to show why it failed
    swift test
    exit 1
fi

echo -e "🚀 ${GREEN}All checks passed!${NC}"
