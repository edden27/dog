---
name: precommit-check
description: Run pre-commit checks before committing — lint, format, build, and code review of staged changes
context: fork
disable-model-invocation: true
---

# Pre-Commit Checklist

Run through this before every commit. Quick gut checks, not a formal process.

> **IMPORTANT:** All commands in this checklist MUST run from the repo root
> (`$CLAUDE_PROJECT_DIR`).
> Running swiftlint from a subdir misses the `.swiftlint.yml` config and lints all of `.build/checkouts/`.

## Reference Documents

Review staged changes against these guidelines:

- [swift-coding-guidelines.md](swift-coding-guidelines.md) — Apple's Swift API Design Guidelines
- [swiftconcurrency.md](swiftconcurrency.md) — Swift 6 strict concurrency rules

## Lint & format

You MUST use the Skill tool to invoke `swift-check`. Do NOT run swift-format or swiftlint yourself.

## Does it build?

You MUST use the Skill tool to invoke `build-check`. Do NOT run swift build yourself.

## Staged changes

Files changed:

run bash `cd "$CLAUDE_PROJECT_DIR" && git diff --cached --name-only`

Diff:

run bash `cd "$CLAUDE_PROJECT_DIR" && git diff --cached`

## Did I break anything?

- [ ] If tests exist, `swift test` passes (no tests exist)
- [ ] If I changed a function signature, did I update all callers?
- [ ] If I renamed a file, did imports/references update?

## Code quality quick scan

Focus only on the staged diff above — do not review the entire codebase.

- [ ] No force unwraps (`!`) outside of tests
- [ ] No `print()` left from debugging
- [ ] No commented-out code being committed — delete it, git has history
- [ ] No hardcoded paths, secrets, or credentials
- [ ] No `// TODO:` or `// FIXME:` that should actually be fixed before committing

## Swift guidelines check

Review the staged diff against [swift-coding-guidelines.md](swift-coding-guidelines.md) and [swiftconcurrency.md](swiftconcurrency.md). Focus on the changed code only. Check for:

- [ ] Naming follows Swift API Design Guidelines (clarity, caller's perspective, omit needless words)
- [ ] Types are Sendable where they cross concurrency boundaries (prefer structs with let properties)
- [ ] async/await used for IO, no completion handlers
- [ ] No `@unchecked Sendable`, `nonisolated(unsafe)`, or `@MainActor` workarounds
- [ ] Actors only used for genuinely shared mutable state

## Naming check

- [ ] New functions/variables have clear descriptive names
- [ ] Booleans read as yes/no questions (`isLoaded`, `hasResults`)
- [ ] Types are PascalCase, everything else is camelCase

## Commit message

- [ ] Starts with a type prefix: `feat:`, `fix:`, `docs:`, `refactor:`, `chore:`
- [ ] Present tense: "add feature" not "added feature"
- [ ] Describes the WHAT in one short line
- [ ] One logical change — if you want to say "and" in the message, it might be two commits

## Files check

- [ ] No `.DS_Store`, build artifacts, or generated files being committed
- [ ] `.gitignore` covers anything that shouldn't be tracked

## If this is a public-facing change

- [ ] README still accurate? Update if the usage changed.
- [ ] If a new command/flag was added, is it documented in the README?
- [ ] If behavior changed, is it noted in the commit message?

## The "sleep on it" rule

If the diff is over 200 lines, read through the whole thing one more time before committing. Tired eyes miss things.

## Response format

If everything passes, just respond: "All good."

Only give full details on things that failed or need attention. Do not list passing checks.
