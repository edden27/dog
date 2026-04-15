#if canImport(Darwin)
  import Darwin
#elseif canImport(Glibc)
  import Glibc
#endif
#if canImport(CWcwidth)
  import CWcwidth
#endif

// Character display-width measurement.
// Adapted from VirtualTerminal/Buffer/TextMetrics.swift (BSD-3-Clause, Saleem Abdulrasool).
//
// Three-tier fast path:
//   1. ASCII          → 1 column, no lookup
//   2. Wide range table (CJK, emoji, etc.) → 2 columns, no syscall
//   3. Everything else → wcwidth() fallback (rarely hit for source code)

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

  /// Terminal column width of this scalar. Always >= 1 for printable characters.
  var terminalWidth: Int {
    // Fast path: known wide ranges → 2, no syscall needed.
    if isWideCharacter { return 2 }
    // Fallback for combining marks and obscure scripts.
    // Almost never reached for real source code.
    #if canImport(Darwin)
      return max(1, Int(wcwidth(Int32(value))))
    #elseif canImport(CWcwidth)
      return max(1, Int(dog_wcwidth(wchar_t(value))))
    #else
      return isWideCharacter ? 2 : 1
    #endif
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
  /// Total terminal column width of this string.
  var terminalWidth: Int {
    // Byte-count fast path: if every byte is ASCII (high bit clear), width == count.
    let allASCII = utf8.allSatisfy { $0 < 0x80 }
    if allASCII { return utf8.count }
    return unicodeScalars.reduce(0) { $0 + $1.terminalWidth }
  }
}
