/// Theme selection and resolution for the `dog` entry point: which theme
/// is in effect (flags, then the saved default, then the built-in default)
/// and how its name or file path becomes rendering styles.
extension Dog {

  /// Resolved styles for rendering — bundles the subset of `LoadedTheme`
  /// fields that `PrintCommand` actually consumes.
  struct ResolvedThemeStyles {
    let colorTable: [Style]
    let baseColor: Style
    let lineNumberStyle: Style?
    let gutterBgStyle: Style?
    let editorBgStyle: Style?
  }

  /// Pick the theme in effect and resolve it into rendering styles.
  ///
  /// Explicit --theme always wins, including `--theme UtilityDark` over
  /// --light. The option carries no parser default so a typed value is
  /// distinguishable from an absent flag (nil). When no theme flag was
  /// typed at all, a saved `--set-default-theme` artifact fills in before
  /// the built-in default — --dark is the escape hatch back to the
  /// built-in when a saved default is set.
  ///
  /// A bad --theme errors. An unreadable artifact degrades to the default
  /// theme with a warning — a stale saved file should never make dog
  /// unable to render.
  static func resolveActiveTheme(
    explicitTheme: String?, light: Bool, dark: Bool, themesDirectory: String
  ) throws -> (name: String, styles: ResolvedThemeStyles) {
    let pickedTheme: String? = {
      if let explicitTheme { return explicitTheme }
      if light { return "UtilityBright" }
      if dark { return "UtilityDark" }
      return nil
    }()
    guard let effectiveTheme = pickedTheme else {
      switch DefaultThemeArtifact.load() {
      case .loaded(let name, let styles):
        return (name, styles)
      case .unreadable:
        Bark.releaseWarning(
          "the saved default theme could not be loaded - run --set-default-theme "
            + "again - using the default theme"
        )
      case .none:
        break
      }
      let styles = try resolveThemeStyles(
        themeName: "UtilityDark", directory: themesDirectory
      )
      return ("UtilityDark", styles)
    }
    let styles = try resolveThemeStyles(
      themeName: effectiveTheme, directory: themesDirectory
    )
    return (effectiveTheme, styles)
  }

  /// Handle `--set-default-theme <value>`: resolve the value exactly like
  /// --theme (a bad value errors the same way), save the finished style
  /// table as the default-theme artifact, and confirm on stdout.
  ///
  /// An empty value clears the saved default. So does `UtilityDark` — it
  /// IS the built-in default, and clearing keeps its zero-cost compiled-in
  /// path instead of writing an artifact that would only slow it down.
  static func saveDefaultTheme(_ value: String, themesDirectory: String) throws {
    if value.isEmpty || value == "UtilityDark" {
      try DefaultThemeArtifact.remove()
      print("default theme reset to built-in 'UtilityDark'")
      return
    }
    let (resolvedName, resolvedStyles) = try resolveActiveTheme(
      explicitTheme: value, light: false, dark: false,
      themesDirectory: themesDirectory
    )
    let displayName = normalizedDisplayName(
      for: resolvedName, directory: themesDirectory
    )
    try DefaultThemeArtifact.save(styles: resolvedStyles, themeName: displayName)
    print("default theme set to '\(displayName)'")
  }

  /// Canonical `file:variant` display form of a theme value, shown by the
  /// --set-default-theme confirmation and stored in the artifact (--woof
  /// reads it back as the active theme name): the bundle filename (no
  /// directory, no .json) plus the variant name that was picked. Built-in
  /// names have no file and stay bare. Only runs on the set command —
  /// renders never pay for the directory listing.
  private static func normalizedDisplayName(
    for value: String, directory: String
  ) -> String {
    if value == "UtilityBright" { return value }
    if let fileVariant = fileVariantSplit(value, directory: directory) {
      return normalizedFileVariant(
        path: fileVariant.path, variantName: fileVariant.variantName
      )
    }
    let expandedPath = ConfigPaths.expand(value)
    if expandedPath.contains("/") {
      return normalizedFileVariant(path: expandedPath, variantName: "")
    }
    if let bundlePath = bundleFilePath(expandedPath, directory: directory) {
      return normalizedFileVariant(path: bundlePath, variantName: "")
    }
    // Plain name — mirror the resolver's preference: the value as a bundle
    // filename first (exact variant inside it, else its first variant),
    // then the first bundle containing the value as a variant name.
    let listing = ZedThemeLoader.listVariantNames(in: directory)
    for (bundle, variants) in listing where bundle == value {
      if variants.contains(value) { return "\(bundle):\(value)" }
      if let firstVariant = variants.first { return "\(bundle):\(firstVariant)" }
    }
    for (bundle, variants) in listing where variants.contains(value) {
      return "\(bundle):\(value)"
    }
    return value
  }

  /// `bundle:variant` for a resolved theme file path. An empty variant name
  /// means the file's first variant — the same rule the loader applies.
  private static func normalizedFileVariant(
    path: String, variantName: String
  ) -> String {
    let filename = path.split(separator: "/").last.map(String.init) ?? path
    let bundle =
      filename.hasSuffix(".json") ? String(filename.dropLast(5)) : filename
    if !variantName.isEmpty { return "\(bundle):\(variantName)" }
    if let bytes = try? ZedThemeLoader.readFileBytes(path: path),
      let firstVariant = ZedThemeVariantWalker.listVariantNames(bytes).first
    {
      return "\(bundle):\(firstVariant)"
    }
    return bundle
  }

  /// Resolve `themeName` into rendering styles. Built-in `UtilityDark` is
  /// zero-cost (pre-baked). A `file:variant` value (split at the LAST
  /// colon, and only when the file part names a real theme file — bundle
  /// filename in `directory`, `.json` optional, or a full path) addresses
  /// one variant directly with no directory search. A value containing
  /// `/` (after `~`/`${VAR}` expansion) loads as a direct path to a theme
  /// JSON file, and a bare `<filename>.json` that exists in `directory`
  /// loads that file the same way. Any other name goes through
  /// `ZedThemeLoader`'s progressive-prefix cascade against `directory`.
  private static func resolveThemeStyles(
    themeName: String, directory: String
  ) throws -> ResolvedThemeStyles {
    if themeName == "UtilityDark" {
      return ResolvedThemeStyles(
        colorTable: TokenType.allCases.map { UtilityDarkTheme.color(for: $0) },
        baseColor: UtilityDarkTheme.baseColor,
        lineNumberStyle: UtilityDarkTheme.lineNumberStyle,
        gutterBgStyle: UtilityDarkTheme.gutterBgStyle,
        editorBgStyle: UtilityDarkTheme.editorBgStyle
      )
    }
    if themeName == "UtilityBright" {
      return ResolvedThemeStyles(
        colorTable: TokenType.allCases.map { UtilityBrightTheme.color(for: $0) },
        baseColor: UtilityBrightTheme.baseColor,
        lineNumberStyle: UtilityBrightTheme.lineNumberStyle,
        gutterBgStyle: UtilityBrightTheme.gutterBgStyle,
        editorBgStyle: UtilityBrightTheme.editorBgStyle
      )
    }
    let loaded: ZedThemeLoader.LoadedTheme
    let expandedPath = ConfigPaths.expand(themeName)
    let directFilePath: String? =
      expandedPath.contains("/")
      ? expandedPath
      : bundleFilePath(expandedPath, directory: directory)
    if let fileVariant = fileVariantSplit(themeName, directory: directory) {
      loaded = try loadFileVariant(
        path: fileVariant.path, variantName: fileVariant.variantName
      )
    } else if let directFilePath {
      // A path or bare `<filename>.json` always means the file's FIRST
      // variant — scoping to its byte range keeps a multi-variant bundle
      // from bleeding later variants' rules into the result. No range found
      // (not a bundle) falls back to scanning the whole file.
      let bytes = try ZedThemeLoader.readFileBytes(path: directFilePath)
      let firstVariantRange = ZedThemeVariantWalker.findVariantRange(bytes, target: nil)
      loaded = try ZedThemeLoader.load(
        bytes: bytes, path: directFilePath, variantRange: firstVariantRange
      )
    } else {
      loaded = try ZedThemeLoader.load(name: themeName, directory: directory)
    }
    return ResolvedThemeStyles(
      colorTable: Array(loaded.colorTable),
      baseColor: loaded.baseColor,
      lineNumberStyle: loaded.lineNumberStyle,
      gutterBgStyle: loaded.gutterBgStyle,
      editorBgStyle: loaded.editorBgStyle
    )
  }

  /// Resolve a bare `<filename>.json` value to a path inside `directory`
  /// when that file exists — the no-colon sibling of `fileVariantSplit`'s
  /// file-part rule. Nil otherwise, so any other value keeps resolving as
  /// a theme name.
  private static func bundleFilePath(
    _ value: String, directory: String
  ) -> String? {
    guard value.hasSuffix(".json") else { return nil }
    let candidatePath = "\(directory)/\(value)"
    guard ZedThemeDirectoryScanner.fileExists(candidatePath) else { return nil }
    return candidatePath
  }

  /// Split a `file:variant` theme value at its LAST colon. Returns the
  /// resolved file path and variant name only when the file part names an
  /// existing theme file — bundle filename in `directory` (`.json`
  /// optional) or a full path. Returns nil otherwise, so a plain theme
  /// name that happens to contain a colon keeps resolving as a name.
  private static func fileVariantSplit(
    _ themeName: String, directory: String
  ) -> (path: String, variantName: String)? {
    guard let colonIndex = themeName.lastIndex(of: ":") else { return nil }
    let filePart = String(themeName[..<colonIndex])
    let variantName = String(themeName[themeName.index(after: colonIndex)...])
    guard !filePart.isEmpty else { return nil }

    let expanded = ConfigPaths.expand(filePart)
    let candidatePath: String
    if expanded.contains("/") {
      candidatePath = expanded
    } else if expanded.hasSuffix(".json") {
      candidatePath = "\(directory)/\(expanded)"
    } else {
      candidatePath = "\(directory)/\(expanded).json"
    }
    guard ZedThemeDirectoryScanner.fileExists(candidatePath) else { return nil }
    return (candidatePath, variantName)
  }

  /// Load one variant addressed as `file:variant` — a direct read with no
  /// directory search. An empty variant name means the file's first
  /// variant, same as the bare path form. A variant name the file doesn't
  /// contain throws with the file's actual variant names as suggestions.
  private static func loadFileVariant(
    path: String, variantName: String
  ) throws -> ZedThemeLoader.LoadedTheme {
    let bytes = try ZedThemeLoader.readFileBytes(path: path)
    if variantName.isEmpty {
      let firstVariantRange = ZedThemeVariantWalker.findVariantRange(
        bytes, target: nil
      )
      return try ZedThemeLoader.load(
        bytes: bytes, path: path, variantRange: firstVariantRange
      )
    }
    guard
      let variantRange = ZedThemeVariantWalker.findVariantRange(
        bytes, target: Array(variantName.utf8)
      )
    else {
      throw DogError.themeNotFound(
        name: variantName,
        searchedDir: path,
        available: ZedThemeVariantWalker.listVariantNames(bytes)
      )
    }
    return try ZedThemeLoader.load(
      bytes: bytes, path: path, variantRange: variantRange
    )
  }
}
