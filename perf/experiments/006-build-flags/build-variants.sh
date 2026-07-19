#!/bin/bash
# Experiment 006: build dog release binaries under different compiler-flag
# variants and stash each under $VARIANT_DIR/dog-<name>. Build failures are
# recorded, not fatal. Run benchmarks separately (bench-variants.sh) so CPU-
# heavy compilation never overlaps timing runs.
#
# Usage:  bash perf/experiments/006-build-flags/build-variants.sh <variant-dir>
#
# Heads-up: each flag change forces SPM to rebuild most targets (~2-4 min,
# cpp grammar dominates). Binaries are copied out because the next variant
# overwrites .build/release/dog.

set -uo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$PROJECT_ROOT"

variant_dir="$1"
mkdir -p "$variant_dir"
log_file="$variant_dir/build-log.txt"

build_variant() {
  variant_name="$1"
  shift
  echo "[$(date +%H:%M:%S)] building $variant_name: $*" | tee -a "$log_file"
  if swift build -c release "$@" >> "$log_file" 2>&1; then
    cp .build/release/dog "$variant_dir/dog-$variant_name"
    size_bytes=$(stat -f%z "$variant_dir/dog-$variant_name")
    echo "[$(date +%H:%M:%S)] OK $variant_name ($size_bytes bytes)" | tee -a "$log_file"
  else
    echo "[$(date +%H:%M:%S)] BUILD FAILED $variant_name (see $log_file)" | tee -a "$log_file"
  fi
}

build_variant baseline
build_variant cc-O3 -Xcc -O3
build_variant cc-O3-native -Xcc -O3 -Xcc -mcpu=native
build_variant lto-thin -Xswiftc -lto=llvm-thin -Xcc -flto=thin
build_variant swift-Ounchecked -Xswiftc -Ounchecked

# Leave the tree back at a plain release build so later work isn't running a
# flag-variant binary by accident.
swift build -c release >> "$log_file" 2>&1
echo "[$(date +%H:%M:%S)] done — tree restored to plain release" | tee -a "$log_file"
