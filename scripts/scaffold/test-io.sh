#!/usr/bin/env bash
# Tests: file reading, stdin, version
source "$(dirname "$0")/helpers.sh"
check_dog

echo "File reading + stdin:"

# Version
"$DOG" --version 2>&1 | grep -qE "^[0-9]+\.[0-9]+\.[0-9]+$" && pass "--version prints semver" || fail "--version prints semver"

# Read a file
LINE_COUNT=$("$DOG" "$FIXTURE" 2>/dev/null | wc -l | tr -d ' ')
[[ "$LINE_COUNT" -eq 10716 ]] && pass "reads jquery.js (10716 lines)" || fail "reads jquery.js (got $LINE_COUNT)"

# Read from stdin
STDIN_OUT=$(echo "let x = 1" | "$DOG" 2>/dev/null)
[[ "$STDIN_OUT" == "let x = 1" ]] && pass "reads from stdin" || fail "reads from stdin (got: $STDIN_OUT)"

# Multi-line stdin
MULTI=$(printf "line1\nline2\nline3\n" | "$DOG" 2>/dev/null | wc -l | tr -d ' ')
[[ "$MULTI" -eq 3 ]] && pass "multi-line stdin (3 lines)" || fail "multi-line stdin (got $MULTI)"

summary
