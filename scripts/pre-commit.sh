#!/bin/bash
# Pre-commit safety net: blocks the commit if swift-format or swiftlint report
# anything. Both run from the repo root so .swiftlint.yml applies.
#
# Install (once per clone):
#   cp scripts/pre-commit.sh .git/hooks/pre-commit && chmod +x .git/hooks/pre-commit
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

# swift-format has no config-file exclusion — skip the generated Embedded files.
swift_format_findings=$(find Sources -name '*.swift' \
  ! -name 'EmbeddedQueries.swift' \
  ! -name 'EmbeddedCompiledQueries.swift' \
  ! -name 'EmbeddedWoofSnippets.swift' -print0 \
  | xargs -0 swift-format lint 2>&1)
if [[ -n "$swift_format_findings" ]]; then
  echo "$swift_format_findings"
  echo "pre-commit: fix the swift-format findings above, then commit again."
  exit 1
fi

if ! swiftlint lint --quiet --strict; then
  echo "pre-commit: fix the swiftlint findings above, then commit again."
  exit 1
fi
