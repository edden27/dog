#!/usr/bin/env python3
"""Parse an xctrace time-profile XML export into weighted hot-function tables.

Usage:
    python3 perf/scripts/parse-timeprofile.py <timeprofile.xml> [--top 25]

Produces two views:
  1. Leaf functions (self time) — where samples actually landed.
  2. Attribution buckets — each sample assigned to the first recognizable
     category found walking the stack leaf->root (dyld/startup, tree-sitter
     query compile, tree-sitter parse, dog highlight/render, output write,
     theme load, other).

xctrace dedupes repeated elements with ref="id" attributes; this resolves them.
Weights are nanoseconds per sample (typically 1ms ticks).
"""

import sys
import xml.etree.ElementTree as ElementTree
from collections import Counter

BUCKET_RULES = [
    # ts_query_new is often inlined/truncated out of exported stacks — its
    # analysis internals must be matched directly or they land in "other".
    ("tree-sitter query compile", [
        "ts_query_new", "ts_query__perform_analysis", "ts_query__analyze",
        "analysis_state", "analysis_subgraph", "state_predecessor_map",
        "ts_lookahead_iterator",
    ]),
    ("tree-sitter parse", ["ts_parser_parse", "ts_lexer", "ts_subtree", "ts_stack", "ts_language"]),
    ("tree-sitter query exec", ["ts_query_cursor", "ts_query_matches", "ts_tree_cursor"]),
    ("dyld/startup", ["dyld", "libSystem_initializer", "_dyld_start"]),
    ("output write", ["write", "__write", "flush"]),
    ("theme", ["heme"]),
    ("highlight/render (dog swift)", ["dog", "highlight", "render", "ANSI", "Token"]),
    ("swift runtime/alloc", ["swift_", "malloc", "free", "_platform_mem"]),
]


def resolve_refs(root):
    by_id = {}
    for element in root.iter():
        identifier = element.get("id")
        if identifier is not None:
            by_id[identifier] = element
    return by_id


def frame_names(backtrace_element, by_id):
    names = []
    for frame in backtrace_element.iter("frame"):
        ref = frame.get("ref")
        resolved = by_id[ref] if ref is not None else frame
        name = resolved.get("name") or "?"
        names.append(name)
    return names


def bucket_for(names):
    for name in names:
        for bucket, needles in BUCKET_RULES:
            if any(needle in name for needle in needles):
                return bucket
    return "other"


def main():
    path = sys.argv[1]
    top_count = int(sys.argv[sys.argv.index("--top") + 1]) if "--top" in sys.argv else 25
    root = ElementTree.parse(path).getroot()
    by_id = resolve_refs(root)

    leaf_weights = Counter()
    bucket_weights = Counter()
    total_ns = 0

    for row in root.iter("row"):
        weight_element = row.find("weight")
        if weight_element is None:
            continue
        ref = weight_element.get("ref")
        if ref is not None:
            weight_element = by_id[ref]
        weight_ns = int(weight_element.text)

        backtrace_holder = row.find("tagged-backtrace")
        if backtrace_holder is None:
            continue
        ref = backtrace_holder.get("ref")
        if ref is not None:
            backtrace_holder = by_id[ref]
        backtrace = backtrace_holder.find("backtrace")
        if backtrace is None:
            continue
        ref = backtrace.get("ref")
        if ref is not None:
            backtrace = by_id[ref]

        names = frame_names(backtrace, by_id)
        if not names:
            continue
        leaf_weights[names[0]] += weight_ns
        bucket_weights[bucket_for(names)] += weight_ns
        total_ns += weight_ns

    total_ms = total_ns / 1e6
    print(f"total sampled: {total_ms:.1f}ms ({path})\n")

    print("## Attribution buckets (stack-walk leaf->root)\n")
    print("| bucket | ms | % |")
    print("| --- | --- | --- |")
    for bucket, weight in bucket_weights.most_common():
        print(f"| {bucket} | {weight/1e6:.1f} | {weight/total_ns*100:.1f}% |")

    print(f"\n## Top {top_count} leaf functions (self time)\n")
    print("| function | ms | % |")
    print("| --- | --- | --- |")
    for name, weight in leaf_weights.most_common(top_count):
        display = name if len(name) <= 100 else name[:97] + "..."
        print(f"| {display} | {weight/1e6:.1f} | {weight/total_ns*100:.1f}% |")


if __name__ == "__main__":
    main()
