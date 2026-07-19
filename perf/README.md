# perf/ — performance work index

Branch: `perf-tuning` (off `main` @ c9d278e). Source of truth for target numbers:
`/Users/eddenamber/Code/vitepress-test/docs/benchmarks.md` (captured 2026-04-12).

Rules for this directory:
- Every experiment gets a numbered dir under `experiments/` with a `NOTES.md`
  (question, exact repro commands, results, heads-ups, decision). Numbers are
  never reused, rejected experiments stay.
- No claim without a metric. Raw outputs live in each experiment's `results/`.
- dog source is never touched from here; implementation happens in Phase 3 as
  separate commits.

## Index

| # | What | Status |
| - | ---- | ------ |
| baseline | Phase 1 complete: no regressions vs docs; tiny-tier deficit = ts_query_new pattern analysis (84–95%); large-tier = ts parse 54% + query exec 22% + swift alloc 14–19%; write cost 0.2% (buffering dead end); memory clean | confirmed |
| [001](experiments/001-tree-sitter-0.26/NOTES.md) | tree-sitter 0.26 upgrade: 1–4% slower, no init win, breaks python query (supertype validation) — stay on 0.25.x | rejected |
| [006](experiments/006-build-flags/NOTES.md) | build flags: thin LTO wins −6..−10% throughput, output byte-identical; O3 subsumed, -Ounchecked worthless | confirmed |

## Layout

- `baseline/` — Phase 1 diagnostics (env snapshot, benchmark re-validation, profiles)
- `experiments/NNN-slug/` — Phase 2 experiments
- `scripts/` — shared runners (see each script's header for usage)
