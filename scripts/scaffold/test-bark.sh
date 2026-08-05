#!/usr/bin/env bash
# Tests: Bark logger behavior (debug vs release builds)
source "$(dirname "$0")/helpers.sh"

echo "Bark logger:"

# Release build should have NO debug log output
# Build release if not already built
RELEASE_DOG="$PROJECT_ROOT/.build/release/dog"
if [[ ! -x "$RELEASE_DOG" ]]; then
  echo "  building release..."
  (cd "$PROJECT_ROOT" && swift build -c release 2>&1 | tail -1)
fi

if [[ -x "$RELEASE_DOG" ]]; then
  # Release: --range triggers Bark.warning() in debug, should be silent in release
  RELEASE_ERR=$("$RELEASE_DOG" --range 1:10 "$FIXTURE" 2>&1 >/dev/null || true)
  echo "$RELEASE_ERR" | grep -qi "warn\|debug\|info\|not yet" && fail "release build has log output" || pass "release build has no log output"
else
  fail "release binary not found"
fi

# Debug build should show log output when DOG_LOG_LEVEL=debug
DEBUG_DOG="$DOG"
if [[ -x "$DEBUG_DOG" ]]; then
  # --range triggers Bark.warning() — should appear on stderr in debug
  DEBUG_ERR=$(DOG_LOG_LEVEL=debug "$DEBUG_DOG" --range 1:10 "$FIXTURE" 2>&1 >/dev/null || true)
  echo "$DEBUG_ERR" | grep -q "not yet implemented" && pass "debug build shows Bark.warning" || fail "debug build Bark.warning missing: $DEBUG_ERR"

  # Verify log output goes to stderr, not stdout
  # grep for "[warn]" prefix specifically — jquery.js contains "warn" in source
  DEBUG_STDOUT=$(DOG_LOG_LEVEL=debug "$DEBUG_DOG" --range 1:10 "$FIXTURE" 2>/dev/null | grep -c "\[warn\]" || true)
  [[ "$DEBUG_STDOUT" -eq 0 ]] && pass "log output on stderr not stdout" || fail "log output leaked to stdout"
else
  fail "debug binary not found"
fi

summary
