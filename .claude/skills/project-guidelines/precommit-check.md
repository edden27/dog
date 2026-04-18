# Pre-Commit Checklist

Run through this before every commit. Quick gut checks, not a formal process.

## Lint & format

- [ ] Run `swift-format lint --recursive Sources/` — fix any formatting issues
- [ ] Run `swiftlint lint --quiet` — fix any lint errors (warnings are OK to assess case by case)
- [ ] These also run automatically via the pre-commit hook, but run them yourself first so you're not surprised

## Does it build?

- [ ] `swift build` succeeds with no errors
- [ ] No warnings unless they're intentional and temporary (mark with `// TODO:`)

## Did I break anything?

- [ ] If tests exist, `swift test` passes
- [ ] If I changed a function signature, did I update all callers?
- [ ] If I renamed a file, did imports/references update?

## Code quality quick scan

- [ ] No force unwraps (`!`) outside of tests — search for `!` on changed lines
- [ ] No `print()` left from debugging — search for `print(` in changed files
- [ ] No commented-out code being committed — delete it, git has history
- [ ] No hardcoded paths, secrets, or credentials
- [ ] No `// TODO:` or `// FIXME:` that should actually be fixed before committing

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

- [ ] `git diff --staged` — scan the diff, make sure nothing unexpected is in there
- [ ] No `.DS_Store`, build artifacts, or generated files being committed
- [ ] `.gitignore` covers anything that shouldn't be tracked

## If this is a public-facing change

- [ ] README still accurate? Update if the usage changed.
- [ ] If a new command/flag was added, is it documented in the README?
- [ ] If behavior changed, is it noted in the commit message?

## The "sleep on it" rule

If the diff is over 200 lines, read through the whole thing one more time before committing. Tired eyes miss things.
