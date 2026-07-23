# Subset builds: fall back to plain text for excluded languages

**Status: planned, not started.** Do on its own branch, target the first update after v0.1.0.
Line numbers below are valid at `main` @ 967cf8c (2026-07-22) — re-check before editing.

## Behavior today (verified against the binary, 2026-07-22)

- Full build: files with extensions dog has no mapping for (`.txt`, `.xyz`) render as **plain text**, exit 0.
- Subset build (`make build TRAITS=SwiftLib,JSONLib`): a `.rs` file **errors** `unknown language 'rust'. Use --list-languages...`, exit 2. The detector's static tables still map `.rs` → `rust`, but the registry only holds compiled-in traits, so the parser throws.
- Explicit `-l rust` errors too — that behavior is correct and must **stay** after the fix (user asked for the language by name).

## Goal

Auto-detected file whose language wasn't compiled in → degrade to plain text like any unknown file type (optionally with a stderr note, e.g. `this build was compiled without rust — showing plain text`). Explicit `-l` keeps erroring.

## Code path

- `/Users/eddenamber/Projects/dog/Sources/dog/Commands/PrintCommand.swift`
  - line 15: `let language: String?` — the explicit `-l` flag; `nil` means auto-detect. This is the gate for the fix.
  - lines 81–85: `LanguageDetector.detect(filename:sourceBytes:explicit:)` call.
  - lines 91–94: parse branch — anything detected goes to `SyntaxParser.parse`, which throws for missing registry entries.
  - lines 95–99: existing plain-text branch — reuse it for the fallback.
- `/Users/eddenamber/Projects/dog/Sources/dog/Parsing/SyntaxParser.swift` lines 13–19: `parse()` throws `DogError.unknownLanguage` when `LanguageRegistry.shared.lookup` returns nil. Unchanged by the fix — explicit `-l` still funnels through here and errors.
- `/Users/eddenamber/Projects/dog/Sources/dog/Parsing/Languages/LanguageRegistry.swift` lines 376–378 `lookup(_:)`, lines 381–383 `isSupported(_:)` — use `isSupported` for the pre-check.
- `/Users/eddenamber/Projects/dog/Sources/dog/Detection/LanguageDetector.swift` line 22 `detect(...)` — static tables, always know all 17 languages regardless of traits. Leave as-is.
- NOT this one: `/Users/eddenamber/Projects/dog/Sources/dog/Dog.swift` lines 533–539 throw `unknownLanguage` for `--woof` snippets — unrelated, don't touch.

## The fix (one condition in PrintCommand)

Current code, `PrintCommand.swift` lines 91–99:

```swift
if let lang = detectedLang {
  let tokens = try await SyntaxParser.parse(sourceBytes: sourceBytes, language: lang)
  Bark.debug("parsed \(tokens.count) tokens for \(lang)")
  (output, lineCount) = renderColorized(sourceBytes: sourceBytes, tokens: tokens)
} else {
  output = ANSIOutput(enabled: colorEnabled, estimatedSize: sourceBytes.count)
  lineCount = sourceBytes.reduce(0) { $0 + ($1 == 0x0A ? 1 : 0) } + 1
  output.text(sourceBytes[...])
}
```

Change the branch condition so an auto-detected language that isn't compiled in takes the plain branch:

```swift
if let lang = detectedLang,
   language != nil || LanguageRegistry.shared.isSupported(lang) {
  // parse branch unchanged — explicit -l for a missing language still errors in parse()
} else {
  // plain branch unchanged; optionally, before it:
  // if let lang = detectedLang { stderr note "compiled without \(lang) — showing plain text" }
}
```

`language != nil` = the flag was explicit → let `parse()` throw its error with suggestion. Default full builds never hit the new path (every detectable language is in the registry), so shipped-binary behavior is byte-identical.

## Verify

```sh
make build TRAITS=SwiftLib,JSONLib
echo 'fn main() {}' > /tmp/t.rs
.build/release/dog /tmp/t.rs            # expect: plain text, exit 0 (+ stderr note if added)
.build/release/dog -l rust /tmp/t.rs    # expect: unknown language error, exit 2
make build                               # full build
swift test                               # 197 green, no behavior change
```

Note: `swift test` runs against the default (all-traits) build, so the excluded-trait path can only be smoke-tested manually on a TRAITS build — that's the two commands above.

## Docs to update when this ships

- `/Users/eddenamber/Code/vitepress-test/docs/installation.md` — "Custom language builds" section, first bullet under "Two things to know": currently says excluded languages error with `unknown language` and don't fall back to plain text. Flip it to describe the fallback (and the stderr note if added), and that `-l <name>` still errors.
- Check the README From-source/custom-builds mention at that time for the same claim (not currently believed to state it — verify then).
