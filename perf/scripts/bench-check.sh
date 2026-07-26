#!/bin/bash
# Bench the `dog` currently on PATH against the docs baseline and print the
# verdict table. Build/install first yourself (make build && make install);
# this script only measures.
#
# Usage:
#   bash perf/scripts/bench-check.sh             # tiers: tiny large (docs conditions)
#   bash perf/scripts/bench-check.sh tiny        # just one tier
#   bash perf/scripts/bench-check.sh tiny large xlarge
#
# Tiers are the fixture sizes under scripts/fixtures/performance:
#   tiny small medium large xlarge
#
# Raw hyperfine JSONs land in perf/latest-bench/results (overwritten each run).
# Keep the machine otherwise idle while it runs — timing noise reads as
# regressions. Table verdicts: "noise" = fine, "CHECK" = investigate.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DOCS_BASELINE="$PROJECT_ROOT/perf/baseline/docs-2026-07-18.csv"
OUT="$PROJECT_ROOT/perf/latest-bench/results"

if [[ $# -eq 0 ]]; then
  set -- tiny large
fi

DOG_PATH="$(command -v dog || true)"
if [[ -z "$DOG_PATH" ]]; then
  echo "error: no dog on PATH — run make install first" >&2
  exit 1
fi
echo "[bench-check] benching: $DOG_PATH ($("$DOG_PATH" --version))"

rm -rf "$OUT"
DOG_BIN="$DOG_PATH" bash "$SCRIPT_DIR/bench-matrix.sh" "$OUT" "$@"

python3 "$SCRIPT_DIR/summarize-baseline.py" "$OUT" --docs "$DOCS_BASELINE"
