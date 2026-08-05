#if canImport(Darwin)
  import Darwin
#elseif canImport(Glibc)
  import Glibc
#endif

/// `--woof` snippet browsing: fzf picker, previews, and direct rendering.
extension Dog {
  /// `--woof-preview <lang>`: hidden fast path for fzf's `--preview` command.
  /// Renders one snippet with forced color, no pager — fzf handles the chrome.
  func runWoofPreview(
    language: String, resolved: ResolvedThemeStyles, isPlain: Bool
  ) async throws {
    try await renderSnippet(
      language: language, resolved: resolved,
      colorEnabled: true, plain: isPlain, paging: .never
    )
  }

  /// `--woof`: browse language snippets through the current theme.
  /// With fzf + TTY: interactive picker, preview renders each language live.
  /// Without fzf or piped: render one snippet (swift or -l <lang>) to pager.
  func runWoof(
    activeTheme: String, resolved: ResolvedThemeStyles,
    colorEnabled: Bool, isPlain: Bool, paging: PagingOption
  ) async throws {
    if let woofLanguage = language {
      // -l specified: render that one language directly, no fzf
      try await renderSnippet(
        language: woofLanguage, resolved: resolved,
        colorEnabled: colorEnabled, plain: isPlain, paging: paging
      )
      return
    }
    // No -l: try fzf interactive browser, fall back to swift snippet
    let didFzf =
      TTY.isTerminal
      && Self.launchWoofFzf(theme: activeTheme, themeDir: themeDir, plain: plain)
    if !didFzf {
      try await renderSnippet(
        language: "swift", resolved: resolved,
        colorEnabled: colorEnabled, plain: isPlain, paging: paging
      )
    }
  }

  /// Render a single embedded snippet through the full PrintCommand pipeline.
  private func renderSnippet(
    language: String, resolved: ResolvedThemeStyles,
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
      colorTable: resolved.colorTable,
      baseColor: resolved.baseColor,
      lineNumberStyle: resolved.lineNumberStyle,
      gutterBgStyle: resolved.gutterBgStyle,
      editorBgStyle: resolved.editorBgStyle,
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
