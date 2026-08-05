#if canImport(Darwin)
  import Darwin
#elseif canImport(Glibc)
  import Glibc
#endif

/// Precomputed default-theme artifact for `--set-default-theme`.
///
/// `dog --set-default-theme <theme>` resolves the theme once and saves the
/// finished style table to `<configDir>/default-theme`. Startup then loads
/// finished bytes (~17µs measured, full open→decode→table cost) instead of
/// parsing theme JSON (~0.5ms). When no artifact exists the probe is one
/// failed open (~1µs). Evidence and format comparison:
/// perf/experiments/009-set-default-theme-artifact/bench_artifact.swift.
///
/// Binary layout (all integers little endian):
///   "DOGT" magic, version u8 (1), format u8 (1 = packed-only),
///   token-style count u16, optional-presence flags u8
///   (bit 0 lineNumber, bit 1 gutterBg, bit 2 editorBg),
///   then packed `Style` u64 slots: base, lineNumber, gutterBg, editorBg,
///   then `count` token styles indexed by `TokenType.rawValue`,
///   then the theme's display name as UTF-8 to end of file.
///
/// Stores only packed color values, never derived ANSI bytes — the running
/// binary always rebuilds escape bytes with its own current code, so an
/// artifact written by an older dog can never replay stale output. The
/// rebuild costs ~1µs for a full table (measured).
enum DefaultThemeArtifact {

  /// What loading the artifact found.
  enum LoadOutcome {
    /// No artifact file exists — no default theme has been set.
    case none
    /// A file exists but could not be used (truncated, wrong magic or
    /// version, or a token count from a different dog build).
    case unreadable
    /// The artifact decoded cleanly.
    case loaded(name: String, styles: Dog.ResolvedThemeStyles)
  }

  /// `<configDir>/default-theme`. Empty string if the config dir is unknown.
  static var artifactPath: String {
    let base = ConfigPaths.configDir
    return base.isEmpty ? "" : "\(base)/default-theme"
  }

  private static let magic: [UInt8] = Array("DOGT".utf8)
  private static let formatVersion: UInt8 = 1
  private static let formatPackedOnly: UInt8 = 1
  /// Magic + version + format + count u16 + optional flags.
  private static let headerByteCount = 9
  /// Base color + the three optional slots, always present.
  private static let fixedSlotCount = 4

  // MARK: - Save

  /// Encode `styles` and write the artifact, creating the config directory
  /// if needed.
  static func save(
    styles: Dog.ResolvedThemeStyles, themeName: String,
    path: String = artifactPath
  ) throws {
    guard !path.isEmpty else {
      throw DogError.writeError(
        path: "<config dir>", detail: "HOME is not set"
      )
    }
    if let slashIndex = path.lastIndex(of: "/"), slashIndex != path.startIndex {
      let directory = String(path[..<slashIndex])
      guard createDirectoryTree(directory) else {
        throw DogError.writeError(
          path: directory, detail: String(cString: strerror(errno))
        )
      }
    }

    let contents = encode(styles: styles, themeName: themeName)
    let descriptor = open(path, O_WRONLY | O_CREAT | O_TRUNC, 0o644)
    guard descriptor >= 0 else {
      throw DogError.writeError(
        path: path, detail: String(cString: strerror(errno))
      )
    }
    defer { close(descriptor) }
    let written = contents.withUnsafeBytes { raw in
      write(descriptor, raw.baseAddress, raw.count)
    }
    guard written == contents.count else {
      throw DogError.writeError(path: path, detail: "short write")
    }
  }

  // MARK: - Remove

  /// Delete the artifact — clearing the saved default. Nothing to delete
  /// is fine (clearing twice should stay friendly).
  static func remove(path: String = artifactPath) throws {
    guard !path.isEmpty else { return }
    if unlink(path) != 0 && errno != ENOENT {
      throw DogError.writeError(
        path: path, detail: String(cString: strerror(errno))
      )
    }
  }

  // MARK: - Load

  /// Load the artifact. Absent file is `.none` (the normal case for anyone
  /// who never ran `--set-default-theme`); any decode problem is
  /// `.unreadable` so the caller can warn and fall back.
  static func load(path: String = artifactPath) -> LoadOutcome {
    guard !path.isEmpty else { return .none }
    let descriptor = open(path, O_RDONLY)
    guard descriptor >= 0 else {
      return errno == ENOENT ? .none : .unreadable
    }
    defer { close(descriptor) }
    var info = stat()
    guard fstat(descriptor, &info) == 0 else { return .unreadable }
    let size = Int(info.st_size)
    let tokenCount = TokenType.allCases.count
    let minimumSize = headerByteCount + (fixedSlotCount + tokenCount) * 8
    guard size >= minimumSize else { return .unreadable }

    let contents = [UInt8](unsafeUninitializedCapacity: size) { buffer, initializedCount in
      var total = 0
      while total < size {
        let readCount = read(descriptor, buffer.baseAddress! + total, size - total)
        if readCount <= 0 { break }
        total += readCount
      }
      initializedCount = total
    }
    guard contents.count == size else { return .unreadable }
    return decode(contents)
  }

  // MARK: - Encoding

  private static func encode(
    styles: Dog.ResolvedThemeStyles, themeName: String
  ) -> [UInt8] {
    let tokenCount = styles.colorTable.count
    var out = magic
    out.reserveCapacity(
      headerByteCount + (fixedSlotCount + tokenCount) * 8 + themeName.utf8.count
    )
    out.append(formatVersion)
    out.append(formatPackedOnly)
    out.append(UInt8(tokenCount & 0xFF))
    out.append(UInt8((tokenCount >> 8) & 0xFF))
    var flags: UInt8 = 0
    if styles.lineNumberStyle != nil { flags |= 1 }
    if styles.gutterBgStyle != nil { flags |= 2 }
    if styles.editorBgStyle != nil { flags |= 4 }
    out.append(flags)

    appendLittleEndian(styles.baseColor.packed, into: &out)
    appendLittleEndian(styles.lineNumberStyle?.packed ?? 0, into: &out)
    appendLittleEndian(styles.gutterBgStyle?.packed ?? 0, into: &out)
    appendLittleEndian(styles.editorBgStyle?.packed ?? 0, into: &out)
    for style in styles.colorTable {
      appendLittleEndian(style.packed, into: &out)
    }
    out.append(contentsOf: themeName.utf8)
    return out
  }

  private static func appendLittleEndian(_ value: UInt64, into out: inout [UInt8]) {
    var remaining = value
    for _ in 0..<8 {
      out.append(UInt8(truncatingIfNeeded: remaining))
      remaining >>= 8
    }
  }

  // MARK: - Decoding

  private static func decode(_ contents: [UInt8]) -> LoadOutcome {
    contents.withUnsafeBytes { raw -> LoadOutcome in
      guard raw[0] == magic[0], raw[1] == magic[1],
        raw[2] == magic[2], raw[3] == magic[3],
        raw[4] == formatVersion, raw[5] == formatPackedOnly
      else { return .unreadable }
      let count = Int(raw[6]) | (Int(raw[7]) << 8)
      // A count from a different dog build means the table would misalign
      // with TokenType — treat as stale, caller warns to re-run the command.
      guard count == TokenType.allCases.count else { return .unreadable }
      let flags = raw[8]

      var offset = headerByteCount
      func loadPacked() -> UInt64 {
        let value = UInt64(
          littleEndian: raw.loadUnaligned(fromByteOffset: offset, as: UInt64.self)
        )
        offset += 8
        return value
      }

      let baseColor = style(fromPacked: loadPacked())
      let lineNumberPacked = loadPacked()
      let gutterBgPacked = loadPacked()
      let editorBgPacked = loadPacked()
      var colorTable: [Style] = []
      colorTable.reserveCapacity(count)
      for _ in 0..<count {
        colorTable.append(style(fromPacked: loadPacked()))
      }
      let name = String(decoding: contents[offset...], as: UTF8.self)
      guard !name.isEmpty else { return .unreadable }

      let styles = Dog.ResolvedThemeStyles(
        colorTable: colorTable,
        baseColor: baseColor,
        lineNumberStyle: flags & 1 != 0 ? style(fromPacked: lineNumberPacked) : nil,
        gutterBgStyle: flags & 2 != 0 ? style(fromPacked: gutterBgPacked) : nil,
        editorBgStyle: flags & 4 != 0 ? style(fromPacked: editorBgPacked) : nil
      )
      return .loaded(name: name, styles: styles)
    }
  }

  /// Rebuild a `Style` from its packed value — ANSI bytes are regenerated
  /// by the running binary, never stored.
  private static func style(fromPacked packed: UInt64) -> Style {
    let red = UInt8((packed >> 16) & 0xFF)
    let green = UInt8((packed >> 24) & 0xFF)
    let blue = UInt8((packed >> 32) & 0xFF)
    let bold = packed & (1 << 6) != 0
    let italic = packed & (1 << 7) != 0
    if packed & (1 << 5) != 0 {
      return Style(
        red: red, green: green, blue: blue,
        backgroundRed: UInt8((packed >> 40) & 0xFF),
        backgroundGreen: UInt8((packed >> 48) & 0xFF),
        backgroundBlue: UInt8((packed >> 56) & 0xFF),
        bold: bold, italic: italic
      )
    }
    return Style(red: red, green: green, blue: blue, bold: bold, italic: italic)
  }

  // MARK: - Directory creation

  /// `mkdir -p` without Foundation: create the directory and any missing
  /// parents. Returns false only when a component cannot be created.
  private static func createDirectoryTree(_ path: String) -> Bool {
    if mkdir(path, 0o755) == 0 || errno == EEXIST { return true }
    guard errno == ENOENT,
      let slashIndex = path.lastIndex(of: "/"), slashIndex != path.startIndex
    else { return false }
    guard createDirectoryTree(String(path[..<slashIndex])) else { return false }
    return mkdir(path, 0o755) == 0 || errno == EEXIST
  }
}
