# 007 — Swift allocation reduction on the token/render path

Status: rejected (user decision — measured gains too small to justify source churn)
Date: 2026-07-18 · dog commit: a4394b7 · baseline binary: plain release at that commit

## Question

Profiles attribute 13.8–18.7% of large-file runtime to swift runtime/alloc
(retain/release, malloc/free, memmove, array growth). How much comes back from
the three obvious, zero-risk allocation fixes?

## What was measured first (probes, no opinion involved)

- Output expansion: colorized output is 6.4–12.3× source (ts 6.4×, cpp 7.5×,
  c 8.0×, json 10.7×, go 12.3×) — but `ANSIOutput` reserved only source×2.
  Measured via `dog --color always -P <fixture> | wc -c` vs `stat -f%z`.
- Token counts: 0.13–0.21 tokens per source byte (typescript/large 413k,
  go/large 407k) — token array built with no reserveCapacity.
- Sort frequency: `needsSort=true` fires on ~half the languages at large size
  (typescript 413k, cpp 165k, python 126k, c 69k tokens), measured with a
  temporary Bark.debug probe in a DEBUG build (`DOG_LOG_LEVEL=debug`; Bark
  compiles out of release — release probes need another mechanism).

## Patches tested (A+B, then A+B+C cumulative)

A. `LanguageEntry.executeQuery`: `tokens.reserveCapacity(sourceBytes.count / 8)`
B. `SyntaxParser.parse`: `tokens.sort {}` in place instead of `tokens.sorted {}`
   (avoids full-array copy when sort fires)
C. `PrintCommand.renderColorized`: computed buffer estimate
   `colorEnabled ? source + tokens*20 + lineCount*(contentCols+48)
                 : source + lineCount*(gutterCols+8)` replacing `source*2`

## Results (hyperfine warmup 1 runs 15, vs stashed baseline binary)

| probe | A+B | A+B+C |
| --- | --- | --- |
| typescript/large | −1% (~6ms) | −1% (~7ms) |
| go/large | −1% | 0% |
| c/xlarge | 0% | −1% (~19ms) |
| cpp/tiny | 0% | 0% (no tiny regression) |
| peak memory c/xlarge | — | **300MB → 268MB (−11%)** |

Byte-diff gate: all 17 languages, tiny+large, identical output for every patch
combination. Plain mode clean.

## Why the alloc bucket didn't shrink much

The 14–19% bucket is dominated by per-capture retain/release traffic and many
small allocations in the match loop, not the few large array growths. Reaching
it means restructuring the capture loop / token storage (e.g. SoA layout,
unmanaged buffers) — higher risk, uncertain payoff. Left as backlog.

## Heads-up

- Thin-LTO builds (experiment 006 flags) spray `*.bc` bitcode files into the
  repo root as a side effect — delete them (`rm *.bc`) or add to .gitignore
  before committing anything after an LTO build.
- Bark logging compiles out of release builds entirely (`#if DEBUG`) — any
  future release-build probe needs fputs/stderr directly, not Bark.
- The patch code above is exact and re-appliable; outputs verified identical,
  so re-adopting later is a copy-paste + re-measure job.

## Decision

**Rejected by user** (2026-07-18): ~1% wall clock isn't worth the source churn;
the −11% peak memory alone didn't change the call. All three patches reverted;
working tree back to a4394b7 state. Deeper alloc restructuring stays in backlog
with an honest "uncertain payoff" label.
