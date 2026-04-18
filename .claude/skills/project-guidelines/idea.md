# dog

**CLI:** `dog`

**Tagline:** "get out the cave, ditch the litter box"

A Swift CLI tool for syntax-highlighted file viewing, powered by tree-sitter. A modern replacement for `bat` (which replaces `cat`) with more accurate AST-based highlighting and a cleaner theming system (no tmTheme XML nightmare).

## Why

- bat uses TextMate grammars (regex-based) — tree-sitter is AST-based and more accurate
- bat themes are tmTheme XML, set via cache rebuild — painful to customize
- Proof benchmark: tree-sitter is 3.3x faster than bat on 10k-line files
- dog beats bat on token coverage for 13/17 languages

## How it works

1. Read file from path argument (or stdin)
2. Detect language from file extension, filename, or shebang (four-stage cascade from linguist data)
3. Parse with tree-sitter grammar, execute highlight query with predicate resolution
4. Map highlight captures → UtilityDark theme colors (pre-computed ANSI byte sequences)
5. Emit ANSI-colored text via raw `[UInt8]` buffer + `write(2)` syscall to terminal

## Key dependencies

- **swift-tree-sitter** (tree-sitter org) — Swift bindings for tree-sitter
- **edden27/tree-sitter-\*** (forked) — individual grammar repos for 17 languages
- **nvim-treesitter queries** (Apache 2.0) — highlight queries bundled in Resources/queries/, inheritance chains resolved, `#lua-match?` converted to `#match?`
- **swift-argument-parser** (Apple) — CLI argument parsing
- No Rainbow — we own ANSI output via `ANSIOutput` (~50 lines)

## Project structure

```
Sources/dog/
  Commands/           — CLI command implementations (PrintCommand, etc.)
  Config/             — configuration loading
  Detection/          — language detection (LanguageDetector, LanguageMap)
  Diagnostics/        — Bark logger, DogError, ErrorHandler
  Output/             — ANSIOutput, TTYDetection
  Parsing/            — tree-sitter parsing module (SyntaxParser, LanguageEntry, LanguageRegistry)
  Resources/queries/  — nvim-treesitter highlight queries (.scm files)
  Theme/              — theme definitions and color mapping
  Dog.swift           — entry point
```

