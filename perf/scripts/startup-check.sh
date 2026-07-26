#!/bin/bash
# Startup-time check for the `dog` currently on PATH. Runs the startup
# decomposition (dog --version, then a blank file per language) and compares
# against the PREVIOUS startup-check run, per language.
# Build/install first yourself (make build && make install); this only
# measures.
#
# Usage:
#   bash perf/scripts/startup-check.sh
#
# Layout: perf/latest-startup/results  = this run (overwritten each time)
#         perf/latest-startup/previous = the run before it (the comparison)
# Keep the machine otherwise idle while it runs.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
BASE="$PROJECT_ROOT/perf/latest-startup"
OUT="$BASE/results"
PREV="$BASE/previous"

DOG_PATH="$(command -v dog || true)"
if [[ -z "$DOG_PATH" ]]; then
  echo "error: no dog on PATH — run make install first" >&2
  exit 1
fi
echo "[startup-check] benching: $DOG_PATH ($("$DOG_PATH" --version))"

if [[ -d "$OUT" ]]; then
  rm -rf "$PREV"
  mv "$OUT" "$PREV"
fi
DOG_BIN="$DOG_PATH" bash "$SCRIPT_DIR/startup-decomp.sh" "$OUT"

echo
if [[ -d "$PREV" ]]; then
  python3 - "$PREV" "$OUT" <<'EOF'
import json, sys
from pathlib import Path

prev_dir, cur_dir = Path(sys.argv[1]), Path(sys.argv[2])

def mean_sd(path):
    r = json.loads(path.read_text())["results"][0]
    return r["mean"] * 1000, r["stddev"] * 1000

print(f'{"":12} {"previous run":>15} {"this run":>15}')
names = ["version"] + sorted(
    p.stem for p in cur_dir.glob("blank-*.json")
)
for name in names:
    cur_path, prev_path = cur_dir / f"{name}.json", prev_dir / f"{name}.json"
    if not cur_path.exists() or not prev_path.exists():
        continue
    (pm, psd), (cm, csd) = mean_sd(prev_path), mean_sd(cur_path)
    label = name.removeprefix("blank-")
    print(f"{label:12} {pm:9.2f}±{psd:4.2f} {cm:9.2f}±{csd:4.2f}   diff {cm-pm:+.2f}ms")
EOF
else
  echo "[startup-check] no previous run to compare against — this run is now the reference"
  python3 "$SCRIPT_DIR/summarize-startup.py" "$OUT" "$PROJECT_ROOT/perf/baseline/results"
fi
