/// Gutter construction and emission: pre-built line-number byte tables and
/// wrap-continuation prefixes, plus their plain-mode (numberless) twins.
extension PrintCommand {
  /// Pre-built gutter bytes: reset + padding + color + digits + reset + separator.
  /// Built once per render, indexed by line number. Avoids per-line String allocation.
  static func buildGutterTable(
    lineCount: Int, digitWidth: Int,
    lineNumberStyle: Style, gutterBgStyle: Style?,
    editorBg: ContiguousArray<UInt8>
  ) -> ContiguousArray<ContiguousArray<UInt8>> {
    var table = ContiguousArray<ContiguousArray<UInt8>>()
    table.reserveCapacity(lineCount)

    // Pre-build the background escape sequence once
    var bgBytes = ContiguousArray<UInt8>()
    if let gutterBg = gutterBgStyle {
      bgBytes.append(contentsOf: [0x1B, 0x5B, 0x34, 0x38, 0x3B, 0x32, 0x3B])
      ANSICodes.appendDecimal(gutterBg.red, into: &bgBytes)
      bgBytes.append(0x3B)
      ANSICodes.appendDecimal(gutterBg.green, into: &bgBytes)
      bgBytes.append(0x3B)
      ANSICodes.appendDecimal(gutterBg.blue, into: &bgBytes)
      bgBytes.append(0x6D)
    }

    // Pre-build the line number fg escape (just the foreground, no reset)
    var fgBytes = ContiguousArray<UInt8>()
    fgBytes.append(contentsOf: [0x1B, 0x5B, 0x33, 0x38, 0x3B, 0x32, 0x3B])
    ANSICodes.appendDecimal(lineNumberStyle.red, into: &fgBytes)
    fgBytes.append(0x3B)
    ANSICodes.appendDecimal(lineNumberStyle.green, into: &fgBytes)
    fgBytes.append(0x3B)
    ANSICodes.appendDecimal(lineNumberStyle.blue, into: &fgBytes)
    fgBytes.append(0x6D)

    for lineNum in 1...lineCount {
      var buf = ContiguousArray<UInt8>()
      buf.reserveCapacity(digitWidth + 40)

      // Reset, then set bg for entire gutter region
      buf.append(contentsOf: ANSICodes.reset)
      buf.append(contentsOf: bgBytes)

      // Right-align padding (bg stays active through spaces)
      var numDigits = 1
      var tempNum = lineNum
      while tempNum >= 10 {
        numDigits += 1
        tempNum /= 10
      }
      for _ in 0..<(digitWidth - numDigits) { buf.append(0x20) }

      // Set fg for digits (bg still active)
      buf.append(contentsOf: fgBytes)
      ANSICodes.appendDecimal(lineNum, digitWidth: numDigits, into: &buf)

      // " │" with gutter bg, then reset + editor bg for trailing space
      buf.append(contentsOf: [0x20, 0xE2, 0x94, 0x82])
      buf.append(contentsOf: ANSICodes.reset)
      buf.append(contentsOf: editorBg)
      buf.append(0x20)

      table.append(buf)
    }
    return table
  }

  func emitGutter(
    lineNumber: Int, gutterTable: ContiguousArray<ContiguousArray<UInt8>>,
    into output: inout ANSIOutput
  ) {
    guard colorEnabled else { return }
    output.text(gutterTable[lineNumber - 1])
  }

  /// Emit gutter padding for wrapped continuation lines, then re-emit the active style.
  /// Pre-built wrap continuation gutter: newline + reset + bg + spaces + fg + " │" + reset + space.
  static func buildWrapGutter(
    digitWidth: Int,
    lineNumberStyle: Style,
    gutterBgStyle: Style?,
    editorBg: ContiguousArray<UInt8>
  ) -> ContiguousArray<UInt8> {
    var buf = ContiguousArray<UInt8>()
    buf.reserveCapacity(digitWidth + 40)

    // Reset MUST come before the newline, otherwise the terminal fills
    // from the cursor to the right edge with the still-active bg color.
    buf.append(contentsOf: ANSICodes.reset)
    buf.append(0x0A)
    if let gutterBg = gutterBgStyle {
      buf.append(contentsOf: [0x1B, 0x5B, 0x34, 0x38, 0x3B, 0x32, 0x3B])
      ANSICodes.appendDecimal(gutterBg.red, into: &buf)
      buf.append(0x3B)
      ANSICodes.appendDecimal(gutterBg.green, into: &buf)
      buf.append(0x3B)
      ANSICodes.appendDecimal(gutterBg.blue, into: &buf)
      buf.append(0x6D)
    }
    // Blank padding where number would be
    for _ in 0..<digitWidth { buf.append(0x20) }
    // Line number fg for │
    buf.append(contentsOf: [0x1B, 0x5B, 0x33, 0x38, 0x3B, 0x32, 0x3B])
    ANSICodes.appendDecimal(lineNumberStyle.red, into: &buf)
    buf.append(0x3B)
    ANSICodes.appendDecimal(lineNumberStyle.green, into: &buf)
    buf.append(0x3B)
    ANSICodes.appendDecimal(lineNumberStyle.blue, into: &buf)
    buf.append(0x6D)
    // " │" + reset + editor bg for trailing space
    buf.append(contentsOf: [0x20, 0xE2, 0x94, 0x82])
    buf.append(contentsOf: ANSICodes.reset)
    buf.append(contentsOf: editorBg)
    buf.append(0x20)

    return buf
  }

  /// Plain-mode gutter entries: just reset + editor bg, repeated per line.
  /// Lets `emitGutter` prime the bg before each line without printing a number.
  static func buildPlainGutterTable(
    lineCount: Int, editorBg: ContiguousArray<UInt8>
  ) -> ContiguousArray<ContiguousArray<UInt8>> {
    var entry = ContiguousArray<UInt8>()
    entry.append(contentsOf: ANSICodes.reset)
    entry.append(contentsOf: editorBg)
    var table = ContiguousArray<ContiguousArray<UInt8>>()
    table.reserveCapacity(lineCount)
    for _ in 0..<lineCount { table.append(entry) }
    return table
  }

  /// Plain-mode wrap continuation: reset + newline + editor bg.
  /// Reset MUST come before the newline, otherwise the terminal fills
  /// from the cursor to the right edge with the still-active bg color.
  static func buildPlainWrapGutter(
    editorBg: ContiguousArray<UInt8>
  ) -> ContiguousArray<UInt8> {
    var buf = ContiguousArray<UInt8>()
    buf.append(contentsOf: ANSICodes.reset)
    buf.append(0x0A)
    buf.append(contentsOf: editorBg)
    return buf
  }
}
