/// Colorized rendering: per-line token emission with wrap, truncation, and
/// background fill. Layout (wrap policy, terminal geometry, pre-built gutter
/// tables) is computed once up front; the per-line loop stays lean.
extension PrintCommand {
  /// Gutter visual width: digits + " │ " (space, box-drawing, space = 3 display cols).
  private static let gutterSeparatorWidth = 3

  /// One-time-per-render layout: wrap policy, terminal geometry, and the
  /// pre-built gutter/background byte tables the per-line loop draws from.
  private struct RenderLayout {
    let wrapEnabled: Bool
    let truncateLongLines: Bool
    let contentCols: Int
    let lineCount: Int
    let editorBackground: ContiguousArray<UInt8>
    let gutterTable: ContiguousArray<ContiguousArray<UInt8>>
    let spacePadding: ContiguousArray<UInt8>
    let wrapGutterBytes: ContiguousArray<UInt8>
  }

  // Compute everything the per-line loop needs, once — nothing here repeats
  // per line. Sequential setup: each block feeds the next and none of it is
  // reusable elsewhere; splitting would only add parameter plumbing.
  // swiftlint:disable:next function_body_length
  private func buildRenderLayout(sourceBytes: [UInt8]) -> RenderLayout {
    // Wrap policy: --wrap=never disables; --wrap=auto wraps only when stdout is a TTY.
    // (Pipes/fzf previews handle their own width — extra newlines count as bonus rows.)
    let wrapEnabled: Bool
    let truncateLongLines: Bool
    let isTTY = stdoutIsTTY()
    switch wrap {
    case .never:
      wrapEnabled = false
      // Only clip to terminal width when output will actually be displayed in one
      // (TTY or explicit width override). Pipes get full lines — downstream
      // consumers handle their own width.
      truncateLongLines = isTTY || terminalWidthOverride != nil
    case .auto:
      wrapEnabled = isTTY || terminalWidthOverride != nil
      truncateLongLines = false
    }
    // Clamp the user override to the actual terminal width — wrapping wider
    // than the real terminal would let the terminal soft-wrap and break our
    // column accounting.
    let actualTermWidth = terminalSize().width
    let termWidth: Int
    if let override = terminalWidthOverride {
      termWidth = min(override, actualTermWidth)
    } else {
      termWidth = actualTermWidth
    }
    // Count lines without allocating — single pass
    var lineCount = 1
    for byte in sourceBytes where byte == 0x0A { lineCount += 1 }
    // Digit width without String allocation
    var digitWidth = 1
    var remaining = lineCount
    while remaining >= 10 {
      digitWidth += 1
      remaining /= 10
    }
    // No gutter in plain mode; also dropped when it can't fit alongside at
    // least one content column (a 3-col fzf preview pane, --terminal-width
    // at or below gutter width). The width math must never go negative —
    // 0..<contentCols traps — and never hit zero, or the wrap loop can't
    // make progress; the floor covers --terminal-width 0.
    let showGutter = !plain && termWidth > digitWidth + Self.gutterSeparatorWidth
    let gutterCols = showGutter ? digitWidth + Self.gutterSeparatorWidth : 0
    let contentCols = max(1, termWidth - gutterCols)

    // Pre-build editor bg escape for the code area. Skip in plain mode so
    // --color=never doesn't leak ANSI bg codes into pipe-friendly output.
    var editorBackground = ContiguousArray<UInt8>()
    if colorEnabled, let background = editorBgStyle {
      editorBackground.append(contentsOf: [0x1B, 0x5B, 0x34, 0x38, 0x3B, 0x32, 0x3B])
      ANSICodes.appendDecimal(background.red, into: &editorBackground)
      editorBackground.append(0x3B)
      ANSICodes.appendDecimal(background.green, into: &editorBackground)
      editorBackground.append(0x3B)
      ANSICodes.appendDecimal(background.blue, into: &editorBackground)
      editorBackground.append(0x6D)
    }

    let lineNumStyle = lineNumberStyle ?? baseColor
    // With no gutter (plain mode, or a pane too narrow to fit one), the table
    // holds empty entries (just bg setup) so emitGutter still primes the
    // editor bg without printing line numbers.
    let gutterTable: ContiguousArray<ContiguousArray<UInt8>>
    if !showGutter {
      gutterTable = Self.buildPlainGutterTable(lineCount: lineCount, editorBg: editorBackground)
    } else {
      gutterTable = Self.buildGutterTable(
        lineCount: lineCount, digitWidth: digitWidth,
        lineNumberStyle: lineNumStyle,
        gutterBgStyle: gutterBgStyle,
        editorBg: editorBackground
      )
    }

    // Pre-build space padding buffer — slice as needed for right-fill
    var spacePadding = ContiguousArray<UInt8>()
    if !editorBackground.isEmpty {
      for _ in 0..<contentCols { spacePadding.append(0x20) }
    }

    let wrapGutterBytes: ContiguousArray<UInt8>
    if !showGutter {
      wrapGutterBytes = Self.buildPlainWrapGutter(editorBg: editorBackground)
    } else {
      wrapGutterBytes = Self.buildWrapGutter(
        digitWidth: digitWidth,
        lineNumberStyle: lineNumStyle,
        gutterBgStyle: gutterBgStyle,
        editorBg: editorBackground
      )
    }

    return RenderLayout(
      wrapEnabled: wrapEnabled,
      truncateLongLines: truncateLongLines,
      contentCols: contentCols,
      lineCount: lineCount,
      editorBackground: editorBackground,
      gutterTable: gutterTable,
      spacePadding: spacePadding,
      wrapGutterBytes: wrapGutterBytes
    )
  }

  // Per-line render loop — pushing per-line work behind call boundaries
  // would cost on the hot path, so the loop stays in one function.
  // swiftlint:disable:next cyclomatic_complexity function_body_length
  func renderColorized(sourceBytes: [UInt8], tokens: [SyntaxToken]) -> (ANSIOutput, Int) {
    let layout = buildRenderLayout(sourceBytes: sourceBytes)
    let wrapEnabled = layout.wrapEnabled
    let truncateLongLines = layout.truncateLongLines
    let contentCols = layout.contentCols
    let editorBg = layout.editorBackground
    let spacePad = layout.spacePadding

    var output = ANSIOutput(
      enabled: colorEnabled,
      estimatedSize: sourceBytes.count * 2
    )

    var tokenIndex = 0
    var lineNumber = 1
    var lineStart = 0

    while lineStart < sourceBytes.count {
      // Find end of this line
      var lineEnd = lineStart
      while lineEnd < sourceBytes.count, sourceBytes[lineEnd] != 0x0A {
        lineEnd += 1
      }
      // CRLF: a trailing \r belongs to the line terminator, not the content.
      // Emitted raw it yanks the cursor to column 0 mid-line (overdraw, short
      // bg fill); it must also not count toward display width.
      var contentEnd = lineEnd
      if contentEnd > lineStart, sourceBytes[contentEnd - 1] == 0x0D {
        contentEnd -= 1
      }

      // Emit gutter with line number
      emitGutter(lineNumber: lineNumber, gutterTable: layout.gutterTable, into: &output)

      let lineLen = contentEnd - lineStart
      // Scan for ASCII-ness — needed by both bulk width math and truncation.
      var lineIsASCII = true
      var scan = lineStart
      while scan < contentEnd {
        if sourceBytes[scan] >= 0x80 {
          lineIsASCII = false
          break
        }
        scan += 1
      }
      // Bulk path is only safe when either wrap is disabled (we'll truncate)
      // or the whole line already fits in contentCols as pure ASCII. Must
      // measure display width (not byte length) because tabs expand.
      var lineDisplayWidth = 0
      if lineIsASCII {
        var byteIndex = lineStart
        while byteIndex < contentEnd {
          if sourceBytes[byteIndex] == 0x09 {
            lineDisplayWidth += tabStopWidth - (lineDisplayWidth % tabStopWidth)
          } else {
            lineDisplayWidth += 1
          }
          byteIndex += 1
        }
      }
      let canBulk = !wrapEnabled || (lineIsASCII && lineDisplayWidth <= contentCols)
      let shouldTruncate = truncateLongLines && !wrapEnabled
      var colUsed: Int
      if canBulk {
        // Truncate: when wrap is disabled, clip the emitted range to contentCols
        // so long lines don't overflow the terminal and soft-wrap.
        var emitEnd = contentEnd
        if shouldTruncate, lineLen > contentCols {
          if lineIsASCII {
            // ASCII: 1 byte == 1 column
            emitEnd = lineStart + contentCols
          } else {
            // Non-ASCII: walk characters and stop at the column limit
            emitEnd = truncateByteEnd(
              sourceBytes: sourceBytes,
              from: lineStart, to: contentEnd, maxColumns: contentCols
            )
          }
        }
        // Fast path: bulk emit, no per-byte wrap check. The returned column
        // already has tab stops expanded and (on non-ASCII lines) scalar
        // widths measured — no separate recompute.
        colUsed = emitLineBulk(
          sourceBytes: sourceBytes,
          lineStart: lineStart, lineEnd: emitEnd, lineIsASCII: lineIsASCII,
          tokens: tokens, tokenIndex: &tokenIndex,
          into: &output
        )
        // If truncated, advance tokenIndex past any tokens we skipped on this line
        if emitEnd < contentEnd {
          while tokenIndex < tokens.count, tokens[tokenIndex].startByte < lineEnd {
            tokenIndex += 1
          }
        }
      } else {
        // Slow path: line may wrap — per-byte column tracking.
        let wrapIndent = Self.measureWrapIndent(
          sourceBytes: sourceBytes, lineStart: lineStart,
          contentEnd: contentEnd, contentCols: contentCols)
        let lineWriter = WrappedLineWriter(
          contentCols: contentCols, wrapGutterBytes: layout.wrapGutterBytes,
          spacePad: spacePad, editorBg: editorBg, wrapIndent: wrapIndent,
          colorEnabled: colorEnabled, colorTable: colorTable, baseColor: baseColor)
        colUsed = lineWriter.emitLine(
          sourceBytes: sourceBytes,
          lineStart: lineStart, lineEnd: contentEnd,
          tokens: tokens, tokenIndex: &tokenIndex,
          into: &output
        )
      }

      // Fill remaining columns with editor background
      if colUsed < contentCols, !editorBg.isEmpty {
        let fillCount = contentCols - colUsed
        output.text(editorBg)
        output.text(spacePad[spacePad.startIndex..<spacePad.startIndex + fillCount])
        output.reset()
      }

      // Newline between lines, but not after the last one
      lineStart = lineEnd + 1
      if lineStart < sourceBytes.count {
        output.newline()
      }
      lineNumber += 1
    }

    output.reset()
    // Always end with a newline so zsh doesn't show its missing-newline `%`
    // marker in a TTY, and downstream pipes see a properly terminated stream.
    output.newline()
    return (output, layout.lineCount)
  }

  /// Leading whitespace of the line in display columns, for wrap-continuation
  /// alignment under the first non-whitespace character. Alignment only
  /// happens when the full indent fits within half of `contentCols` — a
  /// deeper indent can't truly align and would starve narrow rows of room
  /// for words, so those lines wrap flush (0) instead.
  private static func measureWrapIndent(
    sourceBytes: [UInt8], lineStart: Int, contentEnd: Int, contentCols: Int
  ) -> Int {
    var wrapIndent = 0
    let indentCap = contentCols / 2
    var scanIndex = lineStart
    while scanIndex < contentEnd, wrapIndent < indentCap {
      let byte = sourceBytes[scanIndex]
      if byte == 0x20 {
        wrapIndent += 1
      } else if byte == 0x09 {
        wrapIndent += tabStopWidth - (wrapIndent % tabStopWidth)
      } else {
        break
      }
      scanIndex += 1
    }
    let stoppedMidWhitespace =
      scanIndex < contentEnd
      && (sourceBytes[scanIndex] == 0x20 || sourceBytes[scanIndex] == 0x09)
    if wrapIndent > indentCap || stoppedMidWhitespace { return 0 }
    return wrapIndent
  }

  /// Walk a UTF-8 byte range and return the byte index where cumulative
  /// display width would exceed `maxColumns`. Used to truncate non-ASCII lines
  /// when wrap is disabled.
  private func truncateByteEnd(
    sourceBytes: [UInt8], from start: Int, to end: Int, maxColumns: Int
  ) -> Int {
    var byteIndex = start
    var column = 0
    var walker = WidthWalker()
    var previousWasASCII = false
    while byteIndex < end {
      let byte = sourceBytes[byteIndex]
      if byte < 0x80 {
        if column + 1 > maxColumns { return byteIndex }
        column += 1
        byteIndex += 1
        previousWasASCII = true
      } else {
        if previousWasASCII {
          walker.noteASCIIRun()
          previousWasASCII = false
        }
        let characterStart = byteIndex
        byteIndex += 1
        while byteIndex < end, sourceBytes[byteIndex] & 0xC0 == 0x80 { byteIndex += 1 }
        let character = String(decoding: sourceBytes[characterStart..<byteIndex], as: UTF8.self)
        let characterWidth = character.unicodeScalars.reduce(0) { $0 + walker.consume($1.value) }
        if column + characterWidth > maxColumns { return characterStart }
        column += characterWidth
      }
    }
    return end
  }
}
