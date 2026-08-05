#!/usr/bin/env bash
# Tests: --help output shows all expected flags and usage
source "$(dirname "$0")/helpers.sh"
check_dog

echo "Help output:"

HELP=$("$DOG" --help 2>&1)

echo "$HELP" | grep -q "Syntax highlighting powered by tree-sitter" && pass "--help shows abstract" || fail "--help shows abstract"
echo "$HELP" | grep -q "\-l, --language" && pass "-l/--language" || fail "-l/--language"
echo "$HELP" | grep -q "\-p, --plain" && pass "-p/--plain" || fail "-p/--plain"
echo "$HELP" | grep -q "\-r, --range" && pass "-r/--range" || fail "-r/--range"
echo "$HELP" | grep -q "\--color" && pass "--color" || fail "--color"
echo "$HELP" | grep -q "\--theme" && pass "--theme" || fail "--theme"
echo "$HELP" | grep -q "\--line-numbers" && pass "--line-numbers" || fail "--line-numbers"
echo "$HELP" | grep -q "\--no-line-numbers" && pass "--no-line-numbers" || fail "--no-line-numbers"
echo "$HELP" | grep -q "\--header" && pass "--header" || fail "--header"
echo "$HELP" | grep -q "\--no-header" && pass "--no-header" || fail "--no-header"
echo "$HELP" | grep -q "\--list-languages" && pass "--list-languages" || fail "--list-languages"
echo "$HELP" | grep -q "\--list-themes" && pass "--list-themes" || fail "--list-themes"
echo "$HELP" | grep -q "woof" && pass "--woof" || fail "--woof"
echo "$HELP" | grep -q "dog <FILE>" && pass "usage shows 'dog <FILE>'" || fail "usage shows 'dog <FILE>'"
echo "$HELP" | grep -q "| dog" && pass "usage shows pipe example" || fail "usage shows pipe example"

summary
