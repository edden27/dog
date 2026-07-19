# baseline — Phase 1 state capture

Status: confirmed (speed matrix done 2026-07-18; profiles in progress)
Date: 2026-07-18 · Machine: M2 Max 12-core / 32GB, macOS 26.2 · dog commit: c9d278e · Swift 6.3.3 · hyperfine 1.20.0 · bat 0.26.1 (theme UtilityDark via config)
Full environment: `env.txt` (regenerate with the command block in git history / rerun section below).

## Question

Where does dog stand today vs the documented 2026-04-12 benchmark table
(`/Users/eddenamber/Code/vitepress-test/docs/benchmarks.md`), after the
bold/italic fixes (commits 5382fa5, 2cb7e1e)? Is any drift real regression or
run-to-run noise? This is the reference point every Phase 2/3 claim measures
against.

## How to reproduce

```sh
cd /Users/eddenamber/Projects/dog
swift build -c release                       # binary must match HEAD

# Stage 1: everything except xlarge (~5 min)
bash perf/scripts/bench-matrix.sh perf/baseline/results tiny small medium
bash perf/scripts/bench-matrix.sh perf/baseline/results large

# Stage 2: xlarge (c + javascript only, bat is slow here, ~3 min)
bash perf/scripts/bench-matrix.sh perf/baseline/results xlarge

# Comparison table vs docs numbers
python3 perf/scripts/summarize-baseline.py perf/baseline/results
```

Conditions mirror the docs page exactly: `hyperfine --warmup 0 --runs 20`,
dog `--color always -P`, bat `--paging=never --color=always`, auto-detect
language, bat theme from user config (UtilityDark).

## Results

Full per-language tables: `summary.md`. Raw hyperfine JSONs: `results/`.

**Verdict: no regression from the bold/italic fixes (5382fa5, 2cb7e1e).** dog is
equal-or-faster than the documented 2026-04-12 numbers on every row.

| Size | avg ratio now | avg ratio docs | dog wins |
| ---- | ------------- | -------------- | -------- |
| tiny | 1.0x | 1.0x | pattern unchanged (heavy grammars still lose) |
| small | 1.3x | 1.2x | pattern unchanged |
| medium | 3.1x | 3.0x | 17/17 |
| large | 5.1x | 5.1x (5.0x recomputed) | 17/17 |
| xlarge | 7.0x | 7.0x | 2/2 |

dog deltas vs docs: −0.7% to −27.5% (all faster or equal within noise). Largest
gains: small/go −27.5%, small/yaml −21.9%, tiny/yaml −17.7%.

Data-quality notes:
- medium/yaml bat run had one outlier (bat 117.8±51.1ms → ratio 5.9x inflated);
  dog's side clean. Re-run before quoting that cell.
- large/c dog run had one outlier (83.5±21.3ms, sigma says noise).
- Docs "large avg 5.1x" recomputes to 5.0x from their own table rows (rounding).

Confirmed Phase 2 target: tiny/small heavy-grammar startup cost — cpp 0.1x,
swift 0.2x, ruby 0.3x, tsx 0.3x, rust 0.4x — unchanged since April.

## Heads-up

- Run sizes sequentially, never two hyperfine invocations at once — timing noise.
- Docs table numbers are integer-rounded ms; single-digit-ms rows show >10%
  "drift" from rounding alone. Use the sigma column in the summarizer, not raw
  percent, before calling anything a regression.
- bat MUST have `--color=always` or it detects the /dev/null pipe and skips
  highlighting (~30x faster than real — documented trap).
- `scripts/benchmarks/bench.sh` discards hyperfine JSONs (means only); that is
  why `perf/scripts/bench-matrix.sh` exists. Command strings are mirrored 1:1.

## Decision

(pending user review of results)
