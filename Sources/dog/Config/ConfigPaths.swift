#if canImport(Darwin)
  import Darwin
#elseif canImport(Glibc)
  import Glibc
#endif

/// Resolves XDG-style config paths for dog.
///
/// Honors the XDG Base Directory spec:
/// - `$XDG_CONFIG_HOME/dog/...` when the env var is set and absolute.
/// - `$HOME/.config/dog/...` otherwise.
///
/// All paths are computed lazily once per process. No Foundation.
enum ConfigPaths {

  /// `$XDG_CONFIG_HOME/dog` or `$HOME/.config/dog`. Empty string if HOME is unset.
  static let configDir: String = {
    if let xdg = envString("XDG_CONFIG_HOME"), !xdg.isEmpty, xdg.hasPrefix("/") {
      return "\(xdg)/dog"
    }
    guard let home = envString("HOME"), !home.isEmpty else { return "" }
    return "\(home)/.config/dog"
  }()

  /// `<configDir>/themes`. Empty string if `configDir` is empty.
  static let themesDir: String = {
    let base = configDir
    return base.isEmpty ? "" : "\(base)/themes"
  }()

  // TODO: wire config.toml loading here once Config/ConfigFile.swift lands.
  // Placeholder: `<configDir>/config.toml`.

  /// Expand a user-provided path string. Handles:
  ///   - Leading `~/` → `$HOME/`
  ///   - `${VAR}` env var substitution anywhere in the string
  ///
  /// Returns the input unchanged if `$HOME` is unset or a referenced var
  /// is unset (substitutes empty string for missing vars — matches shell
  /// behavior). No Foundation.
  static func expand(_ path: String) -> String {
    var result = path

    // 1. Leading ~/  →  $HOME/
    if result.hasPrefix("~/"), let home = envString("HOME"), !home.isEmpty {
      result = home + String(result.dropFirst(1))
    } else if result == "~", let home = envString("HOME"), !home.isEmpty {
      result = home
    }

    // 2. ${VAR} substitution
    guard result.contains("${") else { return result }

    var output = ""
    output.reserveCapacity(result.count)
    var index = result.startIndex
    while index < result.endIndex {
      let character = result[index]
      if character == "$",
        result.index(after: index) < result.endIndex,
        result[result.index(after: index)] == "{"
      {
        // Find closing brace
        let varStart = result.index(index, offsetBy: 2)
        if let closeIndex = result[varStart...].firstIndex(of: "}") {
          let varName = String(result[varStart..<closeIndex])
          if let value = envString(varName) {
            output += value
          }
          // Missing var → substitute empty (shell-like)
          index = result.index(after: closeIndex)
          continue
        }
      }
      output.append(character)
      index = result.index(after: index)
    }
    return output
  }

  // MARK: - Helpers

  /// Read an environment variable into a Swift String without Foundation.
  private static func envString(_ name: String) -> String? {
    guard let cStringPointer = getenv(name) else { return nil }
    return String(cString: cStringPointer)
  }
}
