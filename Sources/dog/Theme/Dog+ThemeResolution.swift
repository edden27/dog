/// Theme selection and resolution for the `dog` entry point: which theme
/// is in effect (flags, then DOG_THEME, then the built-in default) and
/// how its name or file path becomes rendering styles.
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
  /// distinguishable from an absent flag (nil). DOG_THEME fills in only
  /// when no theme flag was typed at all — --dark is the escape hatch
  /// back to the built-in when the environment sets a theme.
  ///
  /// A broken DOG_THEME degrades to the default theme with a warning —
  /// a bad --theme still errors. The environment should never make dog
  /// unable to render.
  static func resolveActiveTheme(
    explicitTheme: String?, light: Bool, dark: Bool, themesDirectory: String
  ) throws -> (name: String, styles: ResolvedThemeStyles) {
    let environmentTheme: String? = {
      guard let value = ConfigPaths.envString("DOG_THEME"), !value.isEmpty else {
        return nil
      }
      return value
    }()
    let effectiveTheme: String = {
      if let explicitTheme { return explicitTheme }
      if light { return "UtilityBright" }
      if dark { return "UtilityDark" }
      if let environmentTheme { return environmentTheme }
      return "UtilityDark"
    }()
    let themeCameFromEnvironment =
      explicitTheme == nil && !light && !dark && environmentTheme != nil

    do {
      let styles = try resolveThemeStyles(
        themeName: effectiveTheme, directory: themesDirectory
      )
      return (effectiveTheme, styles)
    } catch  where themeCameFromEnvironment {
      Bark.releaseWarning(
        "DOG_THEME '\(effectiveTheme)' could not be loaded - using the default theme"
      )
      let styles = try resolveThemeStyles(
        themeName: "UtilityDark", directory: themesDirectory
      )
      return ("UtilityDark", styles)
    }
  }

  /// Resolve `themeName` into rendering styles. Built-in `UtilityDark` is
  /// zero-cost (pre-baked). A `file:variant` value (split at the LAST
  /// colon, and only when the file part names a real theme file — bundle
  /// filename in `directory`, `.json` optional, or a full path) addresses
  /// one variant directly with no directory search. A value containing
  /// `/` (after `~`/`${VAR}` expansion) loads as a direct path to a theme
  /// JSON file. Any other name goes through `ZedThemeLoader`'s
  /// progressive-prefix cascade against `directory`.
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
    if let fileVariant = fileVariantSplit(themeName, directory: directory) {
      loaded = try loadFileVariant(
        path: fileVariant.path, variantName: fileVariant.variantName
      )
    } else if expandedPath.contains("/") {
      // A path always means the file's FIRST variant — scoping to its byte
      // range keeps a multi-variant bundle from bleeding later variants'
      // rules into the result. No range found (not a bundle) falls back to
      // scanning the whole file.
      let bytes = try ZedThemeLoader.readFileBytes(path: expandedPath)
      let firstVariantRange = ZedThemeVariantWalker.findVariantRange(bytes, target: nil)
      loaded = try ZedThemeLoader.load(
        bytes: bytes, path: expandedPath, variantRange: firstVariantRange
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
