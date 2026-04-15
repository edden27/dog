#!/usr/bin/env bash
# Tests: SIGPIPE handling — piping to head should not crash
source "$(dirname "$0")/helpers.sh"
check_dog

echo "SIGPIPE handling:"

# Pipe large file through head — should exit cleanly, no "broken pipe" error
STDERR=$("$DOG" "$FIXTURE" 2>&1 1>/dev/null | head -1)
# If SIGPIPE isn't handled, we'd see "broken pipe" or a crash message
# Run it properly: dog outputs to head, capture stderr separately
PIPE_ERR=$( { "$DOG" "$FIXTURE" | head -1 > /dev/null; } 2>&1 )
PIPE_EXIT=${PIPESTATUS[0]:-$?}

# No error output on stderr
[[ -z "$PIPE_ERR" ]] && pass "no stderr on pipe to head" || fail "stderr on pipe: $PIPE_ERR"

# head -5 with a large file
PIPE_OUT=$("$DOG" "$FIXTURE" | head -5 | wc -l | tr -d ' ')
[[ "$PIPE_OUT" -eq 5 ]] && pass "head -5 gets 5 lines" || fail "head -5 got $PIPE_OUT lines"

# Pipe to grep — should work without broken pipe
GREP_OUT=$("$DOG" "$FIXTURE" | grep -c "function" 2>/dev/null)
[[ "$GREP_OUT" -gt 0 ]] && pass "pipe to grep works ($GREP_OUT matches)" || fail "pipe to grep"

summary
