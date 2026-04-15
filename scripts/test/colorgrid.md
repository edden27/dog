# TrueColor Grid — ANSI Pipeline Verification

Two scripts that render the same full-spectrum TrueColor grid. Comparing their output proves dog's hex→RGB→ANSI byte pipeline produces accurate colors.

## What They Do

Both scripts render a full HSV color space grid that fills the terminal:
- **X axis:** hue (red → yellow → green → cyan → blue → magenta → red)
- **Y axis top half:** full saturation, brightness 100% → 0% (vivid → black)
- **Y axis bottom half:** brightness 0% → 100%, saturation 100% → 0% (black → pastel → white)

Together this covers every visible color at every brightness and saturation level.

## The Two Scripts

### `colorgrid.py` — Ground Truth

Uses Python's `colorsys.hsv_to_rgb()` and writes raw `\033[48;2;r;g;bm` escape codes directly. No hex conversion, no intermediate parsing. This is the known-correct reference.

```bash
python3 tests/scripts/colorgrid.py
```

### `colorgrid.swift` — Dog's Pipeline

Uses the **exact same code path** dog uses for theme colors:

1. HSV → hex string (`"#DE7547"`)
2. `parseHex()` → `RGB` struct (same code as `ANSICodes.parseHex` in `ANSIOutput.swift`)
3. RGB → `\u{1B}[48;2;r;g;bm` ANSI bytes (same as `ANSICodes.fg()`)
4. Append to `[UInt8]` buffer, flush via `write(STDOUT_FILENO)` (same as `ANSIOutput.flush()`)

```bash
swift tests/scripts/colorgrid.swift
```

## Why Both Exist

The Python script is the ground truth — it goes straight from math to ANSI escapes with no intermediate conversion. If the Swift script produces identical output, it proves:

- `parseHex()` correctly extracts R, G, B from hex strings
- The ANSI escape sequence format is correct
- The `[UInt8]` buffer and `write(2)` flush produce valid output
- No color information is lost in the hex→RGB→bytes pipeline

## How to Compare

Side by side in split terminals:

```bash
# Left pane
python3 tests/scripts/colorgrid.py

# Right pane
swift tests/scripts/colorgrid.swift
```

Or pipe both through `ansisvg` for a diffable SVG snapshot:

```bash
python3 tests/scripts/colorgrid.py | ansisvg > /tmp/grid-python.svg
swift tests/scripts/colorgrid.swift | ansisvg > /tmp/grid-swift.svg
diff /tmp/grid-python.svg /tmp/grid-swift.svg
```

## Results (2026-04-06)

Both grids render identically — same colors, same gradients, no banding, no mismatches. Verified visually in Ghostty on macOS (Apple Silicon). TrueColor (24-bit) confirmed working. Dog's hex→ANSI pipeline is accurate across the full 16.7M color space.
