/// Shell-completion providers for `--language` and `--theme`.
extension Dog {
  /// Shell-completion values for `--language`: every supported language.
  static func completeLanguages(
    _: [String], _: Int, _: String
  ) -> [String] {
    LanguageRegistry.shared.languageNames
  }

  /// Shell-completion values for `--theme`: built-ins plus every variant in
  /// the themes directory. Honors a `--theme-dir` typed earlier on the line.
  static func completeThemes(
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
}
