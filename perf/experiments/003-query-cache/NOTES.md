# 003 — precompiled query serialization (003a prototype + 003b implementation)

Status: IMPLEMENTED (003b shipped 2026-07-18; results at bottom)
Date: 2026-07-18 · dog commit: f1f2c92 · tree-sitter 0.25.10 · M2 Max, macOS 26.2

## Question

`ts_query_new`'s pattern-analysis pass costs 10–130ms per language and owns
84–95% of tiny-tier runtime (see perf/baseline/NOTES.md). Can a compiled
TSQuery be serialized once and reloaded in ~µs, with byte-identical capture
behavior — enabling build-time precompiled queries embedded in the binary?

## How to reproduce

```sh
cd /Users/eddenamber/Projects/dog
SCRATCH=/tmp; TS=.build/checkouts/tree-sitter
cc -O2 -DLANG_FN=tree_sitter_cpp -o $SCRATCH/serialize-bench-cpp \
   perf/experiments/003-query-cache/harness/serialize-bench.c \
   -I$TS/lib/include -I$TS/lib/src \
   LocalPackages/tree-sitter-cpp/src/parser.c \
   LocalPackages/tree-sitter-cpp/src/scanner.c -ILocalPackages/tree-sitter-cpp/src
$SCRATCH/serialize-bench-cpp Sources/dog/Resources/queries/cpp.scm \
   scripts/fixtures/performance/cpp/large.cpp
# repeat with -DLANG_FN=tree_sitter_<lang> + that grammar's src dir; grammars
# with scanner.cc (none in the tested set) need a c++ link step.
```

## Results (all on large fixtures, 20 load iterations)

| grammar | compile | blob bytes | load mean | captures vs fresh compile |
| --- | ---: | ---: | ---: | --- |
| cpp | 130.5ms | 27,019 | 0.003ms | IDENTICAL (3.3MB records) |
| swift | 71.8ms | 14,986 | 0.002ms | IDENTICAL |
| typescript | 69.7ms | 25,762 | 0.005ms | IDENTICAL (15.5MB records) |
| ruby | 68.6ms | 14,714 | 0.003ms | IDENTICAL |
| tsx | 59.6ms | 33,686 | 0.004ms | IDENTICAL |
| rust | 51.5ms | 21,946 | 0.005ms | IDENTICAL |
| python | 21.9ms | 23,391 | 0.002ms | IDENTICAL (4.7MB records) |
| c | 19.6ms | 15,416 | 0.003ms | IDENTICAL |
| bash | 18.4ms | 16,386 | 0.002ms | IDENTICAL |
| json | 0.14ms | 1,908 | 0.003ms | IDENTICAL |

- Load is ~4 orders of magnitude faster than compile. All 17 languages' blobs
  would total well under 0.5MB of binary growth.
- `ts_query_delete` on a deserialized query frees cleanly (arrays allocated
  via ts_malloc to match).
- Why this is tractable: TSQuery (query.c:295 in 0.25.10) contains exactly ONE
  pointer — `language`, re-injected at load. Everything else is flat POD
  arrays (QueryStep and friends are symbols/ids/bitfields) plus one nested
  Array(CaptureQuantifiers).

## Projected impact

Tiny tier becomes process floor (~5ms) for every language: cpp 126→~6ms,
swift 71→~5ms, tsx 62→~5ms. dog would beat bat on ALL 17 languages at EVERY
size (currently loses 10/17 tiny, 9/17 small). Interaction with the shipped
compile/parse overlap: overlap hides min(parse, compile); with compile ≈ 0 the
overlap becomes a no-op rather than a conflict — keep it for the fallback path.

## Heads-up

- The blob format is arch/compiler/runtime-struct specific (bitfield layout,
  struct packing). This is FINE for the intended design — blobs generated at
  build time by the same toolchain that builds the binary that loads them —
  and NOT acceptable for a user-writable on-disk cache shared across builds.
- The harness gains struct access by `#include "lib.c"` (runtime amalgamation)
  — do NOT also link lib.c or symbols duplicate.
- Runtime pin matters: struct layout audited against 0.25.10. Any runtime bump
  must re-verify (add a static assert on sizeof(TSQuery)/sizeof(QueryStep) in
  the generator to make drift loud).
- typescript compile measures ~70ms here vs ~44ms in startup-decomp — harness
  includes first-touch grammar init; direction and conclusion unaffected.

## Decision

003a: prototype CONFIRMED. 003b: IMPLEMENTED same day (user go-ahead).

## 003b implementation results (2026-07-18)

Shipped as: vendored runtime `LocalPackages/tree-sitter` (0.25.10, byte-verified
against the SPM checkout) + local patch adding `ts_query_serialize`/
`ts_query_deserialize` (query.c end, api.h decls; magic + format version +
struct sizes + grammar ABI + query FNV-1a hash all validated inside
deserialize, bounds-checked reads, NULL on any mismatch). Generator:
`scripts/generate/gen-query-blob.c` + `scripts/generate/query-blobs.sh`
(`make generate-query-blobs`) emits the committed
`Sources/dog/Parsing/Languages/EmbeddedCompiledQueries.swift` (17 blobs, 266KB,
each round-trip self-checked at generation). Load path:
`LanguageEntry.compileQuery` tries the blob first; rejection warns on stderr
and falls back to `ts_query_new` (fail-open). Cross-arch layout gate already
wired into `make release-macos` (scripts/verify-query-blob-arch.sh).

Measured (blank-file init cost, warmup 3 runs 50): **+0.3 to +1.2ms for ALL 17
languages** — was +0.8 (json) to +122ms (cpp). Tiny/small matrix vs bat
(warmup 0 runs 20, docs conditions): **tiny avg 2.7x, small avg 3.5x, dog wins
17/17 at BOTH sizes** (was 1.0x losing 10/17, 1.3x losing 9/17). cpp/tiny
0.1x -> 2.7x. Raw: `results-003b-startup/`, `results-003b-bench/`.

Gates passed: stdout byte-identical + stderr silent, all 17 languages
tiny+large vs pre-003b binary; swift test 197 tests, only the 3 known coverage
failures; corrupt-blob fallback + fast-path-equality pinned by
QueryFailureTests."Corrupt precompiled blob falls back to source compilation".
