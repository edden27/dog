#!/usr/bin/env bash
#
# Pillar 3: Compatibility scenarios from KPIs doc.
# 13 scenarios that must all pass for dog to be a drop-in bat replacement.
#
# Usage:
#   ./tests/scripts/compat.sh

set -uo pipefail

START_TIME=$SECONDS

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
FIXTURE="$PROJECT_ROOT/scripts/fixtures/jquery.js"

# Find dog binary
if [[ -n "${DOG_BIN:-}" ]] && [[ -x "$DOG_BIN" ]]; then
    DOG="$DOG_BIN"
elif [[ -x "$PROJECT_ROOT/.build/debug/dog" ]]; then
    DOG="$PROJECT_ROOT/.build/debug/dog"
else
    echo "dog binary not found — set DOG_BIN or run 'swift build'"
    exit 1
fi

# UtilityDark palette — explicit RGB only
G='\033[38;2;136;169;141m'
R='\033[38;2;204;67;61m'
Y='\033[38;2;222;169;99m'
W='\033[38;2;255;241;224m'
B='\033[38;2;208;189;169m'
Z='\033[0m'

PASS_COUNT=0
FAIL_COUNT=0
LINES=()
FAIL_DETAILS=()

pass() {
    PASS_COUNT=$((PASS_COUNT + 1))
    LINES+=("    ${G}✓${Z} ${B}$1${Z}")
}

fail() {
    FAIL_COUNT=$((FAIL_COUNT + 1))
    LINES+=("    ${R}✗${Z} ${B}$1${Z}")
    FAIL_DETAILS+=("$1")
}

if [[ ! -x "$DOG" ]]; then
    echo "dog binary not found at $DOG — run 'swift build' in cli/ first"
    exit 1
fi

# 1. Pipe strips color
PIPED_AUTO=$("$DOG" --woof 2>/dev/null | cat -v)
echo "$PIPED_AUTO" | grep -q '\^\[' && fail "pipe strips color" || pass "pipe strips color"

# 2. --color=always in pipe
ALWAYS=$("$DOG" --color=always --woof 2>/dev/null | cat -v)
echo "$ALWAYS" | grep -q '\^\[' && pass "--color=always forces color in pipe" || fail "--color=always forces color in pipe"

# 3. NO_COLOR env
NOCOLOR=$(NO_COLOR=1 "$DOG" --woof 2>/dev/null | cat -v)
echo "$NOCOLOR" | grep -q '\^\[' && fail "NO_COLOR strips color" || pass "NO_COLOR strips color"

# 4. FORCE_COLOR overrides NO_COLOR
FORCE=$(FORCE_COLOR=1 NO_COLOR=1 "$DOG" --woof 2>/dev/null | cat -v)
echo "$FORCE" | grep -q '\^\[' && pass "FORCE_COLOR overrides NO_COLOR" || fail "FORCE_COLOR overrides NO_COLOR"

# 5. File not found
"$DOG" nonexistent.swift 2>/dev/null; EXIT=$?
[[ $EXIT -eq 1 ]] && pass "file not found exits 1" || fail "file not found exits $EXIT"

# 6. Bad language flag
"$DOG" -l fakeLang "$FIXTURE" 2>/dev/null; EXIT=$?
[[ $EXIT -ne 0 ]] && pass "bad language exits non-zero" || fail "bad language exits $EXIT"

# 7. stdin with language
STDIN_OUT=$(echo "let x = 1" | "$DOG" -l swift 2>/dev/null)
[[ -n "$STDIN_OUT" ]] && pass "stdin with -l swift" || fail "stdin with -l swift"

# 8. stdin no language
STDIN_PLAIN=$(echo "let x = 1" | "$DOG" 2>/dev/null)
[[ "$STDIN_PLAIN" == "let x = 1" ]] && pass "stdin no language passthrough" || fail "stdin no language"

# 9. Binary file
BINARY_MSG=$("$DOG" /bin/ls 2>&1 || true)
echo "$BINARY_MSG" | grep -qi "binary\|not.*UTF-8\|cannot read" && pass "binary file clear message" || fail "binary file message: $BINARY_MSG"

# 10. Empty file
EMPTY_TMP=$(mktemp)
"$DOG" "$EMPTY_TMP" 2>/dev/null; EXIT=$?
OUTPUT=$("$DOG" "$EMPTY_TMP" 2>/dev/null)
rm -f "$EMPTY_TMP"
[[ $EXIT -eq 0 ]] && [[ -z "$OUTPUT" ]] && pass "empty file exit 0" || fail "empty file (exit=$EXIT)"

# 11. Large file pipe (SIGPIPE)
PIPE_ERR=$( { "$DOG" "$FIXTURE" | head -5 > /dev/null; } 2>&1 )
[[ -z "$PIPE_ERR" ]] && pass "large file pipe no broken pipe" || fail "SIGPIPE: $PIPE_ERR"

# 12. --plain
PLAIN_OUT=$("$DOG" -p "$FIXTURE" 2>/dev/null | head -1)
[[ -n "$PLAIN_OUT" ]] && pass "--plain runs without error" || fail "--plain"

# 13. --list-languages
LANGS=$("$DOG" --list-languages 2>/dev/null)
[[ -n "$LANGS" ]] && pass "--list-languages outputs something" || fail "--list-languages"

# --- Output ---
ELAPSED=$((SECONDS - START_TIME))
TOTAL=$((PASS_COUNT + FAIL_COUNT))

echo ""
if [[ $FAIL_COUNT -eq 0 ]]; then
    echo -e "  ${G}(PASS)${Z}  ${W}compat${Z}  ${B}${TOTAL} scenarios${Z}"
else
    echo -e "  ${R}(FAIL)${Z}  ${W}compat${Z}  ${B}${PASS_COUNT} passed, ${FAIL_COUNT} failed${Z}"
fi

for line in "${LINES[@]}"; do
    echo -e "$line"
done

if [[ ${#FAIL_DETAILS[@]} -gt 0 ]]; then
    for detail in "${FAIL_DETAILS[@]}"; do
        echo -e "      ${Y}${detail}${Z}"
    done
fi

echo ""
echo -e "  ${B}${PASS_COUNT} passed, ${FAIL_COUNT} failed  ${ELAPSED}s${Z}"

# Write counts for run-all.sh
if [[ -n "${COUNTS_FILE:-}" ]]; then
    echo "pass=${PASS_COUNT}" >> "$COUNTS_FILE"
    echo "fail=${FAIL_COUNT}" >> "$COUNTS_FILE"
fi

if [[ $FAIL_COUNT -gt 0 ]]; then
    exit 1
fi
