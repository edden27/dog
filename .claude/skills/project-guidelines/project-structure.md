# Project Architecture & File Structure

**Context:** Swift CLI Tool (ArgumentParser + Foundation)
**Style:** Feature-Based, Pragmatic Flattened

## 1. Actual Directory Layout

```text
cli/
  Package.swift
  Sources/dog/
    Dog.swift                        — @main AsyncParsableCommand entry point, all flags

    Commands/
      PrintCommand.swift             — default: read file/stdin → highlight → output

    Output/
      ANSIOutput.swift               — [UInt8] buffer, color/text/reset/flush (no Rainbow)
      TTYDetection.swift             — isatty, NO_COLOR, FORCE_COLOR, --color flag
      LineNumberFormatter.swift      — (Step 4) line number gutter rendering
      HeaderFormatter.swift          — (Step 4) filename header

    Theme/
      TokenType.swift                — (Step 4) enum mapping capture names → types
      UtilityDarkTheme.swift         — (Step 4) hardcoded default theme

    Parsing/                             — (Step 2) tree-sitter parsing module
      SyntaxToken.swift                  — token struct (name + UTF-8 byte offsets)
      SyntaxParser.swift                 — public API: parse(source:language:) → [SyntaxToken]
      Languages/
        LanguageEntry.swift              — actor: grammar + query, lazy init, parse()
        LanguageRegistry.swift           — 17 grammars, aliases, lookup (conditional via #if traits)

    Detection/                           — (Step 3) language detection
      LanguageDetector.swift             — four-stage cascade (explicit → filename → ext → shebang)
      LanguageMap.swift                  — extension/filename/interpreter tables (from linguist)

    Diagnostics/
      Bark.swift                         — debug logger, ANSI-colored, #if DEBUG
      DogError.swift                     — typed error enum, all cases
      ErrorHandler.swift                 — central error router, exit codes, SIGPIPE

  Tests/dogTests/
    ...                                  — Swift unit tests (swift-testing)

tests/
  scripts/
    scaffold/                            — shell-based integration tests for CLI behavior
      run-all.sh                         — runner for all test-*.sh files + swift test
      helpers.sh                         — shared pass/fail helpers
      test-help.sh                       — --help output verification
      test-io.sh                         — file reading, stdin, --version
      test-color.sh                      — TTY detection, --color, NO_COLOR, FORCE_COLOR
      test-errors.sh                     — error handling, exit codes
      test-error-types.sh               — each DogError → correct exit + message
      test-ansi-output.sh               — ANSI byte sequence verification
      test-sigpipe.sh                    — pipe to head/grep without crash
      test-bark.sh                       — debug-only logging, release silent
      test-stubs.sh                      — stub commands don't crash
    compat.sh                            — 13 bat compatibility scenarios (Pillar 3)
    profile-dog.sh                       — profiling: hyperfine + /usr/bin/time + sample + xctrace
    fetch-fixtures.py                    — download fixture files via GitHub API
    bat-coverage.py                      — measure bat's highlighting coverage per language
    linux-test.sh                        — cross-platform Docker test runner
  fixtures/
    jquery.js                            — canonical benchmark file (10,716 lines)
    performance/                         — 74 files across 17 languages × 4 sizes
  benchmarks/
    proof/                               — proof-of-concept tree-sitter vs bat benchmark (used by profile-dog.sh)
  reference/
    nvim-queries/                        — reference nvim-treesitter highlight queries
    official-queries/                    — reference official grammar repo queries
```

## 2. Rules

### File Placement

- **One type per file** when the type is substantial. Small helpers live with the type that uses them.
- **File names match the primary type:** `DogError.swift` contains `enum DogError`.
- **Group by domain:** Output/, Diagnostics/, Commands/, Theme/ — not by type (no "Models/" or "Protocols/").

### Directory Nesting

- **One level max** inside a feature folder. No `Commands/Highlight/Helpers/Utils/`.
- If a folder has only one file, it shouldn't be a folder.
- If a folder grows past ~7 files, consider splitting into subfolders.

### The Entry Point

`Dog.swift` is the single source of truth for:
- All CLI flags and options
- Routing to the correct command
- Global setup (SIGPIPE handler, color detection)

### Service Expansion

- Start with a single file (e.g. `LanguageDetector.swift`).
- If it grows past ~300 lines, convert to a folder with the main file + helpers.

## 3. Runtime Data Layout

CLI tools use XDG-style conventions:

```text
~/.config/dog/
  config.toml          — user preferences
  themes/              — custom theme JSON files
    mytheme.json

~/.cache/dog/          — (future) downloaded grammars, compiled queries
```

No `~/Library/Application Support/` — this is a CLI, not a macOS app.

## 4. Test Organization

Three test systems:

- **Swift unit tests** (`cli/Tests/dogTests/`) — 42 tests across 7 suites for internal logic (token parsing, ANSI codes, errors, coverage). Run via `swift test`.
- **Shell scaffold tests** (`tests/scripts/scaffold/`) — 49 integration assertions across 9 suites for CLI behavior (pipe detection, exit codes, flag parsing). Run via `bash tests/scripts/scaffold/run-all.sh`.
- **Compatibility tests** (`tests/scripts/compat.sh`) — 13 scenarios verifying dog is a drop-in bat replacement. Run via `bash tests/scripts/compat.sh`.

Both are needed. Shell tests verify the binary works as a CLI tool. Swift tests verify internal correctness.
