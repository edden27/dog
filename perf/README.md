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
| baseline | Phase 1 state capture: env, hyperfine matrix vs docs table — no regressions, dog ≥ docs everywhere | confirmed (profiles pending) |

## Layout

- `baseline/` — Phase 1 diagnostics (env snapshot, benchmark re-validation, profiles)
- `experiments/NNN-slug/` — Phase 2 experiments
- `scripts/` — shared runners (see each script's header for usage)
