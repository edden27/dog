#if canImport(Darwin)
  import Darwin
#elseif canImport(Glibc)
  import Glibc
#endif

/// Detects terminal capabilities and resolves whether color output is enabled.
///
/// Checks `isatty()`, `$TERM`, `NO_COLOR`, `FORCE_COLOR` env vars,
/// and the `--color` CLI flag. No Rainbow dependency.
enum TTY {
  /// Whether stdout is connected to an interactive terminal.
  static let isTerminal: Bool = {
    guard isatty(STDOUT_FILENO) != 0 else { return false }
    guard let term = getenv("TERM") else { return true }
    return String(cString: term).lowercased() != "dumb"
  }()

  /// Whether stderr is connected to an interactive terminal.
  ///
  /// Plain isatty, no TERM check — stderr diagnostics stay colored on
  /// dumb terminals; only stdout rendering degrades.
  static let stderrIsTerminal: Bool = isatty(STDERR_FILENO) != 0

  /// Resolve whether color output should be enabled.
  /// - Parameter colorFlag: The `--color` flag value from CLI args.
  /// - Returns: `true` if ANSI color codes should be emitted.
  static func resolveColorEnabled(flag colorFlag: ColorOption) -> Bool {
    switch colorFlag {
    case .always:
      return true
    case .never:
      return false
    case .auto:
      return resolveAuto()
    }
  }

  // MARK: - Private

  private static func resolveAuto() -> Bool {
    // FORCE_COLOR wins over NO_COLOR (industry convention)
    if let force = getenv("FORCE_COLOR") {
      let val = String(cString: force)
      if !val.isEmpty, val != "0" { return true }
    }
    if let noColor = getenv("NO_COLOR") {
      let val = String(cString: noColor)
      if !val.isEmpty, val != "0" { return false }
    }

    return isTerminal
  }
}
