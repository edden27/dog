# 006 — build-flag matrix

Status: open
Date: 2026-07-18 · Machine: M2 Max, macOS 26.2 · dog commit: 4433245 · Swift 6.3.3

## Question

Is there free speed in compiler flags, with zero source changes? Baseline
profile says tree-sitter parse (54% of c/xlarge) and query exec (22%) are all
C code — SPM builds C targets at `-O2` by default; Swift release is `-O` +
whole-module. Candidates:

| variant | flags | rationale |
| --- | --- | --- |
| baseline | (none) | control |
| cc-O3 | `-Xcc -O3` | C hot loops (parse/lex/query) |
| cc-O3-native | `-Xcc -O3 -Xcc -mcpu=native` | Apple-Silicon scheduling/codegen |
| lto-thin | `-Xswiftc -lto=llvm-thin -Xcc -flto=thin` | cross-module inlining |
| swift-Ounchecked | `-Xswiftc -Ounchecked` | drops Swift bounds/overflow checks — SAFETY TRADE-OFF, measured for information only |

## How to reproduce

```sh
cd /Users/eddenamber/Projects/dog
bash perf/experiments/006-build-flags/build-variants.sh <variant-dir>   # ~15 min, stashes dog-<name> binaries
bash perf/experiments/006-build-flags/bench-variants.sh <variant-dir> perf/experiments/006-build-flags/results
```

Probes: cpp/tiny + swift/tiny (query-compile cost — also C code), then
typescript/large, go/large, c/xlarge (throughput). hyperfine warmup 1, runs 10,
all variants in one comparative invocation per fixture.

Correctness gate for any winning variant: byte-diff all 17 tiny outputs vs
baseline binary before promoting it.

## Results

Raw hyperfine JSONs: `results/`. All five variants built (distinct md5s
verified — SPM does apply `-Xcc` flag changes; builds were ~20s each, not the
predicted minutes).

| probe | lto-thin | cc-O3 | cc-O3-native | Ounchecked |
| --- | --- | --- | --- | --- |
| c/xlarge | **−7.8%** | −2.5% | −2.2% | −0.4% |
| go/large | **−9.7%** | −2.2% | −2.2% | +0.0% |
| typescript/large | **−6.2%** | −1.7% | −1.8% | +0.9% |
| swift/tiny | **−2.5%** | −1.1% | −1.0% | −1.8% |
| cpp/tiny | −1.2% | +1.4% | −0.4% | −1.2% |

- **Winner: `-Xswiftc -lto=llvm-thin -Xcc -flto=thin`** — consistent −6 to −10%
  on throughput probes, small but positive on tiny (query compile barely
  benefits — it's one huge function, cross-module inlining can't help it).
- Combo lto-thin + `-Xcc -O3`: no further gain (xlarge slightly worse). O3
  alone ~2% — subsumed by LTO.
- `-Ounchecked` ≈ 0 everywhere → Swift bounds/overflow checks are NOT hot;
  never worth the safety trade.
- Correctness gate: lto-thin output byte-identical to baseline on all 17 tiny
  fixtures.

## Decision

(pending user) — candidate: adopt thin LTO as the release build configuration
in Phase 3. Note adoption mechanics are a docs/build-script change (SPM
`unsafeFlags` in Package.swift would make the package undependable for
consumers like dogtml — flags belong in the documented build command).

## Heads-up

- Each flag change forces a near-full SPM rebuild (~2–4 min; cpp grammar
  dominates). build-variants.sh restores a plain release build at the end so
  the tree never silently keeps a variant binary.
- `-Ounchecked` results, if attractive, are NOT adoptable without an explicit
  user decision — it removes bounds/overflow traps binary-wide.

## Decision

(pending)
