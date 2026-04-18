---
name: project-guidelines
description: Coding standards, Swift conventions, and project rules for dog. Load when writing, reviewing, or modifying code.
---

# dog — Project Guidelines

Rules for writing code in this project. Both for me (the human) and Claude to follow. Reference this before, during, and after writing code.

## Reference Documents

These sibling files contain detailed guidance on specific topics. Read them when relevant.

- [idea.md](idea.md) — Project overview, what we're building (dog — tree-sitter syntax highlighter CLI), and why
- [swift-coding-guidelines.md](swift-coding-guidelines.md) — Apple's Swift API Design Guidelines (naming, conventions, patterns)
- [swiftconcurrency.md](swiftconcurrency.md) — Swift 6 strict concurrency rules, Sendable, actors, async/await patterns
- [project-structure.md](project-structure.md) — **THE BIBLE** for file placement, directory layout, and architecture decisions. Consult when creating new files, commands, services, or reorganizing code

## Related Skills

- `/swift-check` — Run swift-format and swiftlint, reports results
- `/build-check` — Build the project, reports errors/warnings/success
- `/precommit-check` — Full pre-commit checklist (calls swift-check and build-check)

## Naming

- Functions describe what they do: `fetchDocumentation()`, `renderToMarkdown()`, not `doStuff()` or `process()`
- Booleans read as questions: `isLoaded`, `hasResults`, `shouldRefresh`
- Use Swift naming conventions — camelCase for functions/variables, PascalCase for types
- Follow Apple's Swift API Design Guidelines — see [swift-coding-guidelines.md](swift-coding-guidelines.md) for full reference:
  - Name things from the caller's perspective
  - Omit needless words: `remove(at: index)` not `removeItem(atIndex: index)`
  - Compensate for weak type info: `addElement(_ e: Element)` not `add(_ e: Element)` if the type isn't obvious

## Code Style

- Keep functions short. If it's over 40 lines, it probably does too much — break it up.
- Prefer boring obvious code over clever compact code. Three clear lines beat one dense one.
- No force unwraps (`!`) except in tests or when failure is genuinely a programmer error. Use `guard let` or `if let`.
- Use `guard` for early returns. Don't nest — exit early and keep the happy path unindented.
- Use enums for known sets of values rather than raw strings. Strings are typo magnets.
- Mark things `private` by default. Only expose what needs to be public.
- No dead code. Don't comment out code "just in case." Git has history.

## Linting & Formatting

- **swift-format** (formatter) and **SwiftLint** (linter) are both used. Default rules apply unless a `.swift-format` or `.swiftlint.yml` config is added to override specific rules.
- **While coding:** Run both on any files you create or modify. Claude should run `swift-format` on files after writing them and check `swiftlint` output before considering a task done.
- **Before committing:** Run both across the whole project:
  ```
  swift-format lint --recursive Sources/
  swiftlint lint --quiet
  ```
- **Pre-commit hook:** A git hook runs both automatically as a safety net. If either reports errors, the commit is blocked. Fix the issues, then commit again.
- If a specific rule is causing more pain than value, disable it in the config file with a comment explaining why — don't just ignore it.

## Comments

- Comment WHY, not WHAT. If the code needs a comment explaining what it does, rename things until it doesn't.
- Use `// TODO:` for planned improvements. Include enough context that future-you (or Claude) can act on it without re-researching.
- Use `// FIXME:` for known bugs or workarounds that should be fixed.
- Don't add doc comments to internal/private functions unless the behavior is genuinely non-obvious.
- Public API functions get a one-line doc comment describing what they do for the caller.

## File Organization

- One type per file when the type is substantial. Small helper types can live with the type that uses them.
- Group related files in directories by feature/domain (like the reference impl does: `reference/`, `hig/`, `video/`).
- Shared utilities go in a `shared/` or `common/` directory, not duplicated across features.
- File names match the primary type they contain: `SearchResult.swift` contains `struct SearchResult`.

## Error Handling

- Use typed errors (enums conforming to `Error`) rather than throwing generic strings.
- Provide enough context in errors to debug without a stack trace: "Failed to fetch documentation at /documentation/swiftui/view: 404" not "fetch failed".
- Handle errors at the boundary (CLI entry point), not deep in the call stack. Let errors propagate up with context.

## Dependencies

- Avoid them when possible. This is a CLI tool — the standard library and Foundation cover most needs.
- If a dependency is needed, justify it. "SwiftSoup for HTML parsing because regex on HTML is fragile" is a good reason. "Alamofire because I don't want to use URLSession" is not.
- Pin dependency versions. Don't use "up to next major" ranges unless you have tests to catch breakage.

## Git & Commits

- Use Conventional Commits: `feat:`, `fix:`, `docs:`, `refactor:`, `chore:`
- Present tense: "add search command" not "added search command"
- One logical change per commit. Don't mix a feature and a refactor in one commit.
- Never commit secrets, API keys, or credentials. Use `.gitignore` aggressively.
- Commit working code. It's OK for features to be incomplete but the project should build after every commit.
- Run through [precommit-check.md](precommit-check.md) before every commit.
- **KPI line in commit messages:** Every commit that touches code must include a one-liner KPI summary: `KPI: wall-clock ±0%, memory ±0%, 60/60 pass, coverage 96.2%`. For non-code commits (docs, plans, config only), use `KPI: skip (docs only)`. See `docs/kpis.md` for full details.

## Swift-Specific

- Use `Codable` for JSON parsing. Define structs that match the API shape. Don't use `[String: Any]` dictionaries.
- Prefer value types (`struct`) over reference types (`class`) unless you need identity or inheritance.
- Use `async/await` for network calls, not completion handlers.
- Use `ArgumentParser` for CLI argument handling (it's Apple's own library for this).
- Every `@Argument`, `@Option`, and `@Flag` must have a `help:` string. Under 10 words. Describe what it is, not how it works.
- String interpolation over concatenation: `"Found \(count) results"` not `"Found " + String(count) + " results"`.
- **Swift 6 strict concurrency is enforced.** See [swiftconcurrency.md](swiftconcurrency.md) for the full guide. The short version: use structs, use `let`, use `async/await`, use actors only for shared mutable state, never silence concurrency warnings with escape hatches.

## What NOT to Do

- Don't over-engineer. No protocols with one conforming type. No generics that aren't generic over anything real. No abstractions for things that happen once.
- Don't add features nobody asked for. Solve the immediate problem, ship it, iterate.
- Don't copy code between files. If two features need the same logic, extract it to shared.
- Don't suppress errors silently. If you catch an error, at minimum log it.
- Don't use `print()` for user output in the final tool — use a proper output mechanism that can be tested and formatted. `print()` is fine during development.
