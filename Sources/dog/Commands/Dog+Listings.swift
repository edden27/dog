/// `--list-languages` and `--list-themes` output.
extension Dog {
  /// Print supported languages from `LanguageRegistry` — not hardcoded.
  /// Mirrors the layout of `--list-themes`: heading, discussion, then
  /// one canonical name per line.
  static func printLanguages(colorEnabled: Bool) {
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
  static func printThemes(directory: String, colorEnabled: Bool) {
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
}
