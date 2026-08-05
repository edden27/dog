#!/usr/bin/env bash
# Tests: ANSIOutput produces correct byte sequences
# Uses cat -v (portable) instead of xxd (format differs macOS vs Linux)
source "$(dirname "$0")/helpers.sh"
check_dog

echo "ANSIOutput byte correctness:"

# --color=always forces ANSI even in pipe, so we can inspect
# cat -v renders ESC as ^[ — grep for that
WOOF=$("$DOG" --color=always --woof 2>/dev/null | cat -v)

# Check for ANSI color escape: ^[[38;2;222;117;71m (UtilityDark keyword orange)
echo "$WOOF" | grep -q '\^\[' && pass "color() emits ANSI escape" || fail "color() ANSI escape"

# Check for reset sequence: ^[[0m
echo "$WOOF" | grep -q '\^\[\[0m' && pass "reset() emits ESC[0m" || fail "reset() ESC[0m"

# Check text content is present — pipe known source through so the expected
# text is controlled by the test, not by the embedded snippet. -p drops the
# gutter: its │ renders as bytes BSD grep refuses to match past.
CONTENT=$(echo 'let woofTest = 1' | "$DOG" -l swift --color=always -p 2>/dev/null | cat -v)
echo "$CONTENT" | grep -q "woofTest" && pass "text() emits content" || fail "text() content"

# --color=never: verify zero ESC bytes in output
NEVER=$("$DOG" --color=never --woof 2>/dev/null | cat -v)
echo "$NEVER" | grep -q '\^\[' && fail "enabled=false still has ESC" || pass "enabled=false emits no ESC"

# Verify --list-themes with --color=always has ANSI codes
THEMES=$("$DOG" --color=always --list-themes 2>/dev/null | cat -v)
echo "$THEMES" | grep -q '\^\[' && pass "list-themes with color=always has ANSI" || fail "list-themes color=always"

summary
