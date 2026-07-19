# Phase 3 implementation handoff

Living doc. Each section is one confirmed optimization ready to implement, with
full paths, code, verification gates, and gotchas. Written for an agent (or
human) with NO prior context — read `~/Projects/dog/perf/README.md` for the
experiment evidence behind each item. Add sections as more experiments confirm.

Branch: `perf-tuning` (off `main`). Benchmark source of truth:
`~/Code/vitepress-test/docs/benchmarks.md`.

## Ground rules (from project memory — do not skip)

- No `import Foundation` anywhere in dog. stdlib + Darwin/Glibc only.
- No abbreviated identifiers in Swift (`index` not `i`).
- Small steps: one concern per commit; no drive-by refactors.
- Keep the `LanguageEntry` actor — de-actoring was already tested by the user
  and was NOT faster (slower if anything). Do not "simplify" it away.
- Never push / create PRs without explicit user approval.
- Every change ships with: `swift test` green, byte-diff gate (below), and the
  relevant bench re-run. No metric, no merge.

## Shared verification gates

Byte-diff gate — output must be identical before/after (run from repo root
`~/Projects/dog`; stash a pre-change binary first):

```sh
cp .build/release/dog /tmp/dog-before
# ...build the change...
swift build -c release
for lang_dir in scripts/fixtures/performance/*/; do
  fixture=$(ls "$lang_dir"tiny.* 2>/dev/null | head -1); [ -z "$fixture" ] && continue
  /tmp/dog-before --color always -P "$fixture" > /tmp/before.out
  .build/release/dog  --color always -P "$fixture" > /tmp/after.out
  cmp -s /tmp/before.out /tmp/after.out || echo "$(basename "$lang_dir") DIFFERS"
done
```

Bench regression check (dog vs dog comparative, no bat needed):

```sh
hyperfine --warmup 1 --runs 10 \
  "/tmp/dog-before --color always -P scripts/fixtures/performance/typescript/large.ts > /dev/null" \
  ".build/release/dog  --color always -P scripts/fixtures/performance/typescript/large.ts > /dev/null"
```

Full matrix when a change is expected to move documented numbers:
`bash ~/Projects/dog/perf/scripts/bench-matrix.sh <outdir> tiny small medium large xlarge`
then `uv run python3 ~/Projects/dog/perf/scripts/summarize-baseline.py <outdir>`
(NOT bare `python3` — Homebrew 3.14 pyexpat is broken; `uv run` works).

---

## Item 1 — thin LTO release build (from experiment 006) — IMPLEMENTED 2026-07-18

**Final form: C-only thin LTO — `swift build -c release -Xcc -flto=thin`.**

**Evidence:** `~/Projects/dog/perf/experiments/006-build-flags/NOTES.md` plus
Phase 3 follow-up measurements:

- Full LTO (`-Xswiftc -lto=llvm-thin -Xcc -flto=thin`) gives −6..−10% but
  **breaks non-native builds**: the dual-arch (`--arch arm64 --arch x86_64`)
  and cross-arch (`--arch x86_64`) link steps look for `.o` files where swiftc
  emitted bitcode ("File not found: ... ToolInfo.o"). The native arm64 build
  only worked by accident (bitcode sprayed into cwd — the `*.bc` mess).
- C-only LTO (`-Xcc -flto=thin`) measured within 0–1% of full LTO on every
  probe (c/xlarge −6.7% vs −7.2%, go/large −8.7% vs −9.0%, typescript/large
  −6.6% vs −6.4%) — the win is C↔C inlining in tree-sitter, the Swift half is
  noise. Works in native, cross-arch, AND universal builds; no `.bc` spray;
  output byte-identical (all 17 languages, tiny+large).

**Done:**

- `~/Projects/dog/Makefile` `release-macos` → `swift build -c release --arch
  arm64 --arch x86_64 -Xcc -flto=thin` (with rationale comment).
- `~/Projects/dog/scripts/benchmarks/bench.sh` error message names the new
  canonical command.
- `~/Projects/dog/.gitignore` ignores `*.bc` (defends against anyone using the
  Swift-LTO flag again).
- NOT in Package.swift (`unsafeFlags` would make dog unconsumable as an SPM
  dependency for dogtml).

**Still open for this item:**

- Docs site (`~/Code/vitepress-test/docs/`) build/install instructions — needs
  user sign-off (front-facing).
- Linux: `-flto=thin` under the Docker build (`make release-linux` →
  `scripts/generate/linux.sh`) unverified — needs lld with LTO plugin. Verify
  before adding the flag to the Linux path; macOS-only until then.

Gotchas:

- NEVER re-add `-Xswiftc -lto=llvm-thin` — see breakage above.
- After an Xcode/toolchain update, stale LTO bitcode in `.build` can produce
  odd link errors → `swift package clean` and rebuild.
- Profiling note for future perf work: LTO inlining blurs Time Profiler
  attribution; profile non-LTO builds when attribution matters.

---

## Item 2 — overlap query compile with parse (from experiment 004, confirmed at harness level)

**Evidence:** `~/Projects/dog/perf/experiments/004-overlap-compile-parse/NOTES.md`
— saving ≈ min(parse, compile): 86.7ms (36%) cpp/large, 42.6ms (14.7%)
typescript/large, ~0 on tiny (no regression there either, but measure).

**File:** `~/Projects/dog/Sources/dog/Parsing/Languages/LanguageEntry.swift`
(the ONLY file that changes; ~60 lines restructured).

Current flow (sequential, all on the actor): `parse()` → `ensureReady()`
(ts_query_new + predicate table + capture-token table = the 10–122ms per-language
init) → `ts_parser_parse_string` → `executeQuery`.

Target flow: query compile runs as a concurrent child task while the tree
parses; join before `executeQuery`.

Sketch (adapt to house style; names must be unabbreviated):

```swift
/// Immutable result of query compilation. Safe to send across tasks: the
/// pointer is created once here and never mutated (same argument as
/// SendablePointer at the top of this file).
private struct CompiledQuery: @unchecked Sendable {
  let query: OpaquePointer
  let patternPredicates: [[PredicateEvaluator.QueryPredicate]]
  let captureTokenTypes: [TokenType?]
}

/// Pure — touches no actor state, callable off-actor.
private nonisolated static func compileQuery(
  tsLanguage: SendablePointer, queryBytes: [UInt8]
) -> CompiledQuery? {
  // body = current ensureReady() compile section:
  //   ts_query_new + PredicateEvaluator.parseAll + capture table loop
  // returns nil on compile failure (caller logs Bark.warning, renders plain)
}

func parse(sourceBytes: [UInt8]) throws -> [SyntaxToken] {
  if tsQuery == nil, let queryBytes {
    // compile ∥ parse — the experiment-004 overlap
    async let compiled = Self.compileQuery(
      tsLanguage: tsLanguage, queryBytes: queryBytes)
    let tsTree = try parseTree(sourceBytes: sourceBytes)   // existing parse body
    defer { ts_tree_delete(tsTree) }
    guard let compiled = await compiled else { return [] } // plain-output fallback
    commit(compiled)                                        // store into actor state
    return executeQuery(compiled.query, tree: tsTree, sourceBytes: sourceBytes)
  }
  // warm path (second file in same run): unchanged sequential flow
  ...
}
```

Requirements:

- Keep the actor. Reentrancy: the `await` opens the actor to a second caller —
  make the ready-state three-valued (idle / in-flight Task / ready) and have a
  concurrent second caller await the same in-flight task rather than compiling
  twice. Single-file CLI never hits this; correctness still required.
- `deinit` still deletes the query exactly once.
- Compile-failure path must behave exactly as today: `Bark.warning`, empty
  tokens, plain render (see experiment 001 for why this fallback is
  load-bearing).
- Swift concurrency guidelines:
  `~/Code/treesiter-cli-tmp/.claude/skills/project-guidelines/swiftconcurrency.md`.

Verification:

1. `swift test` (ParsingTests cover token output).
2. Byte-diff gate, all 17 languages, tiny AND large fixtures.
3. Bench: expect cpp/large ~281→~195ms, typescript/large ~482→~440ms
   (baseline numbers in `~/Projects/dog/perf/baseline/summary.md`); tiny tier
   must NOT regress (task-spawn cost is µs — verify, don't assume):
   `bash ~/Projects/dog/perf/scripts/bench-matrix.sh /tmp/overlap-check tiny`
4. Multi-file invocation sanity: `dog a.cpp b.cpp` — second file uses the warm
   path (compiled query cached).

---

## Item 3 — surface query-compile failures (robustness fix from experiment 001)

**Evidence:** during experiment 001, python's query failed to compile on the
0.26 runtime and dog silently rendered the whole language as plain
uncolored text — zero signal to the user. In release builds the existing
`Bark.warning` calls compile out entirely (`#if DEBUG` in
`~/Projects/dog/Sources/dog/Diagnostics/Bark.swift`), so the failure is
invisible even with `DOG_LOG_LEVEL=debug`.

**Desired behavior:** keep the graceful degradation (plain render, exit 0 —
correct for a cat-replacement; stdout must stay pipe-clean) but emit a
release-visible one-line warning to **stderr**:

```
dog: highlight query for 'python' failed to compile (offset 1633); rendering without highlighting
```

**Files:**

- `~/Projects/dog/Sources/dog/Parsing/Languages/LanguageEntry.swift` — the
  compile-failure path in `ensureReady()` (moves into `compileQuery(...)` if
  Item 2 lands first; emit at the join point). Two failure sites: nil
  queryBytes ("no highlight query") and `ts_query_new` returning nil.
- `LanguageEntry` does NOT know its language name today (registered by name in
  `LanguageRegistry.swift` but the entry never stores it) — add a
  `languageName: String` let to the entry so the warning can name the language;
  registry passes it at `register(...)`.
- Warning emission: direct `write(STDERR_FILENO, ...)` (Darwin/Glibc, no
  Foundation), NOT `Bark` (compiles out of release). A tiny
  `releaseWarning(_:)` helper next to Bark keeps callsites clean.

**Tests:**

- Unit (XCTest, `~/Projects/dog/tests/dogTests/`): construct a `LanguageEntry`
  with deliberately invalid query bytes, assert `parse()` returns `[]` (plain
  fallback preserved) — this pins the degradation contract.
- Compat-level: stdout byte-diff gate must show ZERO change on all fixtures
  (warning goes to stderr only; scenario "pipe color strip" in
  `scripts/test/compat.sh` must stay green).

**Interaction with Item 2:** if the overlap lands first, the failure surfaces
after the join; same message, same stderr channel. Implement whichever lands
first, wire the other to it.

## Backlog (not yet implementation-ready)

- 002 (per-pattern query compile cost) — SKIPPED by user decision 2026-07-18.
- 003 (compiled-query serialization/cache) — only if the tiny-tier story is
  worth the tree-sitter patch; revisit after 004/006 ship. After 005 closed the
  audit, this is the ONLY remaining tiny-tier lever.
- 007 alloc patches — REJECTED by user (~1% wall, −11% peak memory, judged not
  worth churn). Exact re-appliable patches + measurements:
  `~/Projects/dog/perf/experiments/007-alloc-reduction/NOTES.md`. Deeper
  capture-loop restructuring: uncertain payoff, high risk, do not attempt
  without fresh profile evidence.
- 005 found `TreeSitterMarkdownInline` linked + `EmbeddedQueries.markdown_inline`
  embedded but never used — binary-size dead weight only. Ask user before
  removing (may be scaffolding for future inline-markdown highlighting).

## Additional gotchas discovered during experiments

- Thin-LTO builds emit stray `*.bc` files into the repo root — clean with
  `rm ~/Projects/dog/*.bc` before committing (or gitignore them as part of
  Item 1 adoption).
- `Bark` logging compiles out of release (`#if DEBUG` around everything) —
  release-build instrumentation must use write(2)/fputs directly.
- dog silently renders a language UNHIGHLIGHTED if its query fails to compile
  (see experiment 001) — after any query or runtime change, byte-diff outputs;
  "it runs" proves nothing. Item 3 above makes the failure visible on stderr;
  the byte-diff discipline still applies.
