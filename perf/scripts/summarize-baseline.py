#!/usr/bin/env python3
"""Summarize baseline hyperfine JSONs and compare against the docs-site table.

Usage:
    python3 perf/scripts/summarize-baseline.py <results-dir> [--docs perf/baseline/docs-2026-04-12.csv]

Reads every <size>-<language>.json produced by perf/scripts/bench-matrix.sh
(result [0] = dog, result [1] = bat — same order bench.sh uses) and prints a
markdown table per size:

    language | dog mean±sd | bat mean±sd | ratio | docs dog | docs bat | docs ratio | dog delta

`dog delta` is (current - docs)/docs in percent, with a sigma column:
|delta| expressed in units of the current run's stddev. Rule of thumb applied
in the verdict column: within 2 sigma OR within 5% -> "noise", else "CHECK".

Heads-up: docs numbers are integer-rounded ms; on single-digit-ms rows a 1ms
rounding step alone is >10%, so small-file percent deltas overstate drift —
that is why the sigma column exists.
"""

import csv
import json
import math
import sys
from pathlib import Path

SIZE_ORDER = ["tiny", "small", "medium", "large", "xlarge"]


def load_docs(docs_path):
    docs = {}
    with open(docs_path) as handle:
        for row in csv.DictReader(handle):
            docs[(row["size"], row["language"])] = (
                float(row["dog_ms"]),
                float(row["bat_ms"]),
            )
    return docs


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    results_dir = Path(sys.argv[1])
    docs_path = "perf/baseline/docs-2026-04-12.csv"
    if "--docs" in sys.argv:
        docs_path = sys.argv[sys.argv.index("--docs") + 1]
    docs = load_docs(docs_path)

    rows = {}
    for json_path in sorted(results_dir.glob("*-*.json")):
        size, _, language = json_path.stem.partition("-")
        data = json.loads(json_path.read_text())
        dog_result, bat_result = data["results"][0], data["results"][1]
        rows.setdefault(size, []).append(
            (
                language,
                dog_result["mean"] * 1000,
                dog_result["stddev"] * 1000,
                bat_result["mean"] * 1000,
                bat_result["stddev"] * 1000,
            )
        )

    for size in SIZE_ORDER:
        if size not in rows:
            continue
        print(f"\n### {size}\n")
        header = (
            "| language | dog now | bat now | ratio now | dog docs | bat docs "
            "| ratio docs | dog delta | sigma | verdict |"
        )
        print(header)
        print("|" + " --- |" * 9)
        ratios_now, ratios_docs, verdicts = [], [], []
        for language, dog_mean, dog_sd, bat_mean, bat_sd in sorted(rows[size]):
            ratio_now = bat_mean / dog_mean if dog_mean else math.nan
            docs_entry = docs.get((size, language))
            if docs_entry:
                docs_dog, docs_bat = docs_entry
                docs_ratio = docs_bat / docs_dog
                delta_pct = (dog_mean - docs_dog) / docs_dog * 100
                sigma = abs(dog_mean - docs_dog) / dog_sd if dog_sd else math.inf
                verdict = "noise" if (sigma <= 2 or abs(delta_pct) <= 5) else "CHECK"
                docs_cols = (
                    f"{docs_dog:.0f}ms | {docs_bat:.0f}ms | {docs_ratio:.1f}x "
                    f"| {delta_pct:+.1f}% | {sigma:.1f} | {verdict}"
                )
                ratios_docs.append(docs_ratio)
                verdicts.append(verdict)
            else:
                docs_cols = "- | - | - | - | - | new"
            ratios_now.append(ratio_now)
            print(
                f"| {language} | {dog_mean:.1f}±{dog_sd:.1f}ms "
                f"| {bat_mean:.1f}±{bat_sd:.1f}ms | {ratio_now:.1f}x | {docs_cols} |"
            )
        avg_now = sum(ratios_now) / len(ratios_now)
        summary = f"\navg ratio now: {avg_now:.1f}x"
        if ratios_docs:
            avg_docs = sum(ratios_docs) / len(ratios_docs)
            summary += f" (docs: {avg_docs:.1f}x), CHECK rows: {verdicts.count('CHECK')}"
        print(summary)


if __name__ == "__main__":
    main()
