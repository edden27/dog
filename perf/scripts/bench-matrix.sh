#!/bin/bash
# Baseline benchmark matrix runner — mirrors scripts/benchmarks/bench.sh command
# construction exactly (docs conditions), but KEEPS every raw hyperfine JSON so
# stddev/min/max survive for noise analysis.
#
# Commands mirrored from bench.sh defaults (BENCH_PLAIN=0, BENCH_NO_PAGER=1,
# auto-detect, no theme pin):
#   dog:  <dog> --color always -P <fixture> > /dev/null
#   bat:  bat --paging=never --color=always <fixture> > /dev/null
#
# Usage:
#   bash perf/scripts/bench-matrix.sh <output-dir> <size> [<size> ...]
#
# Env knobs:
#   WARMUP  (default 0)   — docs conditions used 0
#   RUNS    (default 20)  — docs conditions used 20
#   DOG_BIN (default $PROJECT_ROOT/.build/release/dog)
#
# Output: <output-dir>/<size>-<language>.json  (hyperfine --export-json)
# Plus <output-dir>/run-log.txt with per-language progress.
#
# Heads-up: run nothing CPU-heavy concurrently — timing noise. bat reads the
# user's bat config (theme) exactly as bench.sh default does; the active bat
# theme is recorded in the env snapshot.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
FIXTURES="$PROJECT_ROOT/scripts/fixtures/performance"

WARMUP="${WARMUP:-0}"
RUNS="${RUNS:-20}"
DOG="${DOG_BIN:-$PROJECT_ROOT/.build/release/dog}"

if [[ ! -x "$DOG" ]]; then
  echo "error: dog binary not found at $DOG" >&2
  exit 1
fi

output_dir="$1"
shift
mkdir -p "$output_dir"
log_file="$output_dir/run-log.txt"

for size in "$@"; do
  for language_dir in "$FIXTURES"/*/; do
    language=$(basename "$language_dir")

    shopt -s nullglob
    candidates=("$language_dir"${size}.*)
    shopt -u nullglob
    if [[ ${#candidates[@]} -eq 0 ]]; then
      echo "skip $size/$language — no fixture" | tee -a "$log_file"
      continue
    fi
    fixture="${candidates[0]}"

    json_path="$output_dir/${size}-${language}.json"
    echo "[$(date +%H:%M:%S)] $size/$language" | tee -a "$log_file"

    hyperfine --warmup "$WARMUP" --runs "$RUNS" --export-json "$json_path" \
      "$DOG --color always -P $fixture > /dev/null" \
      "bat --paging=never --color=always $fixture > /dev/null" \
      >> "$log_file" 2>&1
  done
done

echo "[$(date +%H:%M:%S)] done: $*" | tee -a "$log_file"
