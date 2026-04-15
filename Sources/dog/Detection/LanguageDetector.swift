#if canImport(Darwin)
  import Darwin
#elseif canImport(Glibc)
  import Glibc
#endif

/// Four-stage language detection cascade.
///
/// Priority: explicit flag → filename → extension → shebang.
/// Stops at the first match. Returns nil if no language can be determined.
enum LanguageDetector {

  // MARK: - Public API

  /// Detect language for a file or stdin input.
  ///
  /// - Parameters:
  ///   - filename: The filename (not full path) if available. Nil for stdin.
  ///   - sourceBytes: Raw UTF-8 bytes (only the first line is read, for shebang detection).
  ///   - explicit: Language name from `-l` flag, if provided.
  /// - Returns: Language name suitable for `LanguageRegistry.lookup()`, or nil.
  static func detect(
    filename: String?,
    sourceBytes: [UInt8],
    explicit: String?
  ) -> String? {
    // Stage 1: explicit flag
    if let explicit, !explicit.isEmpty {
      Bark.debug("detection: explicit flag '\(explicit)'")
      return explicit
    }

    if let filename {
      // Stage 2: exact filename match
      if let lang = detectByFilename(filename) {
        Bark.debug("detection: filename '\(filename)' → \(lang)")
        return lang
      }

      // Stage 3: file extension
      if let lang = detectByExtension(filename) {
        Bark.debug("detection: extension '\(filename)' → \(lang)")
        return lang
      }
    }

    // Stage 4: shebang — only convert the first line to String
    let firstLine = firstLineString(from: sourceBytes)
    if let lang = detectByShebang(firstLine) {
      Bark.debug("detection: shebang → \(lang)")
      return lang
    }

    Bark.debug("detection: no language detected")
    return nil
  }

  /// Convert only the first line of a byte buffer to a String for shebang parsing.
  private static func firstLineString(from bytes: [UInt8]) -> String {
    let end = bytes.firstIndex(of: 0x0A) ?? bytes.endIndex
    return String(decoding: bytes[bytes.startIndex..<end], as: UTF8.self)
  }

  // MARK: - Stage 2: Filename

  private static func detectByFilename(_ name: String) -> String? {
    // Extract just the filename from a path using UTF8View backward scan
    let filename = extractFilename(name)
    return LanguageMap.filenames[filename]
  }

  // MARK: - Stage 3: Extension

  private static func detectByExtension(_ name: String) -> String? {
    let filename = extractFilename(name)
    guard let ext = extractExtension(filename) else { return nil }

    // Try direct extension lookup
    if let lang = LanguageMap.extensions[ext] {
      return lang
    }

    // Strip ignored suffix and retry once
    if let stripped = stripIgnoredSuffix(filename) {
      if let retryExt = extractExtension(stripped) {
        return LanguageMap.extensions[retryExt]
      }
    }

    return nil
  }

  // MARK: - Stage 4: Shebang

  private static func detectByShebang(_ source: String) -> String? {
    guard let interpreter = parseShebang(source) else { return nil }
    return LanguageMap.interpreters[interpreter]
  }

  // MARK: - String Operations (UTF8View)

  /// Extract filename from a path. UTF8View backward scan for '/'.
  private static func extractFilename(_ path: String) -> String {
    let utf8 = path.utf8
    var scan = utf8.endIndex
    while scan > utf8.startIndex {
      utf8.formIndex(before: &scan)
      if utf8[scan] == 0x2F {  // '/'
        let nameStart = utf8.index(after: scan)
        return String(path[nameStart...])
      }
    }
    return path
  }

  /// Extract file extension (including dot). UTF8View backward scan for '.'.
  /// Returns nil for dotfiles (.bashrc) and extensionless files.
  private static func extractExtension(_ name: String) -> String? {
    let utf8 = name.utf8
    var scan = utf8.endIndex
    while scan > utf8.startIndex {
      utf8.formIndex(before: &scan)
      if utf8[scan] == 0x2E {  // '.'
        if scan == utf8.startIndex { return nil }  // dotfile
        return String(name[scan...])
      }
    }
    return nil
  }

  /// Pre-converted ignored suffixes as [UInt8] for fast memcmp.
  private static let suffixBytes: [[UInt8]] = LanguageMap.ignoredSuffixes.map { Array($0.utf8) }

  /// Strip one ignored suffix from the filename. Returns nil if no suffix matched.
  private static func stripIgnoredSuffix(_ name: String) -> String? {
    var foundLength: Int?
    name.utf8.withContiguousStorageIfAvailable { buf in
      guard let baseAddress = buf.baseAddress else { return }
      let nameLength = buf.count
      for suffix in suffixBytes {
        let suffixLength = suffix.count
        guard suffixLength <= nameLength else { continue }
        if memcmp(baseAddress + nameLength - suffixLength, suffix, suffixLength) == 0 {
          foundLength = suffixLength
          return
        }
      }
    }
    guard let matchedLength = foundLength else { return nil }
    return String(name.dropLast(matchedLength))
  }

  /// Parse a shebang line to extract the interpreter name.
  /// UTF8View forward scan. Handles env with flags (-u consumes next token),
  /// variable assignments, and version stripping.
  private static func parseShebang(_ source: String) -> String? {
    let utf8 = source.utf8
    guard utf8.count >= 2 else { return nil }
    var cursor = utf8.startIndex
    guard utf8[cursor] == 0x23, utf8[utf8.index(after: cursor)] == 0x21 else { return nil }  // #!
    utf8.formIndex(&cursor, offsetBy: 2)

    // Find end of first line
    var lineEnd = cursor
    while lineEnd < utf8.endIndex && utf8[lineEnd] != 0x0A {  // '\n'
      utf8.formIndex(after: &lineEnd)
    }

    // Skip whitespace
    while cursor < lineEnd && utf8[cursor] == 0x20 { utf8.formIndex(after: &cursor) }
    guard cursor < lineEnd else { return nil }

    let binary = extractBinaryName(source: source, utf8: utf8, cursor: &cursor, lineEnd: lineEnd)

    if binary == "env" {
      return parseEnvInterpreter(source: source, utf8: utf8, cursor: cursor, lineEnd: lineEnd)
    }

    return stripVersion(binary)
  }

  /// Extract the binary name from the first token in a shebang line.
  /// Advances `cursor` past the first token.
  private static func extractBinaryName(
    source: String,
    utf8: String.UTF8View,
    cursor: inout String.Index,
    lineEnd: String.Index
  ) -> String {
    let pathStart = cursor
    while cursor < lineEnd && utf8[cursor] != 0x20 { utf8.formIndex(after: &cursor) }
    let pathEnd = cursor

    // Scan backward for last '/' to get the binary name
    var binStart = pathEnd
    var scan = pathEnd
    while scan > pathStart {
      utf8.formIndex(before: &scan)
      if utf8[scan] == 0x2F {
        binStart = utf8.index(after: scan)
        break
      }
    }
    if binStart == pathEnd { binStart = pathStart }
    return String(source[binStart..<pathEnd])
  }

  /// Parse the interpreter after `env`, skipping flags and var assignments.
  private static func parseEnvInterpreter(
    source: String,
    utf8: String.UTF8View,
    cursor start: String.Index,
    lineEnd: String.Index
  ) -> String? {
    var cursor = start
    while cursor < lineEnd {
      while cursor < lineEnd && utf8[cursor] == 0x20 { utf8.formIndex(after: &cursor) }
      guard cursor < lineEnd else { return nil }
      var tokenEnd = cursor
      var hasEquals = false
      let isFlag = utf8[cursor] == 0x2D  // '-'
      while tokenEnd < lineEnd && utf8[tokenEnd] != 0x20 {
        if utf8[tokenEnd] == 0x3D { hasEquals = true }  // '='
        utf8.formIndex(after: &tokenEnd)
      }
      if hasEquals {
        cursor = tokenEnd
        continue
      }
      if isFlag {
        let flagLen = source[cursor..<tokenEnd].utf8.count
        let isUnset = (flagLen == 2 && source[source.index(after: cursor)] == "u")
        cursor = tokenEnd
        if isUnset {
          while cursor < lineEnd && utf8[cursor] == 0x20 { utf8.formIndex(after: &cursor) }
          while cursor < lineEnd && utf8[cursor] != 0x20 { utf8.formIndex(after: &cursor) }
        }
        continue
      }
      return stripVersion(String(source[cursor..<tokenEnd]))
    }
    return nil
  }

  /// Strip trailing version: python3.11 → python3 → python, ruby2.7 → ruby2 → ruby.
  /// First strips .\d+ segments, then strips bare trailing digits only if a dot-segment was found.
  /// Protects names like d8, v8 where the digit is part of the name.
  private static func stripVersion(_ name: String) -> String {
    let utf8 = name.utf8
    guard !utf8.isEmpty else { return name }
    var end = utf8.endIndex

    // Phase 1: strip trailing .\d+ segments (e.g. .11, .7, .2)
    let strippedDots = stripDotDigitSegments(utf8: utf8, end: &end)

    // Phase 2: strip bare trailing digits only if we stripped a dot segment
    // python3.11 → python3 → python, but d8 stays d8
    if strippedDots {
      stripTrailingDigits(utf8: utf8, end: &end)
    }

    if end == utf8.endIndex { return name }
    if end <= utf8.startIndex { return name }
    return String(name[name.startIndex..<end])
  }

  /// Strip trailing .\d+ segments from end. Returns true if any were stripped.
  private static func stripDotDigitSegments(
    utf8: String.UTF8View,
    end: inout String.Index
  ) -> Bool {
    var stripped = false
    while end > utf8.startIndex {
      let digitsStart = scanBackwardPastDigits(utf8: utf8, from: end)
      if digitsStart == end { break }
      if digitsStart <= utf8.startIndex { break }
      let beforeDigits = utf8.index(before: digitsStart)
      if utf8[beforeDigits] != 0x2E { break }
      end = beforeDigits
      stripped = true
    }
    return stripped
  }

  /// Strip bare trailing digits from end (only if something non-digit remains).
  private static func stripTrailingDigits(
    utf8: String.UTF8View,
    end: inout String.Index
  ) {
    guard end > utf8.startIndex else { return }
    let digitsStart = scanBackwardPastDigits(utf8: utf8, from: end)
    if digitsStart < end && digitsStart > utf8.startIndex {
      end = digitsStart
    }
  }

  /// Scan backward from `from` past consecutive ASCII digits. Returns the position
  /// of the first non-digit (or startIndex if all digits).
  private static func scanBackwardPastDigits(
    utf8: String.UTF8View,
    from position: String.Index
  ) -> String.Index {
    var scan = position
    while scan > utf8.startIndex {
      let preceding = utf8.index(before: scan)
      guard utf8[preceding] >= 0x30 && utf8[preceding] <= 0x39 else { break }
      scan = preceding
    }
    return scan
  }
}
