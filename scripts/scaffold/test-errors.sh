#!/usr/bin/env bash
# Tests: error handling, exit codes, error messages
source "$(dirname "$0")/helpers.sh"
check_dog

echo "Error handling:"

# Missing file — exit code 1
"$DOG" nonexistent.swift 2>/dev/null; EXIT=$?
[[ $EXIT -eq 1 ]] && pass "missing file exits code 1" || fail "missing file exits code $EXIT (expected 1)"

# Missing file — error message
MSG=$("$DOG" nonexistent.swift 2>&1 || true)
echo "$MSG" | grep -q "file not found" && pass "error says 'file not found'" || fail "error message (got: $MSG)"

# Error format — [error] prefix
echo "$MSG" | grep -q "\[error\]" && pass "error has [error] prefix" || fail "error format (got: $MSG)"

# Error piped — no ANSI codes
PIPED=$("$DOG" nonexistent.swift 2>&1 | cat -v || true)
echo "$PIPED" | grep -q '\^\[' && fail "piped error has ANSI codes" || pass "piped error has no ANSI"

# Bad flag — exit code 2 (ArgumentParser handles this)
"$DOG" --fakeflag 2>/dev/null; EXIT=$?
[[ $EXIT -ne 0 ]] && pass "bad flag exits non-zero" || fail "bad flag should exit non-zero"

summary
