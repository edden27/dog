# 004 — overlap query compile with parse (second thread)

Status: confirmed (harness level; dog implementation is Phase 3)
Date: 2026-07-18 · Machine: M2 Max, macOS 26.2 · dog commit: dd505dc · tree-sitter 0.25.10

## Question

`ts_query_new` (compile) and `ts_parser_parse` (parse) are independent until
query exec needs both, and each only reads the static `TSLanguage`. Running
compile on a second thread should hide min(parse, compile) of wall clock.
How much is that worth per language?

## How to reproduce

```sh
cd /Users/eddenamber/Projects/dog
SCRATCH=<any-tmp-dir>; TS=.build/checkouts/tree-sitter
cc -O2 -DLANG_FN=tree_sitter_typescript -o $SCRATCH/overlap-ts \
   perf/experiments/004-overlap-compile-parse/harness/overlap-bench.c \
   $TS/lib/src/lib.c -I$TS/lib/include -I$TS/lib/src \
   LocalPackages/tree-sitter-typescript/typescript/src/parser.c \
   LocalPackages/tree-sitter-typescript/typescript/src/scanner.c \
   -ILocalPackages/tree-sitter-typescript/typescript/src -lpthread
$SCRATCH/overlap-ts Sources/dog/Resources/queries/typescript.scm \
   scripts/fixtures/performance/typescript/large.ts 15
# same pattern with -DLANG_FN=tree_sitter_cpp (cpp src) and tree_sitter_c
# (c has no scanner.c — omit that argument)
```

## Results (medians of 15 iterations)

| probe | compile | parse | sequential total | overlapped total | saved |
| --- | --- | --- | --- | --- | --- |
| typescript/large | 42.9ms | 144.0ms | 289.7ms | 247.0ms | **42.6ms (14.7%)** |
| cpp/large | 117.1ms | 89.9ms | 240.7ms | 153.9ms | **86.7ms (36.0%)** |
| c/xlarge | 9.6ms | 627.2ms | 900.8ms | 893.6ms | 7.2ms (0.8%) |

- Saving ≈ min(parse, compile) exactly as theory predicts; thread cost noise-level.
- Correctness: capture counts identical sequential vs overlapped (harness fails
  hard on mismatch).
- Where it pays: heavy-grammar medium/large files (cpp, swift, tsx, typescript,
  ruby, rust). Where it does not: tiny files (parse ≈ 1ms hides nothing) and
  light grammars.
- Mapped to dog end-to-end (baseline numbers): cpp/large 281→~195ms (ratio
  4.2x→~6x), typescript/large 482→~440ms.

## Heads-up

- Thread-safety argument: both calls only read the immutable grammar tables.
  Do NOT share a TSParser or TSQuery across threads — create per-thread.
- Tiny-file regression risk in Phase 3: spawning a thread costs ~tens of µs —
  negligible, but gate the overlap on file size only if measurement demands it
  (probably unnecessary).
- dog's parse path is an actor method (`entry.parse()` with await) — the
  Phase 3 change is structured-concurrency (async let / task group), not raw
  threads. Follow old-repo swiftconcurrency guidelines.

## Decision

(pending user) — candidate for Phase 3 implementation after 002 results, since
002 may shrink compile cost and change this experiment's payoff arithmetic
(smaller compile = less to hide, same technique).
