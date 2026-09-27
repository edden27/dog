// Emit functions take flat parameters by design on the render hot path — a
// context struct would add per-call packing for no clarity gain.
// swiftlint:disable function_parameter_count

/// Bulk (non-wrapping) line emission: the fast path for lines that fit the
/// terminal, with an ASCII byte==column body and a measured non-ASCII twin.
extension PrintCommand {
  /// Fast path: emit a line that fits entirely within contentCols. Bulk slices, no wrap checks.
  /// Tabs are expanded to spaces against a content-relative column so the terminal's
  /// absolute tab stops (offset by gutter width) don't desync the trailing bg fill.
  /// Returns the final display column (tab stops expanded; scalar widths measured
  /// on non-ASCII lines) so the caller can pad the trailing background fill.
  func emitLineBulk(
    sourceBytes: [UInt8],
    lineStart: Int, lineEnd: Int, lineIsASCII: Bool, lineHasTab: Bool,
    tokens: [SyntaxToken], tokenIndex: inout Int,
    into output: inout ANSIOutput
  ) -> Int {
    var position = lineStart
    var column = 0
    var lastStyle: Style?
    // One walker per line: cluster state (ZWJ, combining marks) must survive
    // token-boundary slice splits.
    var walker = WidthWalker()

    while tokenIndex < tokens.count, tokens[tokenIndex].endByte <= lineStart {
      tokenIndex += 1
    }

    // A blank line has nothing to draw. Leave the current token alone: a
    // comment spanning the blank line must stay current for the next line.
    guard lineStart < lineEnd else {
      output.reset()
      return 0
    }

    while tokenIndex < tokens.count {
      let token = tokens[tokenIndex]
      guard token.startByte < lineEnd else { break }

      let tokenStart = max(token.startByte, position)
      let tokenEnd = min(token.endByte, lineEnd)
      guard tokenStart < tokenEnd else {
        tokenIndex += 1
        continue
      }

      if tokenStart > position {
        applyStyle(baseColor, lastStyle: &lastStyle, into: &output)
        emitSlice(
          sourceBytes: sourceBytes, from: position, to: tokenStart,
          lineIsASCII: lineIsASCII, lineHasTab: lineHasTab,
          column: &column, walker: &walker, into: &output
        )
      }

      let style = colorTable[(token.tokenType ?? .none).rawValue]
      applyStyle(style, lastStyle: &lastStyle, into: &output)
      emitSlice(
        sourceBytes: sourceBytes, from: tokenStart, to: tokenEnd,
        lineIsASCII: lineIsASCII, lineHasTab: lineHasTab,
        column: &column, walker: &walker, into: &output
      )
      position = tokenEnd

      // Once a token reaches the end of the line the line is done. A token
      // that runs on past the line stays current for the next line; one that
      // ends exactly here is skipped by the next line's leading skip loop.
      if token.endByte < lineEnd { tokenIndex += 1 } else { break }
    }

    if position < lineEnd {
      applyStyle(baseColor, lastStyle: &lastStyle, into: &output)
      emitSlice(
        sourceBytes: sourceBytes, from: position, to: lineEnd,
        lineIsASCII: lineIsASCII, lineHasTab: lineHasTab,
        column: &column, walker: &walker, into: &output
      )
    }

    output.reset()
    return column
  }

  /// Switch the terminal to `style` only when it differs from what is already
  /// on, and remember it. Always inlined: this sits inside the per-token loop.
  @inline(__always)
  private func applyStyle(_ style: Style, lastStyle: inout Style?, into output: inout ANSIOutput) {
    if style != lastStyle {
      output.colorDelta(from: lastStyle, to: style)
      lastStyle = style
    }
  }

  /// Dispatch a slice to the ASCII fast path or the measured twin. ASCII lines
  /// keep the untouched byte==column body; non-ASCII lines pay for real
  /// display-width measurement so tab stops land correctly after wide chars.
  @inline(__always)
  private func emitSlice(
    sourceBytes: [UInt8],
    from start: Int, to end: Int,
    lineIsASCII: Bool, lineHasTab: Bool,
    column: inout Int,
    walker: inout WidthWalker,
    into output: inout ANSIOutput
  ) {
    if lineIsASCII {
      emitBulkSlice(
        sourceBytes: sourceBytes, from: start, to: end,
        lineHasTab: lineHasTab, column: &column, into: &output
      )
    } else {
      emitBulkSliceMeasured(
        sourceBytes: sourceBytes, from: start, to: end,
        column: &column, walker: &walker, into: &output
      )
    }
  }

  /// Emit a byte range, expanding 0x09 tabs into spaces aligned to
  /// `tabStopWidth` columns relative to content start.
  ///
  /// Fast path: the overwhelming majority of tokens contain no tab byte.
  /// `firstIndex(of: 0x09)` compiles to a tight memchr-style loop the Swift
  /// optimizer can SIMD-vectorize; when no tab is present we skip straight
  /// to one `output.text` + column bump, avoiding the per-byte walk the
  /// tab-expansion logic needs. Only tab-bearing tokens pay for the loop.
  @inline(__always)
  private func emitBulkSlice(
    sourceBytes: [UInt8],
    from start: Int, to end: Int,
    lineHasTab: Bool,
    column: inout Int,
    into output: inout ANSIOutput
  ) {
    guard start < end else { return }
    let slice = sourceBytes[start..<end]
    // The line walk already knows whether a tab exists anywhere on the line;
    // only tab lines search each slice for it.
    guard lineHasTab, let firstTab = slice.firstIndex(of: 0x09) else {
      output.text(slice)
      column += end - start
      return
    }
    // Tab present — bulk-emit the pre-tab prefix, then walk only the rest.
    if firstTab > start {
      output.text(sourceBytes[start..<firstTab])
      column += firstTab - start
    }
    var runStart = firstTab
    var index = firstTab
    while index < end {
      if sourceBytes[index] == 0x09 {
        if index > runStart {
          output.text(sourceBytes[runStart..<index])
          column += index - runStart
        }
        let width = tabStopWidth - (column % tabStopWidth)
        for _ in 0..<width { output.byte(0x20) }
        column += width
        index += 1
        runStart = index
      } else {
        index += 1
      }
    }
    if runStart < end {
      output.text(sourceBytes[runStart..<end])
      column += end - runStart
    }
  }

  /// Measured twin of `emitBulkSlice` for lines containing non-ASCII bytes:
  /// decodes UTF-8 scalars and advances `column` by display width — via the
  /// cluster-aware `WidthWalker` — so tab stops land on the right column
  /// after wide characters, ZWJ emoji, skin tones, and combining marks.
  /// `@inline(never)` keeps this body out of the ASCII hot path.
  @inline(never)
  private func emitBulkSliceMeasured(
    sourceBytes: [UInt8],
    from start: Int, to end: Int,
    column: inout Int,
    walker: inout WidthWalker,
    into output: inout ANSIOutput
  ) {
    var index = start
    while index < end {
      let byte = sourceBytes[index]
      if byte == 0x09 {
        let width = tabStopWidth - (column % tabStopWidth)
        for _ in 0..<width { output.byte(0x20) }
        column += width
        index += 1
      } else if byte < 0x80 {
        // Bulk run of ASCII non-tab bytes: byte count == column count.
        let runStart = index
        while index < end, sourceBytes[index] < 0x80, sourceBytes[index] != 0x09 {
          index += 1
        }
        output.text(sourceBytes[runStart..<index])
        column += index - runStart
        walker.noteASCIIRun()
      } else {
        // Decode one UTF-8 scalar and advance by its display width.
        let scalarStart = index
        var value: UInt32
        var length: Int
        if byte & 0xE0 == 0xC0 {
          value = UInt32(byte & 0x1F)
          length = 2
        } else if byte & 0xF0 == 0xE0 {
          value = UInt32(byte & 0x0F)
          length = 3
        } else if byte & 0xF8 == 0xF0 {
          value = UInt32(byte & 0x07)
          length = 4
        } else {
          // Stray continuation byte (e.g. a token boundary split a scalar) —
          // emit it and count one column.
          value = 0xFFFD
          length = 1
        }
        if length > 1 {
          var offset = 1
          while offset < length, scalarStart + offset < end {
            value = (value << 6) | UInt32(sourceBytes[scalarStart + offset] & 0x3F)
            offset += 1
          }
        }
        index = min(scalarStart + length, end)
        output.text(sourceBytes[scalarStart..<index])
        column += walker.consume(value)
      }
    }
  }
}

// swiftlint:enable function_parameter_count
