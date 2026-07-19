#!/bin/bash
# Experiment 006: comparative hyperfine across all built flag variants.
# One hyperfine invocation per fixture with every variant binary as a command —
# hyperfine prints the relative ranking directly.
#
# Usage:  bash perf/experiments/006-build-flags/bench-variants.sh <variant-dir> <output-dir>
#
# Env: WARMUP (default 1), RUNS (default 10)
#
# Heads-up: run alone (no concurrent CPU load), builds must be finished first.

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
FIXTURES="$PROJECT_ROOT/scripts/fixtures/performance"
WARMUP="${WARMUP:-1}"
RUNS="${RUNS:-10}"

variant_dir="$1"
output_dir="$2"
mkdir -p "$output_dir"

PROBES=(
  "cpp/tiny.cpp"
  "swift/tiny.swift"
  "typescript/large.ts"
  "go/large.go"
  "c/xlarge.c"
)

for probe in "${PROBES[@]}"; do
  fixture="$FIXTURES/$probe"
  probe_name=$(echo "$probe" | tr '/.' '--')
  commands=()
  names=()
  for binary in "$variant_dir"/dog-*; do
    [[ -x "$binary" ]] || continue
    names+=("--command-name" "$(basename "$binary")")
    commands+=("$binary --color always -P $fixture > /dev/null")
  done
  echo "[$(date +%H:%M:%S)] probe $probe (${#commands[@]} variants)"
  hyperfine --warmup "$WARMUP" --runs "$RUNS" \
    --export-json "$output_dir/$probe_name.json" \
    "${names[@]}" \
    "${commands[@]}" 2>&1 | grep -E 'Benchmark|mean|faster|±' | sed 's/^ *//'
done
