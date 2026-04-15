#if canImport(Darwin)
  import Darwin
#elseif canImport(Glibc)
  import Glibc
#endif

/// Loads a Zed-style JSON theme file and produces pre-computed ANSI byte
/// sequences for each `TokenType`.
///
/// Uses `ZedThemeScanner` for zero-copy JSON parsing and maps Zed scope
/// names to `TokenType` via a translation table. The result is an array
/// indexed by `TokenType.rawValue` for O(1) lookup in the render loop.
enum ZedThemeLoader {

  /// Result of loading a theme file.
  struct LoadedTheme: Sendable {
    /// Styles indexed by `TokenType.rawValue`.
    let colorTable: [Style]

    /// Base text style for unhighlighted content.
    let baseColor: Style

    // MARK: - Editor UI colors

    /// Default editor text color (editor.foreground).
    let editorFgStyle: Style?

    /// Line number foreground color (editor.line_number).
    let lineNumberStyle: Style?

    /// Active line number foreground color (editor.active_line_number).
    let activeLineNumberStyle: Style?

    /// Gutter background color (editor.gutter.background).
    let gutterBgStyle: Style?

    /// Editor background color (editor.background).
    let editorBgStyle: Style?

    /// O(1) lookup — same speed as UtilityDarkTheme's jump table.
    func color(for tokenType: TokenType) -> Style {
      colorTable[tokenType.rawValue]
    }
  }

  /// Load a Zed theme JSON file from disk.
  ///
  /// When `variantRange` is provided, scoping is restricted to that byte
  /// range inside the file — used by the `load(name:directory:)` resolver
  /// to pick a single variant out of a multi-variant bundle like Catppuccin.
  static func load(
    from path: String,
    variantRange: (start: Int, end: Int)? = nil
  ) throws -> LoadedTheme {
    let bytes = try readFileBytes(path: path)
    return try buildTheme(from: bytes, path: path, variantRange: variantRange)
  }

  /// Load from pre-read bytes (avoids a second file read when the resolver
  /// already has them in hand).
  static func load(
    bytes: [UInt8],
    path: String,
    variantRange: (start: Int, end: Int)? = nil
  ) throws -> LoadedTheme {
    return try buildTheme(from: bytes, path: path, variantRange: variantRange)
  }

  // Name-based resolution: see `ZedThemeResolver.swift` for
  // `load(name:directory:)` and `listVariantNames(in:)`.

  // MARK: - File Reading

  static func readFileBytes(path: String) throws -> [UInt8] {
    let fileDescriptor = open(path, O_RDONLY)
    guard fileDescriptor >= 0 else {
      throw DogError.invalidTheme(path: path, detail: "could not open file")
    }
    defer { close(fileDescriptor) }

    var fileStat = stat()
    fstat(fileDescriptor, &fileStat)
    let fileSize = Int(fileStat.st_size)

    var buffer = [UInt8](repeating: 0, count: fileSize)
    let bytesRead = buffer.withUnsafeMutableBytes {
      read(fileDescriptor, $0.baseAddress, fileSize)
    }
    guard bytesRead == fileSize else {
      throw DogError.invalidTheme(
        path: path,
        detail: "incomplete read (\(bytesRead)/\(fileSize) bytes)"
      )
    }
    return buffer
  }

  // MARK: - Theme Assembly

  static func buildTheme(
    from bytes: [UInt8],
    path: String,
    variantRange: (start: Int, end: Int)? = nil
  ) throws -> LoadedTheme {
    let entries = ZedThemeScanner.scanSyntaxEntries(bytes, range: variantRange)

    guard !entries.isEmpty else {
      throw DogError.invalidTheme(
        path: path,
        detail: "no syntax entries found — is this a Zed theme file?"
      )
    }

    // Extract editor.background FIRST — every subsequent parseHex needs it
    // as the composite target for 8-char `#rrggbbaa` colors. Terminals have
    // no alpha channel, so we bake the blend in at load time.
    let editorBgRGB =
      extractEditorBackgroundRGB(from: bytes, range: variantRange)
      ?? ANSICodes.RGB(red: 0, green: 0, blue: 0)  // TODO: user-configurable fallback

    // Use the theme's "text" color for unhighlighted content
    let baseColor = extractTextColor(from: bytes, range: variantRange, background: editorBgRGB)

    // Initialize all token types to base color
    let tokenCount = TokenType.allCases.count
    var colorTable = [Style](repeating: baseColor, count: tokenCount)

    // Apply theme entries
    for entry in entries {
      guard let tokenType = resolveTokenType(from: entry.scope) else {
        Bark.debug("skipping unknown Zed scope: \(entry.scope)")
        continue
      }

      guard let style = buildStyle(from: entry, background: editorBgRGB) else {
        Bark.warning("invalid color '\(entry.color)' for scope '\(entry.scope)'")
        continue
      }

      colorTable[tokenType.rawValue] = style
      applyToChildren(of: tokenType, style: style, colorTable: &colorTable)
    }

    let editorUI = extractEditorUIStyles(
      from: bytes, range: variantRange, background: editorBgRGB
    )

    return LoadedTheme(
      colorTable: colorTable,
      baseColor: baseColor,
      editorFgStyle: editorUI.foreground,
      lineNumberStyle: editorUI.lineNumber,
      activeLineNumberStyle: editorUI.activeLineNumber,
      gutterBgStyle: editorUI.gutterBg,
      editorBgStyle: editorUI.editorBg
    )
  }

  /// Editor UI colors extracted from a theme's style block.
  /// Bundle so callers don't have to thread 5 positional args.
  private struct EditorUIStyles {
    let foreground: Style?
    let lineNumber: Style?
    let activeLineNumber: Style?
    let gutterBg: Style?
    let editorBg: Style
  }

  /// Extract all editor UI colors in one pass. Every lookup is variant-scoped
  /// and composited against `background` — so multi-variant bundles stay
  /// isolated and 8-char hex values land correctly.
  private static func extractEditorUIStyles(
    from bytes: [UInt8],
    range: (start: Int, end: Int)?,
    background: ANSICodes.RGB
  ) -> EditorUIStyles {
    return EditorUIStyles(
      foreground: extractStyleColor(
        from: bytes, key: "editor.foreground", range: range, background: background
      ),
      lineNumber: extractStyleColor(
        from: bytes, key: "editor.line_number", range: range, background: background
      ),
      activeLineNumber: extractStyleColor(
        from: bytes, key: "editor.active_line_number",
        range: range, background: background
      ),
      gutterBg: extractStyleColor(
        from: bytes, key: "editor.gutter.background",
        range: range, background: background
      ),
      editorBg: Style(
        r: background.red, g: background.green, b: background.blue
      )
    )
  }

  // MARK: - Style Construction

  private static func buildStyle(
    from entry: ZedSyntaxEntry,
    background: ANSICodes.RGB
  ) -> Style? {
    guard let rgb = ANSICodes.parseHex(entry.color, background: background) else {
      return nil
    }
    return Style(
      r: rgb.red, g: rgb.green, b: rgb.blue,
      bold: entry.fontWeight >= 700,
      italic: entry.fontStyle == "italic"
    )
  }

  /// Extract editor.background as raw RGB so it can be used as the composite
  /// target for every other color in the theme. Returns nil if absent or
  /// unparseable — caller falls back to `#000000`.
  private static func extractEditorBackgroundRGB(
    from bytes: [UInt8],
    range: (start: Int, end: Int)?
  ) -> ANSICodes.RGB? {
    guard
      let hexString = ZedThemeScanner.scanStyleValue(
        bytes, key: "editor.background", range: range
      )
    else { return nil }
    // editor.background itself may be #rrggbbaa — drop alpha, there's nothing
    // to composite against (it IS the background).
    return ANSICodes.parseHex(hexString, background: nil)
  }

  private static func extractTextColor(
    from bytes: [UInt8],
    range: (start: Int, end: Int)?,
    background: ANSICodes.RGB
  ) -> Style {
    if let hexString = ZedThemeScanner.scanTextColor(bytes, range: range),
      let rgb = ANSICodes.parseHex(hexString, background: background)
    {
      return Style(r: rgb.red, g: rgb.green, b: rgb.blue)
    }
    return Style(r: 255, g: 255, b: 255)
  }

  /// Extract a style color from a flat key in the theme's style block.
  /// 8-char hex values are composited against `background` at load time.
  private static func extractStyleColor(
    from bytes: [UInt8],
    key: String,
    range: (start: Int, end: Int)?,
    background: ANSICodes.RGB
  ) -> Style? {
    guard let hexString = ZedThemeScanner.scanStyleValue(bytes, key: key, range: range),
      let rgb = ANSICodes.parseHex(hexString, background: background)
    else { return nil }
    return Style(r: rgb.red, g: rgb.green, b: rgb.blue)
  }

  // MARK: - Scope Resolution

  /// Zed-specific scope names that differ from nvim-treesitter capture names.
  private static let zedScopeTranslation: [String: TokenType] = [
    "variable.special": .variableBuiltin,
    "link_uri": .textUri,
    "link_text": .markupLinkLabel,
    "title": .textTitle,
    "punctuation.list_marker": .markupList,
    "tag.doctype": .tagBuiltin,
    "comment.doc": .commentDocumentation,
    "enum": .type,
    "variant": .constant,
    "preproc": .keywordDirective,
    "macro": .functionMacro,
    "regex": .stringRegex,
  ]

  /// Scopes that are editor UI, not syntax — skip silently.
  private static let ignoredScopes: Set<String> = [
    "hint", "predictive", "primary",
  ]

  private static func resolveTokenType(from scope: String) -> TokenType? {
    if ignoredScopes.contains(scope) { return nil }

    if let tokenType = TokenType.from(captureName: scope) {
      return tokenType
    }

    if let tokenType = zedScopeTranslation[scope] {
      return tokenType
    }

    // Hierarchical fallback: strip last dot-segment and retry
    var name = scope
    while let dotIndex = name.lastIndex(of: ".") {
      name = String(name[name.startIndex..<dotIndex])
      if let tokenType = TokenType.from(captureName: name) {
        return tokenType
      }
      if let tokenType = zedScopeTranslation[name] {
        return tokenType
      }
    }

    return nil
  }

  /// Apply a parent's style to all child TokenTypes that inherit from it.
  private static func applyToChildren(
    of parent: TokenType,
    style: Style,
    colorTable: inout [Style]
  ) {
    guard let parentName = parent.captureName else { return }
    let prefix = parentName + "."

    for tokenType in TokenType.allCases {
      guard let childName = tokenType.captureName else { continue }
      if childName.hasPrefix(prefix) {
        colorTable[tokenType.rawValue] = style
      }
    }
  }
}
