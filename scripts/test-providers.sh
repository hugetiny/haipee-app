#!/bin/bash
# API Provider E2E Test Script
# Usage: ./scripts/test-providers.sh [provider-name|all]

set -e

cd "$(dirname "$0")/.."

echo "🧪 Haipee API Provider E2E Tests"
echo "================================"
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to run test
run_test() {
    local provider=$1
    local spec_file="tests/e2e/providers/${provider}.spec.ts"

    if [ ! -f "$spec_file" ]; then
        echo -e "${RED}❌ Test file not found: $spec_file${NC}"
        return 1
    fi

    echo "📝 Testing $provider..."
    if npx playwright test "$spec_file" --project=chromium --reporter=line 2>&1; then
        echo -e "${GREEN}✅ $provider passed${NC}"
        return 0
    else
        echo -e "${RED}❌ $provider failed${NC}"
        return 1
    fi
}

# Main
PROVIDER=${1:-all}

if [ "$PROVIDER" = "all" ]; then
    echo "Running all provider tests..."
    echo ""

    # List of providers
    providers=(
        "gemini"
        "nvidia"
        "openai"
        "opencode"
        "cloudflare"
        "kilo"
        "xiaomimino"
        "huawei"
        "poe"
    )

    passed=0
    failed=0
    skipped=0

    for provider in "${providers[@]}"; do
        if run_test "$provider"; then
            ((passed++))
        else
            ((failed++))
        fi
        echo ""
    done

    echo "================================"
    echo "📊 Test Summary"
    echo "================================"
    echo -e "${GREEN}✅ Passed: $passed${NC}"
    echo -e "${RED}❌ Failed: $failed${NC}"
    echo "================================"

    if [ $failed -eq 0 ]; then
        echo -e "${GREEN}🎉 All tests passed!${NC}"
        exit 0
    else
        echo -e "${RED}⚠️ Some tests failed${NC}"
        exit 1
    fi
else
    # Test single provider
    run_test "$PROVIDER"
fi
