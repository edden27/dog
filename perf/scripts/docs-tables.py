#!/usr/bin/env python3
"""Emit vitepress-formatted benchmark tables for the docs site from hyperfine JSONs.

Usage:
    uv run python3 perf/scripts/docs-tables.py perf/phase3-bench/results

Prints, per size tier: the docs-style markdown table with win/loss/same span
classes, the wins line, and the average — matching the existing format of
~/Code/vitepress-test/docs/benchmarks.md. Also prints the summary table.

Ratio classing mirrors the current docs: ratio rounded to 1 decimal; 1.0 ->
"same", above -> "win", below -> "loss". Times are integer-rounded ms like the
existing tables.
"""

import json
import sys
from pathlib import Path

SIZE_ORDER = ["tiny", "small", "medium", "large", "xlarge"]


def load_rows(results_dir):
    rows = {}
    for json_path in sorted(results_dir.glob("*-*.json")):
        size, _, language = json_path.stem.partition("-")
        data = json.loads(json_path.read_text())
        dog_ms = data["results"][0]["mean"] * 1000
        bat_ms = data["results"][1]["mean"] * 1000
        rows.setdefault(size, []).append((language, dog_ms, bat_ms))
    return rows


def span(ratio_text, klass):
    return f'<span class="{klass}">{ratio_text}</span>'


def classify(ratio_rounded):
    if ratio_rounded > 1.0:
        return "win"
    if ratio_rounded < 1.0:
        return "loss"
    return "same"


def main():
    results_dir = Path(sys.argv[1])
    rows = load_rows(results_dir)
    summary = []

    for size in SIZE_ORDER:
        if size not in rows:
            continue
        print(f"\n=== {size} ===\n")
        print("| Language | dog | bat | Ratio |")
        print("| :--- | ---: | ---: | ---: |")
        wins = losses = ties = 0
        ratios = []
        for language, dog_ms, bat_ms in sorted(rows[size]):
            ratio = bat_ms / dog_ms
            ratio_rounded = round(ratio, 1)
            klass = classify(ratio_rounded)
            wins += klass == "win"
            losses += klass == "loss"
            ties += klass == "same"
            ratios.append(ratio)
            dog_cell = f"{dog_ms:,.0f}ms"
            bat_cell = f"{bat_ms:,.0f}ms"
            print(
                f"| {language} | {dog_cell} | {bat_cell} "
                f"| {span(f'{ratio_rounded}×', klass)} |"
            )
        average = sum(ratios) / len(ratios)
        total = len(ratios)
        summary.append((size, wins, ties, total, average))
        print(f"\nwins: dog {wins}/{total}, bat {losses}/{total}, ties {ties} — avg {average:.1f}x")

    print("\n=== summary table ===\n")
    for size, wins, ties, total, average in summary:
        wins_class = "win" if wins > total / 2 else "same"
        avg_class = "win" if average >= 1.05 else "same"
        print(
            f"| {size} | {span(f'{wins}/{total}', wins_class)} "
            f"| {span(f'{average:.1f}×', avg_class)} |"
        )


if __name__ == "__main__":
    main()
