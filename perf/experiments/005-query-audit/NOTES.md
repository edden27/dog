# 005 — query/startup audit: does dog do unnecessary work per run?

Status: confirmed (audit complete — no waste found)
Date: 2026-07-18 · dog commit: 85a8a49

## Question

Does dog compile queries it doesn't need, eagerly load grammars, or carry
other per-run fixed work a lazy path could skip? (Old-repo perf opportunities
#1 "lazy query compilation" and #5 "lazy grammar loading".)

## How to reproduce

Source reading (line refs at commit 85a8a49) cross-checked against the
startup-decomposition metrics in `perf/baseline/startup/summary.md`:

- `Sources/dog/Parsing/Languages/LanguageRegistry.swift:118` — registry init
  registers 17 entries with RAW query bytes; no compilation.
- `Sources/dog/Parsing/Languages/LanguageEntry.swift:133` (`ensureReady`) —
  the only `ts_query_new` call site; runs lazily on first parse of that
  language only.
- Metric cross-check: blank-file cost scales per language (cpp +122ms …
  json +0.4ms) — if all queries compiled eagerly, every language would pay
  the sum. Floor above `--version` (4.5ms) is ~0.6ms (css/html/json ≈5.1ms),
  which bounds registry init + alias table + theme + detection.

## Results

1. **No redundant query compiles.** Exactly one `ts_query_new` per run, for
   the detected language. Opportunities #1/#5 are already implemented.
2. **Fixed pipeline floor ≈0.6ms** — not worth attacking.
3. **Dead weight (size, not speed):** `TreeSitterMarkdownInline` is imported +
   linked (`LanguageRegistry.swift:32`) and `EmbeddedQueries.markdown_inline`
   (`EmbeddedQueries.swift:3579`) is embedded, but never registered and never
   compiled. Presumably scaffolding for future inline-markdown highlighting.
   Flag to user before touching — removing saves binary bytes only.

## Heads-up

- Don't mistake `EmbeddedQueries` static arrays for lazy-per-language: registry
  init touches all 17, materializing every array — but that's inside the 0.6ms
  floor, measured. Leave it alone.

## Decision

Audit closes the startup question: the ONLY remaining tiny-tier lever is the
query-compile cost itself → experiment 003 (compiled-query cache) if the
tiny-tier headline is wanted, since 002 (pattern rewrites) was skipped.
