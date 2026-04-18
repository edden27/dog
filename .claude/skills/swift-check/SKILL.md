---
name: swift-check
description: Run swift-format and swiftlint against the project and report results
---

# Swift Lint & Format Check

Review the output below and report findings. Do not fix anything — only report.

> **IMPORTANT:** Both commands MUST run from the repo root (where `.swiftlint.yml` lives),
> otherwise swiftlint misses the config and lints all of `.build/checkouts/`.

## swift-format output

run bash `cd "$CLAUDE_PROJECT_DIR" && swift-format lint --recursive Sources/ 2>&1`

## swiftlint output

run bash `cd "$CLAUDE_PROJECT_DIR" && swiftlint lint --quiet 2>&1`

## Instructions

Report findings in this format:

### swift-format
- If clean: "No formatting issues."
- If issues: list each file and issue

### swiftlint
- If clean: "No lint issues."
- If issues: list each file, line, and rule violated

### Summary
- Total issues found across both tools
- Pass/fail verdict: pass only if both tools report zero issues

If any issues were found, ask the user if they want you to auto-fix them. If yes:
- Run `swift-format -i -r Sources/` to fix formatting
- Run `swiftlint lint --fix` to fix lint issues
