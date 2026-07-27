import CWcwidth

#if canImport(Darwin)
  import Darwin
#elseif canImport(Glibc)
  import Glibc
#endif

// Character display-width measurement.
// Adapted from VirtualTerminal/Buffer/TextMetrics.swift (BSD-3-Clause, Saleem Abdulrasool).
//
// Three-tier fast path:
//   1. ASCII          → 1 column, no lookup
//   2. Wide range table (CJK, emoji, etc.) → 2 columns, no syscall
//   3. Everything else → locale-aware wcwidth via the CWcwidth shim
//      (0 = combining mark, -1 = control → treated as 1)

extension UnicodeScalar {
  /// Returns true for known wide Unicode ranges (occupies 2 terminal columns).
  /// Used as a fast-path check before calling wcwidth.
  var isWideCharacter: Bool {
    switch value {
    case 0x01100...0x0115f,  // Hangul Jamo
      0x02329...0x0232a,  // Angle brackets
      0x02e80...0x02eff,  // CJK Radicals
      0x03000...0x0303e,  // CJK Symbols
      0x03041...0x03096,  // Hiragana
      0x030a1...0x030fa,  // Katakana
      0x03105...0x0312d,  // Bopomofo
      0x03131...0x0318e,  // Hangul Compatibility Jamo
      0x03190...0x0319f,  // Kanbun
      0x031c0...0x031e3,  // CJK Strokes
      0x031f0...0x0321e,  // Katakana Extension
      0x03220...0x03247,  // Enclosed CJK
      0x03250...0x032fe,  // Enclosed CJK
      0x03300...0x04dbf,  // CJK Extension A
      0x04e00...0x09fff,  // CJK Unified Ideographs
      0x0a960...0x0a97c,  // Hangul Jamo Extended-A
      0x0ac00...0x0d7a3,  // Hangul Syllables
      0x0f900...0x0faff,  // CJK Compatibility
      0x0fe10...0x0fe19,  // Vertical forms
      0x0fe30...0x0fe6f,  // CJK Compatibility Forms
      0x0ff00...0x0ff60,  // Fullwidth Forms
      0x0ffe0...0x0ffe6,  // Fullwidth Forms
      0x1f300...0x1f5ff,  // Misc Symbols and Pictographs
      0x1f600...0x1f64f,  // Emoticons
      0x1f680...0x1f6ff,  // Transport and Map
      0x1f700...0x1f77f,  // Alchemical Symbols
      0x1f780...0x1f7ff,  // Geometric Shapes Extended
      0x1f800...0x1f8ff,  // Supplemental Arrows-C
      0x1f900...0x1f9ff,  // Supplemental Symbols and Pictographs
      0x20000...0x2fffd,  // CJK Extension B-F
      0x30000...0x3fffd:  // CJK Extension G
      return true
    default:
      return false
    }
  }

  /// Terminal column width of this scalar. 0 for combining marks (they share
  /// the previous character's cell); 1 for controls and everything narrow.
  var terminalWidth: Int {
    // Fast path: known wide ranges → 2, no lookup needed.
    if isWideCharacter { return 2 }
    let raw = Int(dog_wcwidth(wchar_t(value)))
    // -1 = control/invalid → dog's long-standing 1-column policy;
    // 0 = combining mark, keep it.
    return raw < 0 ? 1 : raw
  }
}

/// Single-pass display-width accumulator that handles grapheme clusters —
/// ZWJ sequences (👨‍👩‍👧), skin-tone modifiers (👍🏽), variation selectors
/// (❤️, keycaps), and combining marks (NFD é) — without Character iteration,
/// so it is safe on hot paths.
///
/// Feed scalars in document order via `consume`. Call `noteASCIIRun()` when
/// the surrounding loop bulk-emits ASCII bytes so a following variation
/// selector can still upgrade the last ASCII character (keycap sequences).
struct WidthWalker {
  private var afterJoiner = false
  private var previousWasWide = false
  private var previousWasNarrowVisible = false

  /// The surrounding loop emitted a run of ASCII: the last visible character
  /// is narrow, and any pending join state is stale.
  mutating func noteASCIIRun() {
    afterJoiner = false
    previousWasWide = false
    previousWasNarrowVisible = true
  }

  /// Column contribution of the next scalar, given cluster state so far.
  mutating func consume(_ value: UInt32) -> Int {
    if value == 0x200D {  // zero-width joiner: cluster continues
      afterJoiner = true
      return 0
    }
    if afterJoiner {  // scalar joined into the previous cluster
      afterJoiner = false
      previousWasWide = UnicodeScalar(value)?.isWideCharacter ?? false
      previousWasNarrowVisible = false
      return 0
    }
    if (0x1F3FB...0x1F3FF).contains(value) {  // skin-tone modifier
      if previousWasWide { return 0 }
      previousWasWide = true
      previousWasNarrowVisible = false
      return 2  // a lone modifier renders as a color swatch
    }
    if value == 0xFE0F {  // emoji presentation: upgrades a narrow base to 2
      if previousWasNarrowVisible {
        previousWasNarrowVisible = false
        previousWasWide = true
        return 1
      }
      return 0
    }
    if value == 0xFE0E { return 0 }  // text presentation selector
    let width = UnicodeScalar(value)?.terminalWidth ?? 1
    if width == 0 { return 0 }  // combining mark: keep cluster state
    previousWasWide = width == 2
    previousWasNarrowVisible = width == 1
    return width
  }
}

extension Character {
  /// Number of terminal columns this character occupies.
  var terminalWidth: Int {
    // ASCII fast path — covers the vast majority of source code characters.
    if isASCII {
      return (isWhitespace && self != " ") ? 0 : 1
    }
    return unicodeScalars.reduce(0) { $0 + $1.terminalWidth }
  }
}

extension String {
  /// Total terminal column width of this string, grapheme-cluster aware.
  var terminalWidth: Int {
    // Byte-count fast path: if every byte is ASCII (high bit clear), width == count.
    let allASCII = utf8.allSatisfy { $0 < 0x80 }
    if allASCII { return utf8.count }
    var walker = WidthWalker()
    var total = 0
    var previousWasASCII = false
    for scalar in unicodeScalars {
      if scalar.value < 0x80 {
        total += 1
        previousWasASCII = true
        continue
      }
      if previousWasASCII {
        walker.noteASCIIRun()
        previousWasASCII = false
      }
      total += walker.consume(scalar.value)
    }
    return total
  }
}
