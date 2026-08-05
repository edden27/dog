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
