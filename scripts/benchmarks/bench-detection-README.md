# Language Detection Benchmarks

Micro-benchmarks for the four string operations used in `LanguageDetector`'s four-stage cascade. Each script tests multiple implementation approaches (Foundation, Swift String, UTF8View, raw pointers) to find the fastest option that doesn't sacrifice correctness or readability.

These benchmarks informed our implementation choices — run them to reproduce or to re-evaluate if Swift's performance characteristics change in future versions.

## Why

Language detection runs once per `dog` invocation, so the total cost is ~200 nanoseconds — invisible. But we benchmark anyway because:

1. We want to know the *relative* cost of Foundation vs pure Swift vs byte-level operations
2. We don't want accidental O(n) surprises hiding in "simple" string operations
3. These patterns (UTF8View scanning, precomputed byte arrays) apply elsewhere in the codebase

## Scripts

### `bench-filename.swift` — Filename from path (Stage 2)

Extracts the last path component from a file path (e.g. `/usr/local/bin/Makefile` → `Makefile`).

**Approaches tested:**
1. NSString `lastPathComponent`
2. Swift `lastIndex(of: "/")` + Substring
3. UTF8View backward scan for `0x2F`
4. Raw `withCString` pointer backward scan

**Winner: UTF8View** (35 ns/op, 28.5M ops/sec)

| Approach | ns/op | ops/sec | vs fastest |
|----------|------:|--------:|:----------:|
| Raw UInt8 pointer | 27.6 | 36.3M | 1.0x |
| **UTF8View** | **35.1** | **28.5M** | **1.3x** |
| NSString | 117.7 | 8.5M | 4.3x |
| Swift Substring | 186.9 | 5.4M | 6.8x |

Raw pointer is 8ns faster but unsafe. UTF8View chosen for safety + readability at negligible cost.

### `bench-extension.swift` — File extension (Stage 3)

Extracts the file extension from a filename (e.g. `Button.swift` → `.swift`). Handles dotfiles (`.bashrc` → nil) and no-extension files.

**Approaches tested:**
1. NSString `pathExtension`
2. Swift `lastIndex(of: ".")`
3. UTF8View backward scan for `0x2E`
4. Raw `withCString` pointer backward scan

**Winner: UTF8View** (22 ns/op, 44.8M ops/sec)

| Approach | ns/op | ops/sec | vs fastest |
|----------|------:|--------:|:----------:|
| Raw pointer | 20.4 | 48.9M | 1.0x |
| **UTF8View** | **22.3** | **44.8M** | **1.1x** |
| Swift lastIndex | 92.7 | 10.8M | 4.5x |
| NSString | 224.5 | 4.5M | 11.0x |

### `bench-suffix-strip.swift` — Ignored suffix stripping (Stage 3 retry)

Strips backup/temp suffixes (`.bak`, `.old`, `.orig`, `~`, dpkg/rpm suffixes) before retrying extension lookup. 14 suffixes checked.

**Approaches tested:**
1. Swift `hasSuffix` loop
2. UTF8View manual suffix comparison
3. Raw pointer + `memcmp`
4. Pre-converted `[UInt8]` arrays + `memcmp` via `withContiguousStorageIfAvailable`

**Winner: Precomputed + memcmp** (42 ns/op, 23.7M ops/sec)

| Approach | ns/op | ops/sec | vs fastest |
|----------|------:|--------:|:----------:|
| **Precomputed + memcmp** | **42.2** | **23.7M** | **1.0x** |
| UTF8View manual | 55.6 | 18.0M | 1.3x |
| Swift hasSuffix | 103.4 | 9.7M | 2.5x |
| Raw pointer + memcmp | 151.4 | 6.6M | 3.6x |

Precomputed wins because the 14 suffixes are static — convert to `[UInt8]` once, then `memcmp` is unbeatable for byte comparison. Raw pointer is slowest due to double `withCString` nesting overhead.

### `bench-shebang.swift` — Shebang parsing (Stage 4)

Parses `#!` lines to extract interpreter name. Handles `/usr/bin/env` with flags (`-S`, `-u`), variable assignments (`VAR=val`), and version stripping (`python3.11` → `python3`). Tests all 55 cases including every interpreter from `LanguageMap.interpreters`.

**Approaches tested:**
1. Swift `split(separator:)` + `trimmingCharacters` + `hasPrefix`/`contains`
2. UTF8View forward scan with byte comparisons
3. Raw `withCString` pointer forward scan

**Winner: UTF8View** (94 ns/op, 10.7M ops/sec)

| Approach | ns/op | ops/sec | vs fastest |
|----------|------:|--------:|:----------:|
| **UTF8View scan** | **93.5** | **10.7M** | **1.0x** |
| Raw pointer | 242.0 | 4.1M | 2.6x |
| String split | 1311.0 | 0.8M | 14.0x |

UTF8View dominates because shebang parsing is multi-step (find path, extract binary, skip flags/vars, strip version) — each step in raw pointer mode requires `String(cString:)` allocations that add up. UTF8View works with indices into the original string, zero allocations until the final result.

## Summary

| Operation | Chosen approach | ns/op |
|-----------|----------------|------:|
| Filename from path | UTF8View backward scan | 35 |
| Extension extraction | UTF8View backward scan | 22 |
| Suffix stripping | Precomputed [UInt8] + memcmp | 42 |
| Shebang parsing | UTF8View forward scan | 94 |

**Total detection cost: ~193 ns per file.** For context, reading a file from disk is ~100,000-1,000,000 ns. Tree-sitter parsing jquery.js is ~50,000,000 ns.

## How to run

Compile with optimizations and run:

```bash
# Individual
swiftc -O -o /tmp/bench-filename tests/scripts/bench-filename.swift && /tmp/bench-filename
swiftc -O -o /tmp/bench-extension tests/scripts/bench-extension.swift && /tmp/bench-extension
swiftc -O -o /tmp/bench-suffix-strip tests/scripts/bench-suffix-strip.swift && /tmp/bench-suffix-strip
swiftc -O -o /tmp/bench-shebang tests/scripts/bench-shebang.swift && /tmp/bench-shebang

# All four
for f in bench-filename bench-extension bench-suffix-strip bench-shebang; do
  echo "--- $f ---"
  swiftc -O -o /tmp/$f tests/scripts/$f.swift && /tmp/$f
  echo
done
```

Do NOT run via `swift script.swift` (interpreted mode) — it's 10-100x slower and will take minutes. Always compile with `-O` first.

## Environment

Results above measured on Apple M4 Pro, macOS 26.4, Swift 6.2, compiled with `swiftc -O`.
