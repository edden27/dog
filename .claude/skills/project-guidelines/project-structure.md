# Project Architecture & File Structure

**Context:** Swift CLI Tool (ArgumentParser + Foundation)
**Style:** Feature-Based, Pragmatic Flattened

## 1. Actual Directory Layout

```text
dog/
  Package.swift
  Makefile                           — build (release + LTO), install, package
  install.sh
  Sources/dog/
    Dog.swift                        — @main AsyncParsableCommand: all flags, colorized-help
                                       interception, run() routing to the mode helpers

    Commands/
      PrintCommand.swift             — default mode: read file/stdin → detect → parse → render → pager
      PrintCommand+Render.swift      — renderColorized per-line loop + one-time RenderLayout setup
      PrintCommand+Gutter.swift      — pre-built line-number gutter tables + wrap continuation prefixes
      PrintCommand+BulkEmit.swift    — non-wrapping fast path: ASCII bulk slices + measured non-ASCII twin
      WrappedLineWriter.swift        — soft/hard wrap emission for lines wider than the terminal
      Dog+Woof.swift                 — --woof fzf browser, --woof-preview, snippet rendering
      Dog+Listings.swift             — --list-languages / --list-themes output
      Dog+Completions.swift          — shell-completion providers for --language / --theme

    Output/
      ANSIOutput.swift               — [UInt8] output buffer: color/text/reset/flush, ANSICodes
      Style.swift                    — style packed into UInt64 + pre-computed ANSI bytes
      HelpFormatter.swift            — colorizes --help output
      Pager.swift                    — pager spawn (posix_spawnp)
      TerminalSize.swift             — terminal window size
      TextMetrics.swift              — WidthWalker: display-width measurement (wide chars, clusters)
      TTYDetection.swift             — isatty, NO_COLOR, FORCE_COLOR, --color flag

    Theme/
      TokenType.swift                — enum mapping capture names → token types
      UtilityDarkTheme.swift         — built-in default theme
      UtilityBrightTheme.swift       — built-in light theme (--light)
      Dog+ThemeResolution.swift      — --theme/--light/--dark resolution → ResolvedThemeStyles
      DefaultThemeArtifact.swift     — --set-default-theme save/load (packed binary artifact)
      EmbeddedWoofSnippets.swift     — GENERATED (scripts/generate/generate-woof-snippets.sh)
      Zed/
        ZedThemeLoader.swift         — Zed theme JSON → color table
        ZedThemeScanner.swift        — zero-copy JSON byte scanner
        ZedThemeDirectoryScanner.swift — themes directory listing (--list-themes, completions)
        ZedThemeResolver.swift       — theme name / path / `file:variant` resolution
        ZedThemeVariantWalker.swift  — locate a variant's byte range inside a theme bundle

    Parsing/
      SyntaxParser.swift             — public API: parse(sourceBytes:language:) → [SyntaxToken]
      SyntaxToken.swift              — token struct (type + UTF-8 byte offsets)
      Languages/
        LanguageRegistry.swift       — grammars, aliases, lookup (conditional via #if traits)
        LanguageEntry.swift          — actor: grammar + query, lazy init, parse()
        FastMatcher.swift            — fast-path capture-name matching
        PredicateEvaluator.swift     — tree-sitter query predicate evaluation
        EmbeddedQueries.swift        — GENERATED (scripts/generate/generate-embedded-queries.sh)
        EmbeddedCompiledQueries.swift — GENERATED (scripts/generate/query-blobs.sh)

    Detection/
      LanguageDetector.swift         — four-stage cascade (explicit → filename → ext → shebang)
      LanguageMap.swift              — extension/filename/interpreter tables (from linguist)

    Diagnostics/
      Bark.swift                     — debug logger, ANSI-colored, #if DEBUG
      DogError.swift                 — typed error enum, all cases
      ErrorHandler.swift             — central error router, exit codes, SIGPIPE

    Config/
      ConfigPaths.swift              — XDG config paths, ~ and ${VAR} expansion

    Resources/
      queries/                       — highlight query sources (*.scm), embedded at build time
      woof/                          — woof snippet sources, embedded at build time

  Sources/CWcwidth/                  — vendored C wcwidth (glibc has no wcwidth_l)
  LocalPackages/                     — vendored tree-sitter runtime + grammar packages
  Tests/dogTests/                    — Swift unit tests (swift-testing)

  scripts/
    scaffold/                        — shell integration tests for CLI behavior + run-all.sh
    test/                            — compat.sh (bat drop-in scenarios), colorgrid, linguist samples
    fixtures/performance/            — bench fixtures, 17 languages × sizes
    generate/                        — generators for the three Embedded*.swift files
    benchmarks/                      — standalone micro-benchmark swift files
    release/                         — publish.sh
    pre-commit.sh                    — lint hook; install with
                                       cp scripts/pre-commit.sh .git/hooks/pre-commit

  perf/                              — bench-matrix runner, baselines, bench receipts
```

## 2. Rules

### File Placement

- **One type per file** when the type is substantial. Small helpers live with the type that uses them.
- **File names match the primary type:** `DogError.swift` contains `enum DogError`.
- **Group by domain:** Output/, Diagnostics/, Commands/, Theme/ — not by type (no "Models/" or "Protocols/").
- **Generated files are never hand-edited.** The three Embedded*.swift files carry a
  "do not edit" header, are excluded from linting, and change only by rerunning
  their generator script.

### Directory Nesting

- **One level max** inside a feature folder. No `Commands/Highlight/Helpers/Utils/`.
- If a folder has only one file, it shouldn't be a folder.
- If a folder grows past ~7 files, consider splitting into subfolders (that's how
  Theme/Zed/ happened).

### The Entry Point

`Dog.swift` is the single source of truth for:
- All CLI flags and options
- Routing to the correct mode
- Global setup (SIGPIPE handler, color detection)

Mode implementations live in `Dog+<Mode>.swift` extension files in the matching
domain folder (`Commands/Dog+Woof.swift`, `Theme/Dog+ThemeResolution.swift`) —
`run()` stays a flat router.

### Service Expansion

- Start with a single file (e.g. `LanguageDetector.swift`).
- If it grows past ~300 lines, split into extension files by concern —
  `PrintCommand.swift` + `PrintCommand+Render/+Gutter/+BulkEmit.swift` is the pattern.

## 3. Runtime Data Layout

CLI tools use XDG-style conventions:

```text
~/.config/dog/
  themes/              — custom theme JSON files (Zed format)
  default-theme        — packed artifact written by --set-default-theme
  config.toml          — (planned) user preferences; loader not wired yet
```

No `~/Library/Application Support/` — this is a CLI, not a macOS app.

## 4. Test Organization

Three test systems:

- **Swift unit tests** (`Tests/dogTests/`) — 222 tests across 31 suites for internal
  logic (parsing, detection, themes, errors, width). Run `swift build`, then `swift test`.
- **Shell scaffold tests** (`scripts/scaffold/`) — integration assertions for CLI
  behavior (pipe detection, exit codes, flag parsing, error types). Run via
  `bash scripts/scaffold/run-all.sh`.
- **Compatibility tests** (`scripts/test/compat.sh`) — scenarios verifying dog is a
  drop-in bat replacement.

All are needed. Shell tests verify the binary works as a CLI tool. Swift tests verify
internal correctness. Fixture files for tests and benches live under `scripts/fixtures/`.
