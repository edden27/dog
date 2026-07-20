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

# CRLF input: \r is part of the line terminator, must not reach the output
CRLF_OUT=$(printf 'let x = 1\r\nlet y = 2\r\n' | "$DOG" -l swift 2>/dev/null)
[[ "$CRLF_OUT" == $'let x = 1\nlet y = 2' ]] && pass "CRLF input: \\r stripped" || fail "CRLF input: \\r stripped (got: $(printf '%s' "$CRLF_OUT" | cat -v))"

# CRLF with colors: no raw \r byte anywhere in the ANSI stream
CRLF_ANSI=$(printf 'let x = 1\r\n// hi\r\n' | "$DOG" -l swift --color=always 2>/dev/null)
if printf '%s' "$CRLF_ANSI" | LC_ALL=C grep -q "$(printf '\r')"; then
    fail "CRLF colored output contains raw \\r"
else
    pass "CRLF colored output contains no \\r"
fi

summary
