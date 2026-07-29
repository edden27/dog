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
    version: "0.1.0"
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
      "Theme name or path to a theme file.",
      discussion: """
        Matches a themes[].name entry inside any *.json bundle in \
        ~/.config/dog/themes/ (or $XDG_CONFIG_HOME/dog/themes/). A value \
        containing / loads that file directly instead (~/ and ${VAR} expand; \
        a file with multiple variants uses its first variant). Zed-style JSON. \
        Colors accept #rrggbb or #rrggbbaa — if alpha is present and \
        editor.background is defined, it composites against it; otherwise the \
        raw RGB is used as a solid color.

        Built-in names: 'UtilityDark', 'UtilityBright'. Built-ins \
        are zero-cost (compiled in, no file I/O). An explicit --theme overrides \
        --light and --dark. When no theme flag is given, the saved \
        --set-default-theme choice picks the theme.
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
      "Save a theme as the default, precomputed for instant startup.",
      discussion: """
        Resolves <set-default-theme> exactly like --theme (name or path, \
        honors --theme-dir), then saves the finished style table to \
        ~/.config/dog/default-theme. Later runs load it in microseconds - \
        no theme file parsing. It applies when no --theme or --light/--dark \
        picks a theme. Set 'UtilityDark' or an empty value to clear the \
        saved default.
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
    let colorTable = resolved.colorTable
    let baseColor = resolved.baseColor
    let lineNumberStyle = resolved.lineNumberStyle
    let gutterBgStyle = resolved.gutterBgStyle
    let editorBgStyle = resolved.editorBgStyle

    // -p = no decorations, -pp = no decorations + no pager, -P = no pager
    let isPlain = plain >= 1
    let effectivePaging: PagingOption = (plain >= 2 || noPager) ? .never : paging

    // --woof-preview <lang>: hidden fast path for fzf's --preview command.
    // Renders one snippet with forced color, no pager — fzf handles the chrome.
    if let previewLang = woofPreview {
      try await Self.renderSnippet(
        language: previewLang,
        colorTable: colorTable, baseColor: baseColor,
        lineNumberStyle: lineNumberStyle,
        gutterBgStyle: gutterBgStyle,
        editorBgStyle: editorBgStyle,
        wrap: wrap, terminalWidth: terminalWidth,
        colorEnabled: true, plain: isPlain, paging: .never
      )
      return
    }

    // --woof: browse language snippets through current theme.
    // With fzf + TTY: interactive picker, preview renders each language live.
    // Without fzf or piped: render one snippet (swift or -l <lang>) to pager.
    if woof {
      if let woofLang = language {
        // -l specified: render that one language directly, no fzf
        try await Self.renderSnippet(
          language: woofLang,
          colorTable: colorTable, baseColor: baseColor,
          lineNumberStyle: lineNumberStyle,
          gutterBgStyle: gutterBgStyle,
          editorBgStyle: editorBgStyle,
          wrap: wrap, terminalWidth: terminalWidth,
          colorEnabled: colorEnabled, plain: isPlain, paging: effectivePaging
        )
      } else {
        // No -l: try fzf interactive browser, fall back to swift snippet
        let didFzf =
          TTY.isTerminal
          && Self.launchWoofFzf(
            theme: activeTheme, themeDir: themeDir, plain: plain
          )
        if !didFzf {
          try await Self.renderSnippet(
            language: "swift",
            colorTable: colorTable, baseColor: baseColor,
            lineNumberStyle: lineNumberStyle,
            gutterBgStyle: gutterBgStyle,
            editorBgStyle: editorBgStyle,
            wrap: wrap, terminalWidth: terminalWidth,
            colorEnabled: colorEnabled, plain: isPlain, paging: effectivePaging
          )
        }
      }
      return
    }

    let command = PrintCommand(
      file: file,
      language: language,
      plain: isPlain,
      colorEnabled: colorEnabled,
      paging: effectivePaging,
      wrap: wrap,
      terminalWidthOverride: terminalWidth,
      colorTable: colorTable,
      baseColor: baseColor,
      lineNumberStyle: lineNumberStyle,
      gutterBgStyle: gutterBgStyle,
      editorBgStyle: editorBgStyle
    )

    do {
      try await command.run()
    } catch {
      ErrorHandler.handle(error)
    }
  }

  // MARK: - Completion helpers

  /// Shell-completion values for `--language`: every supported language.
  private static func completeLanguages(
    _: [String], _: Int, _: String
  ) -> [String] {
    LanguageRegistry.shared.languageNames
  }

  /// Shell-completion values for `--theme`: built-ins plus every variant in
  /// the themes directory. Honors a `--theme-dir` typed earlier on the line.
  private static func completeThemes(
    _ arguments: [String], _: Int, _: String
  ) -> [String] {
    let directory = themeDirArgument(in: arguments) ?? ConfigPaths.themesDir
    var names = ["UtilityDark", "UtilityBright"]
    for (_, variants) in ZedThemeLoader.listVariantNames(in: directory) {
      names.append(contentsOf: variants)
    }
    return names
  }

  /// Find the last `--theme-dir` value among `arguments`, expanded.
  private static func themeDirArgument(in arguments: [String]) -> String? {
    var value: String?
    for (index, argument) in arguments.enumerated() {
      if argument == "--theme-dir", index + 1 < arguments.count {
        value = arguments[index + 1]
      } else if argument.hasPrefix("--theme-dir=") {
        value = String(argument.dropFirst("--theme-dir=".count))
      }
    }
    return value.map(ConfigPaths.expand)
  }

  // MARK: - Listing helpers

  /// Print supported languages from `LanguageRegistry` — not hardcoded.
  /// Mirrors the layout of `--list-themes`: heading, discussion, then
  /// one canonical name per line.
  private static func printLanguages(colorEnabled: Bool) {
    var output = ANSIOutput(enabled: colorEnabled)
    let names = LanguageRegistry.shared.languageNames

    output.color(UtilityDarkTheme.helpStyle(for: .heading))
    output.text("LANGUAGES:")
    output.reset()
    output.newline()
    output.text("  ")
    output.color(UtilityDarkTheme.helpStyle(for: .dim))
    output.text(
      "Set --language <name> with one of the languages below to force a grammar."
    )
    output.reset()
    output.newline()
    output.text("  ")
    output.color(UtilityDarkTheme.helpStyle(for: .dim))
    output.text("Auto-detected from file extension, filename, or shebang otherwise.")
    output.reset()
    output.newline()
    output.newline()

    for name in names {
      output.text("  ")
      output.color(UtilityDarkTheme.helpStyle(for: .listPrimary))
      output.text(name)
      output.reset()
      output.newline()
    }

    output.flush()
  }

  /// One entry in the theme list — built-in or discovered on disk.
  private struct ThemeEntry {
    let bundle: String
    let variants: [String]
    let note: String?
  }

  /// Print built-in + user theme bundles, grouped with a header and one
  /// variant per line. Bundles are derived from the built-in plus any
  /// *.json under `directory` — never hardcoded.
  private static func printThemes(directory: String, colorEnabled: Bool) {
    var output = ANSIOutput(enabled: colorEnabled)
    let userBundles =
      directory.isEmpty ? [] : ZedThemeLoader.listVariantNames(in: directory)

    var entries: [ThemeEntry] = [
      ThemeEntry(bundle: "UtilityDark", variants: [], note: "built-in, default"),
      ThemeEntry(bundle: "UtilityBright", variants: [], note: "built-in, --light"),
    ]
    for (bundle, variants) in userBundles {
      entries.append(ThemeEntry(bundle: bundle, variants: variants, note: nil))
    }

    writeThemesHeader(into: &output)
    for entry in entries {
      writeThemeEntry(entry, into: &output)
    }

    if userBundles.isEmpty, !directory.isEmpty {
      output.newline()
      output.text("  ")
      output.color(UtilityDarkTheme.helpStyle(for: .dim))
      output.text("(no user themes in \(directory))")
      output.reset()
      output.newline()
    }

    output.flush()
  }

  private static func writeThemesHeader(into output: inout ANSIOutput) {
    output.color(UtilityDarkTheme.helpStyle(for: .heading))
    output.text("THEMES:")
    output.reset()
    output.newline()
    output.text("  ")
    output.color(UtilityDarkTheme.helpStyle(for: .dim))
    output.text(
      "Set --theme <name> with one of the themes below to use any of your themes."
    )
    output.reset()
    output.newline()
    output.text("  ")
    output.color(UtilityDarkTheme.helpStyle(for: .dim))
    output.text("See --help for theme-dir info.")
    output.reset()
    output.newline()
  }

  private static func writeThemeEntry(_ entry: ThemeEntry, into output: inout ANSIOutput) {
    output.newline()
    output.text("  ")
    output.color(UtilityDarkTheme.helpStyle(for: .listPrimary))
    output.text(entry.bundle)
    output.reset()
    if let note = entry.note {
      output.text("  ")
      output.color(UtilityDarkTheme.helpStyle(for: .dim))
      output.text("(\(note))")
      output.reset()
    }
    output.newline()
    for variant in entry.variants {
      output.text("    ")
      output.color(UtilityDarkTheme.helpStyle(for: .listSecondary))
      output.text("'\(variant)'")
      output.reset()
      output.newline()
    }
  }

  // MARK: - Woof helpers

  /// Render a single embedded snippet through the full PrintCommand pipeline.
  private static func renderSnippet(
    language: String,
    colorTable: [Style], baseColor: Style,
    lineNumberStyle: Style?, gutterBgStyle: Style?, editorBgStyle: Style?,
    wrap: WrapOption, terminalWidth: Int?,
    colorEnabled: Bool, plain: Bool, paging: PagingOption
  ) async throws {
    let available = EmbeddedWoofSnippets.all.map(\.language)
    guard let entry = EmbeddedWoofSnippets.all.first(where: { $0.language == language }) else {
      let suggestion = available.first { $0.hasPrefix(language.prefix(3)) }
      ErrorHandler.handle(
        DogError.unknownLanguage(name: language, suggestion: suggestion)
      )
    }

    let command = PrintCommand(
      file: nil,
      language: language,
      plain: plain,
      colorEnabled: colorEnabled,
      paging: paging,
      wrap: wrap,
      terminalWidthOverride: terminalWidth,
      colorTable: colorTable,
      baseColor: baseColor,
      lineNumberStyle: lineNumberStyle,
      gutterBgStyle: gutterBgStyle,
      editorBgStyle: editorBgStyle,
      sourceOverride: entry.bytes
    )

    do {
      try await command.run()
    } catch {
      ErrorHandler.handle(error)
    }
  }

  /// Single-quote a value for embedding in a shell command line.
  ///
  /// UTF-8 byte walk, stdlib only — Foundation's replacingOccurrences breaks
  /// the bare-Linux release build. Byte 39 (') never appears inside a
  /// multi-byte UTF-8 sequence, so byte comparison is safe.
  private static func shellQuoted(_ value: String) -> String {
    var bytes: [UInt8] = []
    bytes.reserveCapacity(value.utf8.count + 2)
    bytes.append(39)  // '
    for byte in value.utf8 {
      if byte == 39 {
        // Close the quote, emit an escaped quote, reopen: ' → '\''
        bytes.append(contentsOf: [39, 92, 39, 39])
      } else {
        bytes.append(byte)
      }
    }
    bytes.append(39)
    return String(decoding: bytes, as: UTF8.self)
  }

  /// Launch fzf with the list of available woof languages.
  /// Preview pane calls `dog --woof-preview <lang>` with the current theme.
  /// Uses `posix_spawnp` + pipe — same pattern as `Pager.swift`.
  /// Returns false if fzf isn't available or fails to spawn.
  @discardableResult
  private static func launchWoofFzf(
    theme: String, themeDir: String?, plain: Int
  ) -> Bool {
    // Build the preview command string for fzf's --preview flag.
    // {} is replaced by fzf with the selected language name.
    var preview = "dog --woof-preview {} --color=always"
    if theme != "UtilityDark" {
      preview += " --theme \(shellQuoted(theme))"
    }
    if let dir = themeDir {
      preview += " --theme-dir \(shellQuoted(dir))"
    }
    if plain >= 1 { preview += " -p" }

    // Pipe: we write language list to fzf's stdin
    var pipefd: [Int32] = [0, 0]
    guard pipe(&pipefd) == 0 else { return false }

    #if canImport(Darwin)
      var fileActions: posix_spawn_file_actions_t?
    #else
      var fileActions = posix_spawn_file_actions_t()
    #endif
    posix_spawn_file_actions_init(&fileActions)
    posix_spawn_file_actions_adddup2(&fileActions, pipefd[0], STDIN_FILENO)
    posix_spawn_file_actions_addclose(&fileActions, pipefd[1])
    // Discard fzf's selection output — user already saw the preview
    let devnull = open("/dev/null", O_WRONLY)
    if devnull >= 0 {
      posix_spawn_file_actions_adddup2(&fileActions, devnull, STDOUT_FILENO)
    }

    let argv: [UnsafeMutablePointer<CChar>?] = [
      strdup("fzf"),
      strdup("--ansi"),
      strdup("--preview"), strdup(preview),
      strdup("--preview-window"), strdup("right:70%"),
      strdup("--header"), strdup("woof! browse snippets with your current theme"),
      nil,
    ]
    defer { for arg in argv { free(arg) } }

    var pid: pid_t = 0
    let status = posix_spawnp(&pid, "fzf", &fileActions, nil, argv, environ)
    posix_spawn_file_actions_destroy(&fileActions)

    guard status == 0 else {
      close(pipefd[0])
      close(pipefd[1])
      return false
    }

    // Close read end in parent — only fzf uses it
    close(pipefd[0])
    if devnull >= 0 { close(devnull) }

    // Write language list to fzf's stdin
    let languages = EmbeddedWoofSnippets.all.map(\.language)
    let input = languages.joined(separator: "\n")
    input.withCString { cstr in
      _ = write(pipefd[1], cstr, strlen(cstr))
    }

    // Close write end — signals EOF to fzf
    close(pipefd[1])

    // Wait for fzf to exit
    var exitStatus: Int32 = 0
    waitpid(pid, &exitStatus, 0)

    return true
  }
}
