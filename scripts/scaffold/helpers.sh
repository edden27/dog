#!/usr/bin/env bash
# Shared test helpers — sourced by each test file

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
FIXTURE="$PROJECT_ROOT/scripts/fixtures/jquery.js"

# Find the dog binary — check DOG_BIN env var first (set by linux-test.sh),
# then the standard macOS debug path
if [[ -n "${DOG_BIN:-}" ]] && [[ -x "$DOG_BIN" ]]; then
    DOG="$DOG_BIN"
elif [[ -x "$PROJECT_ROOT/.build/debug/dog" ]]; then
    DOG="$PROJECT_ROOT/.build/debug/dog"
else
    echo "dog binary not found — set DOG_BIN or run 'swift build' first"
    exit 1
fi

# UtilityDark palette
GREEN='\033[38;2;136;169;141m'    # #88A98D — function
RED='\033[38;2;204;67;61m'        # #CC433D — regexp/error
YELLOW='\033[38;2;222;169;99m'    # #DEA963 — type/warning
RESET='\033[0m'

PASS=0
FAIL=0

pass() {
    PASS=$((PASS + 1))
    echo -e "  ${GREEN}✓${RESET} $1"
}

fail() {
    FAIL=$((FAIL + 1))
    echo -e "  ${RED}✗${RESET} $1"
}

summary() {
    echo ""
    TOTAL=$((PASS + FAIL))
    if [[ $FAIL -gt 0 ]]; then
        echo -e "  ${GREEN}$PASS${RESET}/${TOTAL} passed, ${RED}$FAIL FAILED${RESET}"
        return 1
    else
        echo -e "  ${GREEN}$PASS/$TOTAL passed${RESET}"
    fi
}

check_dog() {
    if [[ ! -x "$DOG" ]]; then
        echo "dog binary not found at $DOG — run 'swift build' first"
        exit 1
    fi
}
