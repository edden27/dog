#!/usr/bin/env bash
# Run all scaffold tests
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TOTAL_PASS=0
TOTAL_FAIL=0

# UtilityDark palette
ORANGE='\033[38;2;222;117;71m'    # #DE7547 — keyword
GREEN='\033[38;2;136;169;141m'    # #88A98D — function
RED='\033[38;2;204;67;61m'        # #CC433D — regexp/error
BOLD='\033[1m'
RESET='\033[0m'

echo ""
echo -e "${ORANGE}━━━ dog test suite ━━━${RESET}"
echo ""

FAILED_SUITES=()

# Swift unit tests
echo "Swift unit tests:"
if (cd "$PROJECT_ROOT" && swift test 2>&1 | tail -1 | grep -q "passed"); then
    SWIFT_RESULT=$(cd "$PROJECT_ROOT" && swift test 2>&1 | tail -1)
    echo -e "  ${GREEN}✓${RESET} $SWIFT_RESULT"
    TOTAL_PASS=$((TOTAL_PASS + 1))
else
    echo -e "  ${RED}✗${RESET} swift test failed"
    TOTAL_FAIL=$((TOTAL_FAIL + 1))
    FAILED_SUITES+=("swift-test")
fi
echo ""

for test in "$SCRIPT_DIR"/test-*.sh; do
    bash "$test"
    EXIT=$?
    echo ""
    if [[ $EXIT -ne 0 ]]; then
        TOTAL_FAIL=$((TOTAL_FAIL + 1))
        FAILED_SUITES+=("$(basename "$test")")
    else
        TOTAL_PASS=$((TOTAL_PASS + 1))
    fi
done

echo -e "${ORANGE}━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "  Test suites: ${GREEN}$TOTAL_PASS passed${RESET}, $TOTAL_FAIL failed"
if [[ $TOTAL_FAIL -gt 0 ]]; then
    for suite in "${FAILED_SUITES[@]}"; do
        echo -e "  ${RED}FAILED: $suite${RESET}"
    done
    exit 1
else
    echo -e "  ${GREEN}All suites passed!${RESET}"
fi
echo ""
