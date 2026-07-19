#!/usr/bin/env python3
"""Summarize startup decomposition: version vs blank-file vs tiny-fixture times.

Usage:
    python3 perf/scripts/summarize-startup.py <startup-results-dir> <baseline-results-dir>

Prints a markdown table per language:
    version | blank | tiny | init cost (blank-version) | content cost (tiny-blank)

init cost ~= detection + grammar registration + query compile + theme load for
that language. content cost ~= parsing/rendering ~30 real lines.
"""

import json
import sys
from pathlib import Path


def mean_ms(json_path):
    data = json.loads(Path(json_path).read_text())
    return data["results"][0]["mean"] * 1000, data["results"][0]["stddev"] * 1000


def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    startup_dir, baseline_dir = Path(sys.argv[1]), Path(sys.argv[2])

    version_mean, version_sd = mean_ms(startup_dir / "version.json")
    print(f"dog --version: {version_mean:.1f}±{version_sd:.1f}ms (pure process startup)\n")
    print("| language | blank file | tiny fixture | init cost (blank−version) | content cost (tiny−blank) |")
    print("|" + " --- |" * 5)

    rows = []
    for blank_path in sorted(startup_dir.glob("blank-*.json")):
        language = blank_path.stem.removeprefix("blank-")
        blank_mean, blank_sd = mean_ms(blank_path)
        tiny_path = baseline_dir / f"tiny-{language}.json"
        if tiny_path.exists():
            tiny_mean, _ = mean_ms(tiny_path)
            tiny_cell = f"{tiny_mean:.1f}ms"
            content_cell = f"{tiny_mean - blank_mean:+.1f}ms"
        else:
            tiny_cell, content_cell = "-", "-"
        init_cost = blank_mean - version_mean
        rows.append((init_cost, language, blank_mean, blank_sd, tiny_cell, content_cell))

    for init_cost, language, blank_mean, blank_sd, tiny_cell, content_cell in sorted(rows, reverse=True):
        print(
            f"| {language} | {blank_mean:.1f}±{blank_sd:.1f}ms | {tiny_cell} "
            f"| {init_cost:+.1f}ms | {content_cell} |"
        )


if __name__ == "__main__":
    main()
