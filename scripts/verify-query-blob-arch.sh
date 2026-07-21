#!/bin/bash
# Cross-arch layout verification for precompiled query blobs (perf experiment
# 003 / Phase 3 handoff Item 4).
#
# The serialized-TSQuery blob format is struct-layout dependent (bitfields,
# packing). Universal (arm64 + x86_64) builds are only safe if both arches
# produce byte-identical blobs and capture streams. This script proves or
# refutes that for the CURRENT toolchain on every run:
#
#   1. builds the serialize harness for arm64 and x86_64
#   2. runs both (x86_64 via Rosetta), dumping blob + capture stream
#   3. byte-compares blobs and capture streams across arches
#
# Exit 0: layouts identical — single shared blobs are safe for universal builds.
# Exit 1: DRIFT DETECTED — per-arch blobs are REQUIRED; do not ship universal.
# Exit 2: environment problem (no Rosetta, build failure) — check is
#         inconclusive, treat as failure for release purposes.
#
# Wired as a prerequisite of `make release-macos`. Runtime ~10s.
# Grammars checked: cpp (most complex query) and json (control).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TS_SRC="$PROJECT_ROOT/LocalPackages/tree-sitter"
HARNESS="$PROJECT_ROOT/perf/experiments/003-query-cache/harness/serialize-bench.c"
WORK_DIR=$(mktemp -d)
trap 'rm -rf "$WORK_DIR"' EXIT

if [[ ! -d "$TS_SRC" ]]; then
  echo "verify-query-blob-arch: vendored tree-sitter missing at LocalPackages/tree-sitter" >&2
  exit 2
fi

if ! arch -x86_64 /usr/bin/true 2>/dev/null; then
  echo "verify-query-blob-arch: Rosetta unavailable — cannot verify x86_64 layout." >&2
  echo "Install Rosetta (softwareupdate --install-rosetta) or ship per-arch blobs." >&2
  exit 2
fi

check_grammar() {
  language_name="$1"
  language_fn="$2"
  grammar_src="$3"
  query_file="$4"
  fixture="$5"

  scanner_arg=""
  [[ -f "$grammar_src/scanner.c" ]] && scanner_arg="$grammar_src/scanner.c"

  for target_arch in arm64 x86_64; do
    cc -arch "$target_arch" -O2 -DLANG_FN="$language_fn" \
      -o "$WORK_DIR/bench-$language_name-$target_arch" "$HARNESS" \
      -I"$TS_SRC/lib/include" -I"$TS_SRC/lib/src" \
      "$grammar_src/parser.c" $scanner_arg -I"$grammar_src" \
      || { echo "build failed: $language_name $target_arch" >&2; exit 2; }
  done

  "$WORK_DIR/bench-$language_name-arm64" "$query_file" "$fixture" 3 \
    "$WORK_DIR/$language_name-arm64" > /dev/null \
    || { echo "arm64 run failed (capture mismatch?): $language_name" >&2; exit 1; }
  arch -x86_64 "$WORK_DIR/bench-$language_name-x86_64" "$query_file" "$fixture" 3 \
    "$WORK_DIR/$language_name-x86_64" > /dev/null \
    || { echo "x86_64 run failed (capture mismatch?): $language_name" >&2; exit 1; }

  for artifact in blob captures; do
    if ! cmp -s "$WORK_DIR/$language_name-arm64.$artifact" \
                "$WORK_DIR/$language_name-x86_64.$artifact"; then
      echo "ARCH LAYOUT DRIFT: $language_name $artifact differs between arm64 and x86_64." >&2
      echo "Per-arch blobs are REQUIRED — do not ship shared blobs in a universal binary." >&2
      exit 1
    fi
  done
  echo "  $language_name: arm64 == x86_64 (blob + captures byte-identical)"
}

echo "verify-query-blob-arch: cross-arch layout check"
check_grammar cpp tree_sitter_cpp \
  "$PROJECT_ROOT/LocalPackages/tree-sitter-cpp/src" \
  "$PROJECT_ROOT/Sources/dog/Resources/queries/cpp.scm" \
  "$PROJECT_ROOT/scripts/fixtures/performance/cpp/medium.cpp"
check_grammar json tree_sitter_json \
  "$PROJECT_ROOT/LocalPackages/tree-sitter-json/src" \
  "$PROJECT_ROOT/Sources/dog/Resources/queries/json.scm" \
  "$PROJECT_ROOT/scripts/fixtures/performance/json/medium.json"
echo "verify-query-blob-arch: PASS — shared blobs safe for universal builds on this toolchain"
