---
name: build-check
description: Build the dog CLI project. Use when compiling, building, or checking for build errors.
---

# Build dog

## Command
```bash
cd "$CLAUDE_PROJECT_DIR" && swift build 2>&1
```

## Rules
- Set bash timeout to 2 minutes (120000ms)
- If timeout, retry with 4 minutes (240000ms)

## Output
Reports build success or failure with compiler errors/warnings.
