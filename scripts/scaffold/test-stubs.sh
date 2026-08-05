#!/usr/bin/env bash
# Tests: stub commands run without crashing
source "$(dirname "$0")/helpers.sh"
check_dog

echo "Stubs:"

"$DOG" --list-languages 2>/dev/null | grep -qi "languages\|coming" && pass "--list-languages" || fail "--list-languages"
"$DOG" --list-themes 2>/dev/null | grep -qi "utilitydark\|default" && pass "--list-themes" || fail "--list-themes"
[[ -n "$("$DOG" --woof 2>/dev/null)" ]] && pass "--woof" || fail "--woof"

summary
