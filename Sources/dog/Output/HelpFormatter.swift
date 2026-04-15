/// Semantic roles inside a `--help` message. Each role maps to a `Style`
/// via the active theme (see `UtilityDarkTheme.helpStyle(for:)`), so
/// recoloring help is a one-line change in the theme.
enum HelpRole {
  case heading
  case command
  case flag
  case metavar
  case defaultValue
  case punctuation
  case discussion
  case dim
  /// Primary item in a list (e.g. theme bundle name, language name).
  case listPrimary
  /// Secondary item in a list (e.g. theme variant).
  case listSecondary
}

/// Colorizes ArgumentParser's plain `helpMessage()` output.
///
/// Hand-rolled byte scanner — no Foundation, no regex engine. Runs once per
/// `--help` invocation, then the process exits.
enum HelpFormatter {
  static func colorize(_ plain: String) -> [UInt8] {
    let spaced = spaceEntries(Array(plain.utf8))
    let spans = scan(spaced)
    return render(src: spaced, spans: spans)
  }

  /// Insert a blank line before every entry inside ARGUMENTS/OPTIONS/FLAGS
  /// except the first one in each section. An entry is a line where the
  /// first non-space content starts with `-` (flag) or `<` (metavar).
  private static func spaceEntries(_ src: [UInt8]) -> [UInt8] {
    var out: [UInt8] = []
    out.reserveCapacity(src.count + 64)
    var index = 0
    var inEntrySection = false
    var firstEntrySeen = false

    while index < src.count {
      let lineStart = index
      while index < src.count, src[index] != 0x0A { index += 1 }
      let lineEnd = index  // exclusive; points at newline or EOF
      let hasNewline = index < src.count
      if hasNewline { index += 1 }

      // Heading line toggles section state.
      if isHeadingLine(src, start: lineStart, end: lineEnd) {
        let text = src[lineStart..<lineEnd]
        inEntrySection = isEntryHeading(text)
        firstEntrySeen = false
        out.append(contentsOf: text)
        if hasNewline { out.append(0x0A) }
        continue
      }

      if inEntrySection, isEntryStartLine(src, start: lineStart, end: lineEnd) {
        if firstEntrySeen {
          out.append(0x0A)
        }
        firstEntrySeen = true
      }

      out.append(contentsOf: src[lineStart..<lineEnd])
      if hasNewline { out.append(0x0A) }
    }
    return out
  }

  /// `USAGE:`-style line: uppercase + spaces + trailing colon at SOL.
  private static func isHeadingLine(_ src: [UInt8], start: Int, end: Int) -> Bool {
    guard start < end, isUpper(src[start]) else { return false }
    return scanHeading(src, from: start).map { $0 == end } ?? false
  }

  private static func isEntryHeading(_ text: ArraySlice<UInt8>) -> Bool {
    let arguments: [UInt8] = [0x41, 0x52, 0x47, 0x55, 0x4D, 0x45, 0x4E, 0x54, 0x53, 0x3A]
    let options: [UInt8] = [0x4F, 0x50, 0x54, 0x49, 0x4F, 0x4E, 0x53, 0x3A]
    let flags: [UInt8] = [0x46, 0x4C, 0x41, 0x47, 0x53, 0x3A]
    return slicesEqual(text, arguments) || slicesEqual(text, options) || slicesEqual(text, flags)
  }

  private static func slicesEqual(_ lhs: ArraySlice<UInt8>, _ rhs: [UInt8]) -> Bool {
    guard lhs.count == rhs.count else { return false }
    for (offset, byte) in rhs.enumerated() where lhs[lhs.startIndex + offset] != byte {
      return false
    }
    return true
  }

  /// True if line is the start of a new entry (indented, then `-` or `<`).
  /// ArgumentParser indents entries with exactly 2 spaces; continuation
  /// lines use more.
  private static func isEntryStartLine(_ src: [UInt8], start: Int, end: Int) -> Bool {
    guard end - start >= 3 else { return false }
    guard src[start] == 0x20, src[start + 1] == 0x20 else { return false }
    let third = src[start + 2]
    if third == 0x20 { return false }
    return third == 0x2D || third == 0x3C
  }

  // MARK: - Scanning

  private struct Span {
    let start: Int
    let end: Int  // exclusive
    let role: HelpRole
  }

  private static func scan(_ src: [UInt8]) -> [Span] {
    var spans: [Span] = []
    var index = 0
    var atLineStart = true
    let count = src.count

    while index < count {
      let byte = src[index]

      // Heading: SOL, run of [A-Z ] ending in ':'.
      if atLineStart, isUpper(byte) {
        if let end = scanHeading(src, from: index) {
          spans.append(Span(start: index, end: end, role: .heading))
          index = end
          atLineStart = false
          continue
        }
      }

      // Flag: '-' not preceded by word char. Accept "-x, --word", "--word", "-x".
      if byte == 0x2D, !isWordPrev(src, at: index) {
        if let end = scanFlag(src, from: index) {
          spans.append(Span(start: index, end: end, role: .flag))
          index = end
          atLineStart = false
          continue
        }
      }

      // Metavar: '<' ... '>' on same line.
      if byte == 0x3C {
        if let end = scanMetavar(src, from: index) {
          spans.append(Span(start: index, end: end, role: .metavar))
          index = end
          atLineStart = false
          continue
        }
      }

      // Default annotation: '(default:' or '(values:' ... ')'.
      if byte == 0x28 {
        if let end = scanDefault(src, from: index) {
          spans.append(Span(start: index, end: end, role: .defaultValue))
          index = end
          atLineStart = false
          continue
        }
      }

      atLineStart = (byte == 0x0A)
      index += 1
    }

    return spans
  }

  /// Scan a heading starting at `start`. Requires at least one upper-case
  /// letter, only `[A-Z ]` allowed, and must end with ':'.
  private static func scanHeading(_ src: [UInt8], from start: Int) -> Int? {
    var cursor = start
    var sawUpper = false
    while cursor < src.count {
      let byte = src[cursor]
      if isUpper(byte) {
        sawUpper = true
        cursor += 1
      } else if byte == 0x20 {
        cursor += 1
      } else if byte == 0x3A, sawUpper {
        return cursor + 1
      } else {
        return nil
      }
    }
    return nil
  }

  /// Scan a flag. Handles `-x, --word`, `--word`, `-x`.
  private static func scanFlag(_ src: [UInt8], from start: Int) -> Int? {
    let count = src.count
    var cursor = start
    // Leading short flag "-x"
    if cursor + 1 < count, src[cursor] == 0x2D, isAlpha(src[cursor + 1]) {
      // Could be short-only or "-x, --word". Try ", --" after short.
      let afterShort = cursor + 2
      if afterShort + 3 < count,
        src[afterShort] == 0x2C, src[afterShort + 1] == 0x20,
        src[afterShort + 2] == 0x2D, src[afterShort + 3] == 0x2D,
        afterShort + 4 < count, isAlpha(src[afterShort + 4])
      {
        // Consume "-x, --word..."
        cursor = afterShort + 4
        while cursor < count, isFlagBody(src[cursor]) { cursor += 1 }
        return cursor
      }
      // Short-only: make sure next char isn't a word character.
      if afterShort == count || !isAlnum(src[afterShort]) {
        return afterShort
      }
      return nil
    }
    // "--word"
    if cursor + 2 < count, src[cursor] == 0x2D, src[cursor + 1] == 0x2D, isAlpha(src[cursor + 2]) {
      cursor += 2
      while cursor < count, isFlagBody(src[cursor]) { cursor += 1 }
      return cursor
    }
    return nil
  }

  /// Scan `<...>` on a single line.
  private static func scanMetavar(_ src: [UInt8], from start: Int) -> Int? {
    var cursor = start + 1
    while cursor < src.count {
      let byte = src[cursor]
      if byte == 0x0A { return nil }
      if byte == 0x3E { return cursor + 1 }
      cursor += 1
    }
    return nil
  }

  /// Scan `(default:...)` or `(values:...)`.
  private static func scanDefault(_ src: [UInt8], from start: Int) -> Int? {
    let count = src.count
    let defaultTag: [UInt8] = [0x64, 0x65, 0x66, 0x61, 0x75, 0x6C, 0x74, 0x3A]  // "default:"
    let valuesTag: [UInt8] = [0x76, 0x61, 0x6C, 0x75, 0x65, 0x73, 0x3A]  // "values:"
    let after = start + 1
    let matches =
      matchesTag(src, at: after, tag: defaultTag)
      || matchesTag(src, at: after, tag: valuesTag)
    guard matches else { return nil }
    var cursor = after
    while cursor < count {
      let byte = src[cursor]
      if byte == 0x0A { return nil }
      if byte == 0x29 { return cursor + 1 }
      cursor += 1
    }
    return nil
  }

  private static func matchesTag(_ src: [UInt8], at offset: Int, tag: [UInt8]) -> Bool {
    guard offset + tag.count <= src.count else { return false }
    for (index, expected) in tag.enumerated() where src[offset + index] != expected {
      return false
    }
    return true
  }

  // MARK: - Byte class helpers

  private static func isUpper(_ byte: UInt8) -> Bool { byte >= 0x41 && byte <= 0x5A }
  private static func isLower(_ byte: UInt8) -> Bool { byte >= 0x61 && byte <= 0x7A }
  private static func isDigit(_ byte: UInt8) -> Bool { byte >= 0x30 && byte <= 0x39 }
  private static func isAlpha(_ byte: UInt8) -> Bool { isUpper(byte) || isLower(byte) }
  private static func isAlnum(_ byte: UInt8) -> Bool { isAlpha(byte) || isDigit(byte) }
  private static func isFlagBody(_ byte: UInt8) -> Bool { isAlnum(byte) || byte == 0x2D }

  /// True if the byte at `index - 1` is a word character (alnum or `_`).
  private static func isWordPrev(_ src: [UInt8], at index: Int) -> Bool {
    guard index > 0 else { return false }
    let prev = src[index - 1]
    return isAlnum(prev) || prev == 0x5F
  }

  // MARK: - Rendering

  private static func render(src: [UInt8], spans: [Span]) -> [UInt8] {
    var output = ANSIOutput(enabled: true, estimatedSize: src.count + spans.count * 32)
    var cursor = 0
    for span in spans {
      if cursor < span.start {
        output.text(src[cursor..<span.start])
      }
      output.color(UtilityDarkTheme.helpStyle(for: span.role))
      output.text(src[span.start..<span.end])
      output.reset()
      cursor = span.end
    }
    if cursor < src.count {
      output.text(src[cursor..<src.count])
    }
    return Array(output.buffer)
  }
}
