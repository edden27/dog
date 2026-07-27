#if canImport(Darwin)
  import Darwin
#elseif canImport(Glibc)
  import Glibc
#endif

/// Number of display columns a tab character advances to the next tab stop.
/// Defaults to 4 — tighter than the 8-column terminal default, which wastes
/// horizontal space for code that uses tabs for indentation (Go, Makefiles).
let tabStopWidth = 4

/// Reads a file or stdin, highlights it, and writes colored output to stdout.
struct PrintCommand {
  let file: String?
  let language: String?
  let plain: Bool
  let colorEnabled: Bool
  let paging: PagingOption
  let wrap: WrapOption
  /// User-supplied terminal width override (columns). When nil, autodetect.
  let terminalWidthOverride: Int?
  /// O(1) array-indexed color table — no closure indirection.
  let colorTable: [Style]
  let baseColor: Style
  let lineNumberStyle: Style?
  let gutterBgStyle: Style?
  let editorBgStyle: Style?
  /// Pre-loaded source bytes — when set, skips file/stdin reading.
  /// Used by `--woof` to feed embedded snippets through the normal pipeline.
  let sourceOverride: [UInt8]?

  init(
    file: String?,
    language: String?,
    plain: Bool,
    colorEnabled: Bool,
    paging: PagingOption,
    wrap: WrapOption,
    terminalWidthOverride: Int?,
    colorTable: [Style],
    baseColor: Style,
    lineNumberStyle: Style?,
    gutterBgStyle: Style?,
    editorBgStyle: Style?,
    sourceOverride: [UInt8]? = nil
  ) {
    self.file = file
    self.language = language
    self.plain = plain
    self.colorEnabled = colorEnabled
    self.paging = paging
    self.wrap = wrap
    self.terminalWidthOverride = terminalWidthOverride
    self.colorTable = colorTable
    self.baseColor = baseColor
    self.lineNumberStyle = lineNumberStyle
    self.gutterBgStyle = gutterBgStyle
    self.editorBgStyle = editorBgStyle
    self.sourceOverride = sourceOverride
  }

  /// Execute the highlight-and-print pipeline.
  func run() async throws {
    let sourceBytes: [UInt8]
    if let override = sourceOverride {
      sourceBytes = override
    } else {
      do {
        sourceBytes = try readSourceBytes()
      } catch DogError.binaryFile(let path) {
        // Soft message instead of hard error — plays nicely with fzf previews
        var output = ANSIOutput(enabled: colorEnabled)
        output.text("\(path): binary file")
        output.newline()
        output.flush()
        return
      }
    }

    // Detect language: explicit flag → filename → extension → shebang
    let detectedLang = LanguageDetector.detect(
      filename: file,
      sourceBytes: sourceBytes,
      explicit: language
    )

    // Parse with tree-sitter if we have a language
    var output: ANSIOutput
    var lineCount: Int

    if let lang = detectedLang {
      let tokens = try await SyntaxParser.parse(sourceBytes: sourceBytes, language: lang)
      Bark.debug("parsed \(tokens.count) tokens for \(lang)")
      (output, lineCount) = renderColorized(sourceBytes: sourceBytes, tokens: tokens)
    } else {
      output = ANSIOutput(enabled: colorEnabled, estimatedSize: sourceBytes.count)
      lineCount = sourceBytes.reduce(0) { $0 + ($1 == 0x0A ? 1 : 0) } + 1
      output.text(sourceBytes[...])
    }

    // Pager decision
    let term = terminalSize()
    let usePager: Bool
    switch paging {
    case .never: usePager = false
    case .always: usePager = stdoutIsTTY()
    case .auto: usePager = stdoutIsTTY() && lineCount > term.height
    }

    if usePager {
      _ = Pager.run(buffer: &output)
    } else {
      output.flush()
    }
  }

  // MARK: - Rendering

  /// Gutter visual width: digits + " │ " (space, box-drawing, space = 3 display cols).
  private static let gutterSeparatorWidth = 3

  private func renderColorized(sourceBytes: [UInt8], tokens: [SyntaxToken]) -> (ANSIOutput, Int) {
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

    var output = ANSIOutput(
      enabled: colorEnabled,
      estimatedSize: sourceBytes.count * 2
    )

    // Pre-build editor bg escape for the code area. Skip in plain mode so
    // --color=never doesn't leak ANSI bg codes into pipe-friendly output.
    var editorBg = ContiguousArray<UInt8>()
    if colorEnabled, let background = editorBgStyle {
      editorBg.append(contentsOf: [0x1B, 0x5B, 0x34, 0x38, 0x3B, 0x32, 0x3B])
      ANSICodes.appendDecimal(background.r, into: &editorBg)
      editorBg.append(0x3B)
      ANSICodes.appendDecimal(background.g, into: &editorBg)
      editorBg.append(0x3B)
      ANSICodes.appendDecimal(background.b, into: &editorBg)
      editorBg.append(0x6D)
    }

    let lineNumStyle = lineNumberStyle ?? baseColor
    // With no gutter (plain mode, or a pane too narrow to fit one), the table
    // holds empty entries (just bg setup) so emitGutter still primes the
    // editor bg without printing line numbers.
    let gutterTable: ContiguousArray<ContiguousArray<UInt8>>
    if !showGutter {
      gutterTable = Self.buildPlainGutterTable(lineCount: lineCount, editorBg: editorBg)
    } else {
      gutterTable = Self.buildGutterTable(
        lineCount: lineCount, digitWidth: digitWidth,
        lineNumberStyle: lineNumStyle,
        gutterBgStyle: gutterBgStyle,
        editorBg: editorBg
      )
    }

    // Pre-build space padding buffer — slice as needed for right-fill
    var spacePad = ContiguousArray<UInt8>()
    if !editorBg.isEmpty {
      for _ in 0..<contentCols { spacePad.append(0x20) }
    }

    let wrapGutterBytes: ContiguousArray<UInt8>
    if !showGutter {
      wrapGutterBytes = Self.buildPlainWrapGutter(editorBg: editorBg)
    } else {
      wrapGutterBytes = Self.buildWrapGutter(
        digitWidth: digitWidth,
        lineNumberStyle: lineNumStyle,
        gutterBgStyle: gutterBgStyle,
        editorBg: editorBg
      )
    }

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
      emitGutter(lineNumber: lineNumber, gutterTable: gutterTable, into: &output)

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
        // Fast path: bulk emit, no per-byte wrap check
        emitLineBulk(
          sourceBytes: sourceBytes,
          lineStart: lineStart, lineEnd: emitEnd,
          tokens: tokens, tokenIndex: &tokenIndex,
          into: &output
        )
        if lineIsASCII {
          colUsed = 0
          for byteIdx in lineStart..<emitEnd {
            if sourceBytes[byteIdx] == 0x09 {
              colUsed += tabStopWidth - (colUsed % tabStopWidth)
            } else {
              colUsed += 1
            }
          }
        } else {
          // Non-ASCII bulk path (wrap disabled): measure display columns
          let str = String(decoding: sourceBytes[lineStart..<emitEnd], as: UTF8.self)
          colUsed = str.unicodeScalars.reduce(0) { $0 + $1.terminalWidth }
        }
        // If truncated, advance tokenIndex past any tokens we skipped on this line
        if emitEnd < contentEnd {
          while tokenIndex < tokens.count, tokens[tokenIndex].startByte < lineEnd {
            tokenIndex += 1
          }
        }
      } else {
        // Slow path: line may wrap — per-byte column tracking.
        // Measure leading whitespace in display columns so wrap continuations
        // align under the first non-whitespace char. Cap at half contentCols
        // to keep continuations usable on deeply indented lines.
        var wrapIndent = 0
        let indentCap = contentCols / 2
        var scanIdx = lineStart
        while scanIdx < contentEnd, wrapIndent < indentCap {
          let byte = sourceBytes[scanIdx]
          if byte == 0x20 {
            wrapIndent += 1
          } else if byte == 0x09 {
            wrapIndent += tabStopWidth - (wrapIndent % tabStopWidth)
          } else {
            break
          }
          scanIdx += 1
        }
        if wrapIndent > indentCap { wrapIndent = indentCap }
        let lineWriter = WrappedLineWriter(
          contentCols: contentCols, wrapGutterBytes: wrapGutterBytes,
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
    return (output, lineCount)
  }

  /// Plain-mode gutter entries: just reset + editor bg, repeated per line.
  /// Lets `emitGutter` prime the bg before each line without printing a number.
  private static func buildPlainGutterTable(
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
  private static func buildPlainWrapGutter(
    editorBg: ContiguousArray<UInt8>
  ) -> ContiguousArray<UInt8> {
    var buf = ContiguousArray<UInt8>()
    buf.append(contentsOf: ANSICodes.reset)
    buf.append(0x0A)
    buf.append(contentsOf: editorBg)
    return buf
  }

  /// Walk a UTF-8 byte range and return the byte index where cumulative
  /// display width would exceed `maxColumns`. Used to truncate non-ASCII lines
  /// when wrap is disabled.
  private func truncateByteEnd(
    sourceBytes: [UInt8], from start: Int, to end: Int, maxColumns: Int
  ) -> Int {
    var byteIndex = start
    var column = 0
    while byteIndex < end {
      let byte = sourceBytes[byteIndex]
      if byte < 0x80 {
        if column + 1 > maxColumns { return byteIndex }
        column += 1
        byteIndex += 1
      } else {
        let characterStart = byteIndex
        byteIndex += 1
        while byteIndex < end, sourceBytes[byteIndex] & 0xC0 == 0x80 { byteIndex += 1 }
        let character = String(decoding: sourceBytes[characterStart..<byteIndex], as: UTF8.self)
        let characterWidth = character.unicodeScalars.reduce(0) { $0 + $1.terminalWidth }
        if column + characterWidth > maxColumns { return characterStart }
        column += characterWidth
      }
    }
    return end
  }

  /// Fast path: emit a line that fits entirely within contentCols. Bulk slices, no column tracking.
  /// Tabs are expanded to spaces against a content-relative column so the terminal's
  /// absolute tab stops (offset by gutter width) don't desync the trailing bg fill.
  private func emitLineBulk(
    sourceBytes: [UInt8],
    lineStart: Int, lineEnd: Int,
    tokens: [SyntaxToken], tokenIndex: inout Int,
    into output: inout ANSIOutput
  ) {
    var position = lineStart
    var column = 0
    var lastStyle: Style?

    while tokenIndex < tokens.count, tokens[tokenIndex].endByte <= lineStart {
      tokenIndex += 1
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
        if lastStyle != baseColor {
          output.colorDelta(from: lastStyle, to: baseColor)
          lastStyle = baseColor
        }
        emitBulkSlice(
          sourceBytes: sourceBytes, from: position, to: tokenStart,
          column: &column, into: &output
        )
      }

      let style = colorTable[(token.tokenType ?? .none).rawValue]
      if style != lastStyle {
        output.colorDelta(from: lastStyle, to: style)
        lastStyle = style
      }
      emitBulkSlice(
        sourceBytes: sourceBytes, from: tokenStart, to: tokenEnd,
        column: &column, into: &output
      )
      position = tokenEnd

      if token.endByte <= lineEnd { tokenIndex += 1 } else { break }
    }

    if position < lineEnd {
      if lastStyle != baseColor {
        output.colorDelta(from: lastStyle, to: baseColor)
      }
      emitBulkSlice(
        sourceBytes: sourceBytes, from: position, to: lineEnd,
        column: &column, into: &output
      )
    }

    output.reset()
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
    column: inout Int,
    into output: inout ANSIOutput
  ) {
    guard start < end else { return }
    let slice = sourceBytes[start..<end]
    guard let firstTab = slice.firstIndex(of: 0x09) else {
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

  /// Pre-built gutter bytes: reset + padding + color + digits + reset + separator.
  /// Built once per render, indexed by line number. Avoids per-line String allocation.
  private static func buildGutterTable(
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
      ANSICodes.appendDecimal(gutterBg.r, into: &bgBytes)
      bgBytes.append(0x3B)
      ANSICodes.appendDecimal(gutterBg.g, into: &bgBytes)
      bgBytes.append(0x3B)
      ANSICodes.appendDecimal(gutterBg.b, into: &bgBytes)
      bgBytes.append(0x6D)
    }

    // Pre-build the line number fg escape (just the foreground, no reset)
    var fgBytes = ContiguousArray<UInt8>()
    fgBytes.append(contentsOf: [0x1B, 0x5B, 0x33, 0x38, 0x3B, 0x32, 0x3B])
    ANSICodes.appendDecimal(lineNumberStyle.r, into: &fgBytes)
    fgBytes.append(0x3B)
    ANSICodes.appendDecimal(lineNumberStyle.g, into: &fgBytes)
    fgBytes.append(0x3B)
    ANSICodes.appendDecimal(lineNumberStyle.b, into: &fgBytes)
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

  private func emitGutter(
    lineNumber: Int, gutterTable: ContiguousArray<ContiguousArray<UInt8>>,
    into output: inout ANSIOutput
  ) {
    guard colorEnabled else { return }
    output.text(gutterTable[lineNumber - 1])
  }

  /// Emit gutter padding for wrapped continuation lines, then re-emit the active style.
  /// Pre-built wrap continuation gutter: newline + reset + bg + spaces + fg + " │" + reset + space.
  private static func buildWrapGutter(
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
      ANSICodes.appendDecimal(gutterBg.r, into: &buf)
      buf.append(0x3B)
      ANSICodes.appendDecimal(gutterBg.g, into: &buf)
      buf.append(0x3B)
      ANSICodes.appendDecimal(gutterBg.b, into: &buf)
      buf.append(0x6D)
    }
    // Blank padding where number would be
    for _ in 0..<digitWidth { buf.append(0x20) }
    // Line number fg for │
    buf.append(contentsOf: [0x1B, 0x5B, 0x33, 0x38, 0x3B, 0x32, 0x3B])
    ANSICodes.appendDecimal(lineNumberStyle.r, into: &buf)
    buf.append(0x3B)
    ANSICodes.appendDecimal(lineNumberStyle.g, into: &buf)
    buf.append(0x3B)
    ANSICodes.appendDecimal(lineNumberStyle.b, into: &buf)
    buf.append(0x6D)
    // " │" + reset + editor bg for trailing space
    buf.append(contentsOf: [0x20, 0xE2, 0x94, 0x82])
    buf.append(contentsOf: ANSICodes.reset)
    buf.append(contentsOf: editorBg)
    buf.append(0x20)

    return buf
  }

  // MARK: - Private

  private func readSourceBytes() throws -> [UInt8] {
    if let file {
      let descriptor = open(file, O_RDONLY)
      guard descriptor >= 0 else {
        throw DogError.fileNotFound(path: file)
      }
      defer { close(descriptor) }

      // Get file size for single-shot read
      var fileInfo = stat()
      guard fstat(descriptor, &fileInfo) == 0 else {
        throw DogError.readError(path: file, detail: "could not access file info")
      }
      guard (fileInfo.st_mode & S_IFMT) != S_IFDIR else {
        throw DogError.readError(path: file, detail: "it is a directory")
      }
      let size = Int(fileInfo.st_size)
      var bytes = [UInt8](repeating: 0, count: size)
      let bytesRead = bytes.withUnsafeMutableBufferPointer { buf in
        read(descriptor, buf.baseAddress, size)
      }
      guard bytesRead == size else {
        throw DogError.readError(path: file, detail: "file changed while reading")
      }
      guard bytes.isValidUTF8 else {
        throw DogError.binaryFile(path: file)
      }
      return bytes
    }

    // Read from stdin
    var bytes: [UInt8] = []
    let chunkSize = 64 * 1024
    var chunk = [UInt8](repeating: 0, count: chunkSize)
    while true {
      let bytesRead = chunk.withUnsafeMutableBufferPointer { buf in
        read(STDIN_FILENO, buf.baseAddress, chunkSize)
      }
      if bytesRead <= 0 { break }
      bytes.append(contentsOf: chunk[..<bytesRead])
    }
    guard bytes.isValidUTF8 else {
      throw DogError.readError(
        path: "<stdin>",
        detail: "input is not valid UTF-8"
      )
    }
    return bytes
  }
}

extension Array where Element == UInt8 {
  /// Check whether the bytes are valid UTF-8.
  fileprivate var isValidUTF8: Bool {
    withUnsafeBufferPointer { buf in
      var iter = buf.makeIterator()
      var codec = UTF8()
      while true {
        switch codec.decode(&iter) {
        case .scalarValue: continue
        case .emptyInput: return true
        case .error: return false
        }
      }
    }
  }
}
