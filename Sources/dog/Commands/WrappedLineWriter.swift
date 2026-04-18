/// Emits a single logical source line to an `ANSIOutput`, honoring soft/hard
/// wrapping, tab expansion, editor-background fill, and wrap-indent alignment.
///
/// The writer is a value type built per line and then consumed by `emitLine`.
/// Keeping wrap state in one place (instead of threading 7+ params through
/// every helper) lets each method stay small and keeps `PrintCommand` focused
/// on the render pipeline rather than byte-level layout.
struct WrappedLineWriter {
  /// Display columns available for content (excludes gutter/line-number area).
  let contentCols: Int
  /// Pre-built ANSI bytes that emit the wrap-gutter prefix for continuation rows.
  let wrapGutterBytes: ContiguousArray<UInt8>
  /// Reusable space buffer sized to `contentCols`; empty in plain mode.
  let spacePad: ContiguousArray<UInt8>
  /// Pre-built editor-background escape; empty when bg is disabled.
  let editorBg: ContiguousArray<UInt8>
  /// Display columns of leading whitespace on the line — continuation rows
  /// indent to this column so wrapped text aligns under the first non-space
  /// character of the original line.
  let wrapIndent: Int
  /// When false, ANSI escapes are suppressed (plain pipe-friendly output).
  let colorEnabled: Bool

  /// Style table indexed by `TokenType.rawValue`. Sourced from the theme.
  let colorTable: [Style]
  /// Fallback style used for source bytes not covered by any token.
  let baseColor: Style

  /// Emit the given logical line, wrapping as needed. Returns the column
  /// position of the cursor after the last byte emitted (for subsequent
  /// right-edge bg fill by the caller).
  @discardableResult
  func emitLine(
    sourceBytes: [UInt8],
    lineStart: Int, lineEnd: Int,
    tokens: [SyntaxToken], tokenIndex: inout Int,
    into output: inout ANSIOutput
  ) -> Int {
    var pos = lineStart
    var column = 0
    var lastStyle: Style?

    while tokenIndex < tokens.count, tokens[tokenIndex].endByte <= lineStart {
      tokenIndex += 1
    }
    while tokenIndex < tokens.count {
      let token = tokens[tokenIndex]
      guard token.startByte < lineEnd else { break }
      let tokenStart = max(token.startByte, pos)
      let tokenEnd = min(token.endByte, lineEnd)
      guard tokenStart < tokenEnd else {
        tokenIndex += 1
        continue
      }
      if tokenStart > pos {
        applyStyleIfNeeded(baseColor, lastStyle: &lastStyle, into: &output)
        emitSlice(
          sourceBytes: sourceBytes, from: pos, to: tokenStart,
          column: &column, currentStyle: lastStyle, into: &output)
      }
      let style = colorTable[(token.tokenType ?? .none).rawValue]
      applyStyleIfNeeded(style, lastStyle: &lastStyle, into: &output)
      emitSlice(
        sourceBytes: sourceBytes, from: tokenStart, to: tokenEnd,
        column: &column, currentStyle: lastStyle, into: &output)
      pos = tokenEnd
      if token.endByte <= lineEnd { tokenIndex += 1 } else { break }
    }
    if pos < lineEnd {
      applyStyleIfNeeded(baseColor, lastStyle: &lastStyle, into: &output)
      emitSlice(
        sourceBytes: sourceBytes, from: pos, to: lineEnd,
        column: &column, currentStyle: lastStyle, into: &output)
    }
    output.reset()
    return column
  }

  /// Apply `style` to `output` only when it differs from the last-applied
  /// style on this line. Keeps `lastStyle` in sync with terminal state.
  private func applyStyleIfNeeded(
    _ style: Style, lastStyle: inout Style?, into output: inout ANSIOutput
  ) {
    guard lastStyle != style else { return }
    output.color(style)
    lastStyle = style
  }

  /// Emit a byte range with wrap handling. Tracks column and wraps at
  /// `contentCols`. Word-aware: soft-wraps at word boundaries when the next
  /// word would overflow but fits on a fresh indented row.
  private func emitSlice(
    sourceBytes: [UInt8], from start: Int, to end: Int,
    column: inout Int, currentStyle: Style?,
    into output: inout ANSIOutput
  ) {
    var index = start
    while index < end {
      let byte = sourceBytes[index]
      if byte < 0x80 {
        index = emitASCIIByte(
          sourceBytes: sourceBytes, index: index, end: end, byte: byte,
          column: &column, currentStyle: currentStyle, into: &output)
      } else {
        index = emitMultibyteChar(
          sourceBytes: sourceBytes, index: index, end: end,
          column: &column, currentStyle: currentStyle, into: &output)
      }
    }
  }

  /// Emit one ASCII byte with wrap + tab handling. Returns next source index.
  private func emitASCIIByte(
    sourceBytes: [UInt8], index: Int, end: Int, byte: UInt8,
    column: inout Int, currentStyle: Style?,
    into output: inout ANSIOutput
  ) -> Int {
    if column >= contentCols {
      column = performWrap(column: column, currentStyle: currentStyle, into: &output)
      if byte == 0x20 { return index + 1 }
    }
    if byte != 0x20, byte != 0x09,
      atWordBoundary(sourceBytes: sourceBytes, index: index),
      shouldSoftWrap(sourceBytes: sourceBytes, wordStart: index, end: end, column: column)
    {
      column = performWrap(column: column, currentStyle: currentStyle, into: &output)
    }
    if byte == 0x09 {
      emitTabExpansion(column: column, into: &output)
      let advance = tabStopWidth - (column % tabStopWidth)
      column = min(column + advance, contentCols)
    } else {
      output.byte(byte)
      column += 1
    }
    return index + 1
  }

  /// Decode and emit a multi-byte UTF-8 character, wrapping if needed.
  private func emitMultibyteChar(
    sourceBytes: [UInt8], index: Int, end: Int,
    column: inout Int, currentStyle: Style?,
    into output: inout ANSIOutput
  ) -> Int {
    let charStart = index
    var cursor = index + 1
    while cursor < end, sourceBytes[cursor] & 0xC0 == 0x80 { cursor += 1 }
    let charString = String(decoding: sourceBytes[charStart..<cursor], as: UTF8.self)
    let charWidth = charString.unicodeScalars.reduce(0) { $0 + $1.terminalWidth }
    if column + charWidth > contentCols {
      column = performWrap(column: column, currentStyle: currentStyle, into: &output)
    }
    output.text(sourceBytes[charStart..<cursor])
    column += charWidth
    return cursor
  }

  /// Fill remainder of current row with editor bg, emit wrap gutter + indent,
  /// and return the column position at the start of the new row.
  private func performWrap(
    column: Int, currentStyle: Style?, into output: inout ANSIOutput
  ) -> Int {
    let gap = contentCols - column
    if gap > 0, !spacePad.isEmpty {
      output.text(editorBg)
      output.text(spacePad[spacePad.startIndex..<spacePad.startIndex + gap])
      output.reset()
    }
    emitWrapGutter(currentStyle: currentStyle, into: &output)
    emitWrapIndent(into: &output)
    return wrapIndent
  }

  /// Emit the wrap-gutter prefix for a continuation row and re-apply the
  /// active style. In plain mode, emits a bare newline instead of ANSI.
  private func emitWrapGutter(
    currentStyle: Style?, into output: inout ANSIOutput
  ) {
    if colorEnabled {
      output.text(wrapGutterBytes)
      if let style = currentStyle { output.color(style) }
    } else {
      output.newline()
    }
  }

  /// Emit `wrapIndent` editor-bg spaces so continuation rows align under the
  /// first non-whitespace character of the wrapped line.
  private func emitWrapIndent(into output: inout ANSIOutput) {
    guard wrapIndent > 0 else { return }
    if colorEnabled, !spacePad.isEmpty {
      output.text(spacePad[spacePad.startIndex..<spacePad.startIndex + wrapIndent])
    } else {
      for _ in 0..<wrapIndent { output.byte(0x20) }
    }
  }

  /// Expand a tab to spaces, clamped to the remaining content width so the
  /// terminal doesn't advance past the right edge and leak bg into the gutter.
  private func emitTabExpansion(column: Int, into output: inout ANSIOutput) {
    let advance = tabStopWidth - (column % tabStopWidth)
    let fill = min(advance, contentCols - column)
    guard fill > 0 else { return }
    if !spacePad.isEmpty {
      output.text(spacePad[spacePad.startIndex..<spacePad.startIndex + fill])
    } else {
      for _ in 0..<fill { output.byte(0x20) }
    }
  }

  /// True when `index` sits at the start of a word (source start, or preceded
  /// by whitespace / newline).
  private func atWordBoundary(sourceBytes: [UInt8], index: Int) -> Bool {
    guard index > 0 else { return true }
    let previous = sourceBytes[index - 1]
    return previous == 0x20 || previous == 0x09 || previous == 0x0A
  }

  /// True when the word beginning at `wordStart` should trigger a soft wrap:
  /// won't fit on the current row but will fit on a fresh indented row.
  private func shouldSoftWrap(
    sourceBytes: [UInt8], wordStart: Int, end: Int, column: Int
  ) -> Bool {
    let remaining = contentCols - column
    var wordEnd = wordStart
    while wordEnd < end, sourceBytes[wordEnd] < 0x80,
      sourceBytes[wordEnd] != 0x20, sourceBytes[wordEnd] != 0x09
    {
      wordEnd += 1
    }
    let wordLength = wordEnd - wordStart
    let nextRowCapacity = contentCols - wrapIndent
    return wordLength > remaining && column > 0 && wordLength <= nextRowCapacity
  }
}
