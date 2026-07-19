#!/bin/bash
# Startup-cost decomposition per language — isolates fixed overhead from
# content-proportional work.
#
# Three graduated measurements:
#   1. dog --version                  -> pure process startup (dyld + arg parse)
#   2. dog <blank .ext file>          -> + detection + grammar/query init + empty pipeline
#   3. tiny fixture (baseline data)   -> + ~30 lines of real content
#
# (blank - version) ~= per-language init cost (grammar registration + query
# compile + theme load). (tiny - blank) ~= cost of actually parsing/rendering
# 30 lines. Extensions are derived from each language's tiny fixture so the
# detection path matches the benchmark exactly.
#
# Usage:
#   bash perf/scripts/startup-decomp.sh <output-dir>
#
# Env knobs:
#   WARMUP (default 3), RUNS (default 50), DOG_BIN (default release binary)
#
# Output: <output-dir>/version.json, <output-dir>/blank-<language>.json
# Blank files are one newline, created under a temp dir, removed after.
#
# Heads-up: run alone, no concurrent CPU load. A blank file may short-circuit
# before grammar init (that outcome is itself a finding — compare against a
# one-comment file if blank ~= version across ALL languages).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
FIXTURES="$PROJECT_ROOT/scripts/fixtures/performance"

WARMUP="${WARMUP:-3}"
RUNS="${RUNS:-50}"
DOG="${DOG_BIN:-$PROJECT_ROOT/.build/release/dog}"

output_dir="$1"
mkdir -p "$output_dir"
blank_dir=$(mktemp -d)
trap 'rm -rf "$blank_dir"' EXIT

hyperfine --warmup "$WARMUP" --runs "$RUNS" \
  --export-json "$output_dir/version.json" \
  "$DOG --version > /dev/null" >> "$output_dir/run-log.txt" 2>&1

for language_dir in "$FIXTURES"/*/; do
  language=$(basename "$language_dir")
  shopt -s nullglob
  candidates=("$language_dir"tiny.*)
  shopt -u nullglob
  [[ ${#candidates[@]} -eq 0 ]] && continue
  extension="${candidates[0]##*.}"

  blank_file="$blank_dir/blank.$extension"
  printf '\n' > "$blank_file"

  echo "[$(date +%H:%M:%S)] blank $language (.$extension)" | tee -a "$output_dir/run-log.txt"
  hyperfine --warmup "$WARMUP" --runs "$RUNS" \
    --export-json "$output_dir/blank-${language}.json" \
    "$DOG --color always -P $blank_file > /dev/null" >> "$output_dir/run-log.txt" 2>&1
done

echo "done" | tee -a "$output_dir/run-log.txt"
