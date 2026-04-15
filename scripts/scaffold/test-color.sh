#!/usr/bin/env bash
# Tests: TTY detection, --color flag, NO_COLOR, FORCE_COLOR, pipe behavior
source "$(dirname "$0")/helpers.sh"
check_dog

echo "Color / TTY detection:"

# Piped output strips ANSI
PIPED=$("$DOG" --woof 2>/dev/null | cat -v)
echo "$PIPED" | grep -q '\^\[' && fail "piped strips ANSI" || pass "piped strips ANSI"

# --color=always forces ANSI in pipe
ALWAYS=$("$DOG" --color=always --woof 2>/dev/null | cat -v)
echo "$ALWAYS" | grep -q '\^\[' && pass "--color=always forces ANSI" || fail "--color=always forces ANSI"

# --color=never strips ANSI
NEVER=$("$DOG" --color=never --woof 2>/dev/null | cat -v)
echo "$NEVER" | grep -q '\^\[' && fail "--color=never strips ANSI" || pass "--color=never strips ANSI"

# NO_COLOR env var strips ANSI
NOCOLOR=$(NO_COLOR=1 "$DOG" --woof 2>/dev/null | cat -v)
echo "$NOCOLOR" | grep -q '\^\[' && fail "NO_COLOR=1 strips ANSI" || pass "NO_COLOR=1 strips ANSI"

# FORCE_COLOR overrides NO_COLOR
FORCE=$(FORCE_COLOR=1 NO_COLOR=1 "$DOG" --woof 2>/dev/null | cat -v)
echo "$FORCE" | grep -q '\^\[' && pass "FORCE_COLOR overrides NO_COLOR" || fail "FORCE_COLOR overrides NO_COLOR"

# --color=never with file — no ANSI in output
FILE_NEVER=$("$DOG" --color=never "$FIXTURE" 2>/dev/null | cat -v | head -5)
echo "$FILE_NEVER" | grep -q '\^\[' && fail "--color=never strips file ANSI" || pass "--color=never strips file ANSI"

summary
