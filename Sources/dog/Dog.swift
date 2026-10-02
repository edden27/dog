import ArgumentParser

#if canImport(Darwin)
  import Darwin
#elseif canImport(Glibc)
  import Glibc
#endif

// dog 🐕 — syntax highlighting powered by tree-sitter
// "get out the cave, ditch the litter box"

/// Color output mode for `--color` flag.
enum ColorOption: String, ExpressibleByArgument, CaseIterable {
  case auto
  case always
  case never
}

/// Pager mode for `--paging` flag.
enum PagingOption: String, ExpressibleByArgument, CaseIterable {
  case auto
  case always
  case never
}

/// Line-wrap mode for `--wrap` flag.
/// `auto` wraps when stdout is a TTY; `never` disables wrapping entirely.
enum WrapOption: String, ExpressibleByArgument, CaseIterable {
  case auto
  case never
}

@main
struct Dog: AsyncParsableCommand {
  /// Custom entry point: intercept `--help`/`-h` to emit a colorized help
  /// message, otherwise fall through to ArgumentParser's normal dispatch.
  static func main() async {
    let args = CommandLine.arguments.dropFirst()
    if args.contains("--help") || args.contains("-h") {
      let plain = Self.helpMessage()
      let enabled = TTY.resolveColorEnabled(flag: .auto)
      let bytes: [UInt8] = enabled ? HelpFormatter.colorize(plain) : Array(plain.utf8)
      var out = ANSIOutput(enabled: true, estimatedSize: bytes.count + 1)
      out.text(bytes)
      out.newline()
      out.flush()
      return
    }
    do {
      var command = try parseAsRoot()
      if var dog = command as? Dog {
        try await dog.run()
      } else {
        try command.run()
      }
    } catch {
      // DogError gets dog's own formatting + exit code; everything else
      // (ValidationError, parse errors) keeps ArgumentParser's usage output.
      if let dogError = error as? DogError {
        ErrorHandler.handle(dogError)
      }
      exit(withError: error)
    }
  }

  static let configuration = CommandConfiguration(
    commandName: "dog",
    abstract: "Syntax highlighting powered by tree-sitter.",
    usage: """
      dog <FILE>
      dog [OPTIONS] [FILE]
      echo CODE | dog -l LANGUAGE
      """,
    discussion: "get out the cave, ditch the litter box",
    version: "0.1.1"
  )

  // MARK: - Arguments

  @Argument(help: "File to display.", completion: .file())
  var file: String?

  // MARK: - Options

  @Option(
    name: .shortAndLong, help: "Set the language.",
    completion: .custom(completeLanguages)
  )
  var language: String?

  @Option(help: "When to use colors.")
  var color: ColorOption = .auto

  @Option(
    name: [.customShort("t"), .long],
    help: ArgumentHelp(
      "Theme name or path, or both with ':' - example: 'file-name:theme name'.",
      discussion: """
        A plain name searches ~/.config/dog/themes/. Helps to specify the \
        theme when a single JSON file contains multiple variants. Examples:
          --theme 'Nord Dark'
          --theme Catppuccin.json
          --theme 'Catppuccin:Catppuccin Mocha'
          --theme '~/.config/zed/themes/Catppuccin.json:Catppuccin Mocha'

        Zed-theme style JSON. Colors accept #rrggbb or #rrggbbaa — if alpha \
        is present and editor.background is defined, it composites against \
        it; otherwise the raw RGB is used as a solid color.

        Built-ins: 'UtilityDark', 'UtilityBright'. Built-ins are zero-cost \
        (compiled in, no file I/O). An explicit --theme overrides --light \
        and --dark. See --set-default-theme to set a custom default theme \
        choice.
        """
    ),
    completion: .custom(completeThemes)
  )
  var theme: String?

  @Option(
    name: .long,
    help: ArgumentHelp(
      "Directory path to search for theme JSON files.",
      discussion: """
        Overrides the default ~/.config/dog/themes/ (or $XDG_CONFIG_HOME/dog/themes/).
        Useful for pointing at an existing editor's theme dir.

        Examples:
          --theme-dir '~/.config/zed/themes'
          --theme-dir '${HOME}/.config/zed/themes'
          --theme-dir '/absolute/path/to/themes'

        Supports leading ~/ expansion and ${VAR} environment variable \
        substitution (e.g. ${HOME}, ${XDG_CONFIG_HOME}). Quote paths that \
        contain spaces or special characters.
        """
    ),
    completion: .directory
  )
  var themeDir: String?

  @Option(
    name: .long,
    help: ArgumentHelp(
      "Save a theme as the default for instant startup.",
      discussion: """
        Removes the need to pass --theme (name or path, honors --theme-dir). \
        Saves the theme table to ~/.config/dog/default-theme. Loads in \
        microseconds - no theme file parsing. It applies when no --theme or \
        --light/--dark is given. Set 'UtilityDark' or empty '' to clear and \
        restore the built-in 'UtilityDark' default.
        """
    ),
    completion: .custom(completeThemes)
  )
  var setDefaultTheme: String?

  @Option(name: .long, help: "When to use the pager (auto, always, never).")
  var paging: PagingOption = .auto

  @Flag(name: [.customShort("P"), .long], help: "Disable the pager.")
  var noPager = false

  @Option(name: .shortAndLong, help: "Line range to display (not yet implemented).")
  var range: String?

  @Option(name: [.customShort("w"), .long], help: "Line wrap mode (auto, never).")
  var wrap: WrapOption = .auto

  @Option(name: .long, help: "Override terminal width (columns).")
  var terminalWidth: Int?

  // MARK: - Flags

  @Flag(name: .shortAndLong, help: "No decorations. Use twice (-pp) to also disable pager.")
  var plain: Int

  @Flag(inversion: .prefixedNo, help: "Show line numbers (not yet implemented).")
  var lineNumbers = true

  @Flag(inversion: .prefixedNo, help: "Show filename header (not yet implemented).")
  var header = true

  @Flag(name: [.customShort("L"), .long], help: "List supported languages.")
  var listLanguages = false

  @Flag(name: [.customShort("T"), .long], help: "List available themes.")
  var listThemes = false

  @Flag(
    name: .long,
    help: ArgumentHelp(
      "Use the built-in UtilityBright light theme.",
      discussion: """
        Shortcut for --theme UtilityBright. Overridden by an explicit --theme. \
        Mutually exclusive with --dark.
        """
    )
  )
  var light = false

  @Flag(
    name: .long,
    help: ArgumentHelp(
      "Use the built-in UtilityDark theme (default).",
      discussion: """
        Shortcut for --theme UtilityDark. Overridden by an explicit --theme. \
        Mutually exclusive with --light.
        """
    )
  )
  var dark = false

  @Flag(help: "Take dog out for a walk.")
  var woof = false

  @Option(
    name: .long,
    help: .hidden
  )
  var woofPreview: String?

  // MARK: - Run

  mutating func run() async throws {
    ErrorHandler.installSignalHandlers()

    let colorEnabled = TTY.resolveColorEnabled(flag: color)

    // Resolve themes directory: --theme-dir flag > config.toml > XDG default.
    // FIXME: config.toml `theme_dir` precedence slot — wire once config loader lands.
    let resolvedThemesDir: String = {
      if let flag = themeDir { return ConfigPaths.expand(flag) }
      return ConfigPaths.themesDir
    }()

    if listLanguages {
      Self.printLanguages(colorEnabled: colorEnabled)
      return
    }

    if listThemes {
      Self.printThemes(directory: resolvedThemesDir, colorEnabled: colorEnabled)
      return
    }

    if let setDefaultTheme {
      try Self.saveDefaultTheme(setDefaultTheme, themesDirectory: resolvedThemesDir)
      return
    }

    if let range {
      // v2 stub
      Bark.warning("--range is not yet implemented (got: \(range))")
    }

    if light && dark {
      throw ValidationError("--light and --dark are mutually exclusive")
    }
    let (activeTheme, resolved) = try Self.resolveActiveTheme(
      explicitTheme: theme, light: light, dark: dark,
      themesDirectory: resolvedThemesDir
    )

    // -p = no decorations, -pp = no decorations + no pager, -P = no pager
    let isPlain = plain >= 1
    let effectivePaging: PagingOption = (plain >= 2 || noPager) ? .never : paging

    if let previewLanguage = woofPreview {
      try await runWoofPreview(
        language: previewLanguage, resolved: resolved, isPlain: isPlain
      )
      return
    }

    if woof {
      try await runWoof(
        activeTheme: activeTheme, resolved: resolved,
        colorEnabled: colorEnabled, isPlain: isPlain, paging: effectivePaging
      )
      return
    }

    await runPrint(
      resolved: resolved, colorEnabled: colorEnabled,
      isPlain: isPlain, paging: effectivePaging
    )
  }

  /// Default mode: highlight the file (or stdin) and print it.
  private func runPrint(
    resolved: ResolvedThemeStyles, colorEnabled: Bool,
    isPlain: Bool, paging: PagingOption
  ) async {
    let command = PrintCommand(
      file: file,
      language: language,
      plain: isPlain,
      colorEnabled: colorEnabled,
      paging: paging,
      wrap: wrap,
      terminalWidthOverride: terminalWidth,
      colorTable: resolved.colorTable,
      baseColor: resolved.baseColor,
      lineNumberStyle: resolved.lineNumberStyle,
      gutterBgStyle: resolved.gutterBgStyle,
      editorBgStyle: resolved.editorBgStyle
    )

    do {
      try await command.run()
    } catch {
      ErrorHandler.handle(error)
    }
  }

}
