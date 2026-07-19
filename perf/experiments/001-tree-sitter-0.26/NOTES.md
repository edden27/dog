# 001 — tree-sitter runtime 0.25.10 → 0.26.11

Status: rejected (0.26 slower + breaks python highlighting)
Date: 2026-07-18 · Machine: M2 Max, macOS 26.2 · dog commit: 4433245 · Swift 6.3.3

## Question

Does upgrading the vendored tree-sitter runtime (pinned `.upToNextMinor(from:
"0.25.0")` → resolves 0.25.10, Sep 2025) to the current 0.26.11 (Jul 2026)
improve (a) the query-compile init cost that owns the tiny tier, and (b)
parse/query-exec throughput on large files?

Changelog recon (via `gh api`, see repro): no commit targets the
`ts_query__perform_analysis` pass directly; candidates are
`123fb1c1 perf(query): min-heap for finished_states in next_capture` (query
exec) and `c1379718 perf(parser): LookaheadIterator in error recovery`.
Expectation set accordingly: modest at best — measure, don't assume.

## How to reproduce

```sh
cd /Users/eddenamber/Projects/dog
# Package.swift: runtime pin changed to .upToNextMinor(from: "0.26.0")
swift package resolve && swift build -c release

# recon commands used:
gh api repos/tree-sitter/tree-sitter/releases --paginate -q '.[] | "\(.tag_name)  \(.published_at)"'
gh api "repos/tree-sitter/tree-sitter/commits?path=lib/src&since=2025-09-22T00:00:00Z&per_page=100" \
  -q '.[] | select(.commit.message | test("perf|speed|fast|optimi"; "i")) | .commit.message'

# measurements (compare against perf/baseline/):
bash perf/scripts/startup-decomp.sh perf/experiments/001-tree-sitter-0.26/results/startup
bash perf/scripts/bench-matrix.sh perf/experiments/001-tree-sitter-0.26/results/bench large
uv run python3 perf/scripts/summarize-startup.py perf/experiments/001-tree-sitter-0.26/results/startup perf/baseline/results
uv run python3 perf/scripts/summarize-baseline.py perf/experiments/001-tree-sitter-0.26/results/bench
```

Correctness gate before timing counts: `swift test` passes and highlight output
is byte-identical (or reviewed-diff) on tiny fixtures vs 0.25.10 binary.

## Results

**Build/compat:** 0.26.11 resolves and builds clean. Byte-diff of all 17 tiny
fixtures between runtimes (both binaries stashed, compared with `cmp`):
**16/17 identical; python breaks.**

**Python root cause** (found with `harness/query-compile-check.c`, a standalone
reproducer built against each runtime's C source): dog's python.scm line 84
docstring pattern

```scheme
(expression_statement (string (string_content) @spell) @string.documentation)
```

fails on 0.26 with `TSQueryErrorStructure` — python grammar v0.25 declares
`expression_statement` a supertype (subtypes: assignment, augmented_assignment,
expression, tuple_expression, yield) and 0.26's new subtype validation rejects
`string` as its child, even though real trees contain exactly that shape.
When one pattern fails to compile, **dog silently renders the whole language
unhighlighted** — no warning (separate robustness finding).

Ecosystem-wide: nvim-treesitter main ships this same pattern; upstream grammar
declares the same supertype.

**Rewrite attempts** (verified with `harness/query-capture-dump.c` — compile
success is NOT enough, several variants compile but capture nothing):

| variant | 0.25 compile | 0.26 compile | captures at runtime |
| --- | --- | --- | --- |
| original `(expression_statement (string ...))` | OK | Structure error | works on 0.25 |
| `(string)` w/o inner capture, or outer-capture variants | OK | Structure error | — |
| `(primary_expression/string)` slash form | OK | Structure error | — |
| explicit supertype nesting `(expression (primary_expression (string)))` | OK | OK | **zero captures — dead** |
| wildcard `(_ (string_content))` child | OK | OK | **zero captures — dead** |

No compatible form found in the time spent. User decision: measure 0.26 on the
16 valid languages first (option a); python fix only matters if 0.26 wins.

**Startup (16 valid languages):** init costs statistically unchanged vs 0.25 —
cpp 119.8ms (was 122.2), swift 65.8 (67.9), tsx 57.7 (58.6), typescript 43.7
(44.5), ruby 41.5 (42.9). ~1–3%, at the noise floor. 0.26 does NOT address the
query-compile cost. (Python's 0.9ms init row is bogus — failed query skips
compilation entirely.) Raw: `results/startup/`, summary:
`results/startup-summary.md`.

**Throughput (dog-only comparative hyperfine, warmup 1 runs 10):** 0.25.10 is
1.01–1.04× FASTER than 0.26.11 on all five probes (c/xlarge, go/large,
typescript/large, cpp/large, ruby/large). 0.26 is a 1–4% regression. Raw:
`results/throughput-*.json`.

## Heads-up

- 0.26 tightened query validation — a highlights.scm that compiled on 0.25 can
  FAIL on 0.26, and dog's failure mode is silent full-language fallback to
  plain text. Byte-diff every language's output before trusting any benchmark
  of a runtime/grammar/query change.
- A query variant that *compiles* on both runtimes can still be dead at match
  time (supertype analysis kills it silently). Always verify with
  `query-capture-dump`, never with compile success alone.
- Grammars are ABI-14 C parsers (standalone LocalPackages/upstream); 0.26
  runtime accepts them, no grammar rebuilds needed.
- Harness binaries build in ~2s: see header comments in `harness/*.c` for exact
  commands (0.25 source lives in `.build/checkouts/tree-sitter`, 0.26 cloned to
  scratchpad with `.git` removed).

## Decision

**Rejected.** 0.26.11 is 1–4% slower on throughput, gives no init-cost
improvement, and breaks python highlighting with no compatible query rewrite
found. Stay on `.upToNextMinor(from: "0.25.0")`. Revisit only if upstream
relaxes supertype validation or the python grammar/queries realign. The
python-pattern findings and both harnesses remain valuable for experiment 002
(per-pattern compile-cost profiling reuses query-compile-check.c directly).
