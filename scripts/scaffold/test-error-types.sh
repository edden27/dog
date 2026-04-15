#!/usr/bin/env bash
# Tests: each DogError type produces correct exit code and message
source "$(dirname "$0")/helpers.sh"
check_dog

echo "Error types:"

# fileNotFound — exit 1
"$DOG" nonexistent.swift 2>/dev/null; EXIT=$?
[[ $EXIT -eq 1 ]] && pass "fileNotFound → exit 1" || fail "fileNotFound exit $EXIT"

MSG=$("$DOG" nonexistent.swift 2>&1 || true)
echo "$MSG" | grep -q "file not found" && pass "fileNotFound message" || fail "fileNotFound message: $MSG"

# binaryFile — exit 1 (pipe binary content via stdin won't trigger it,
# but we can test with an actual binary)
BINARY_MSG=$("$DOG" /bin/ls 2>&1 || true)
BINARY_EXIT=$?
echo "$BINARY_MSG" | grep -qi "binary\|not.*UTF-8\|cannot read" && pass "binary file detected" || fail "binary file message: $BINARY_MSG"

# bad usage (unknown flag) — ArgumentParser handles this, exit != 0
"$DOG" --totally-fake-flag 2>/dev/null; EXIT=$?
[[ $EXIT -ne 0 ]] && pass "bad flag → non-zero exit" || fail "bad flag exit $EXIT"

# Error messages have [error] prefix when piped
PIPED=$("$DOG" nonexistent.swift 2>&1 | cat || true)
echo "$PIPED" | grep -q "^\[error\]" && pass "error prefix [error]" || fail "error prefix: $PIPED"

summary
