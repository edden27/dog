#if canImport(Darwin)
  import Darwin
#elseif canImport(Glibc)
  import Glibc
#endif
import Testing

@testable import dog

/// Tests for `ConfigPaths` — XDG base-directory cascade and path expansion.
///
/// Env-var tests set values via `setenv(3)` and restore the prior value on
/// exit so test ordering stays deterministic under parallel execution.
@Suite("Config Paths")
struct ConfigPathsTests {

  // MARK: - expand(_:)

  @Test("expand leaves absolute paths unchanged")
  func expandAbsoluteUnchanged() {
    #expect(ConfigPaths.expand("/usr/local/bin") == "/usr/local/bin")
    #expect(ConfigPaths.expand("/absolute/path/to/themes") == "/absolute/path/to/themes")
  }

  @Test("expand resolves leading ~/ against $HOME")
  func expandTildeSlash() {
    withEnv("HOME", value: "/Users/test") {
      #expect(ConfigPaths.expand("~/foo") == "/Users/test/foo")
      #expect(ConfigPaths.expand("~/foo/bar") == "/Users/test/foo/bar")
    }
  }

  @Test("expand bare ~ returns $HOME")
  func expandBareTilde() {
    withEnv("HOME", value: "/Users/test") {
      #expect(ConfigPaths.expand("~") == "/Users/test")
    }
  }

  @Test("expand substitutes ${HOME}")
  func expandDollarBraceHome() {
    withEnv("HOME", value: "/Users/test") {
      #expect(ConfigPaths.expand("${HOME}/themes") == "/Users/test/themes")
    }
  }

  @Test("expand substitutes arbitrary ${VAR}")
  func expandArbitraryVar() {
    withEnv("DOG_TEST_VAR", value: "custom-value") {
      #expect(ConfigPaths.expand("${DOG_TEST_VAR}/sub") == "custom-value/sub")
    }
  }

  @Test("expand substitutes empty string for missing env var")
  func expandMissingVarEmpty() {
    unsetenv("DOG_MISSING_VAR")
    #expect(ConfigPaths.expand("${DOG_MISSING_VAR}/foo") == "/foo")
  }

  @Test("expand handles multiple ${VAR} substitutions")
  func expandMultipleVars() {
    withEnv("DOG_A", value: "alpha") {
      withEnv("DOG_B", value: "beta") {
        #expect(ConfigPaths.expand("${DOG_A}-${DOG_B}") == "alpha-beta")
      }
    }
  }

  @Test("expand leaves unclosed ${VAR without closing brace alone")
  func expandUnclosedBrace() {
    withEnv("HOME", value: "/Users/test") {
      // No closing } — should pass through unchanged
      let result = ConfigPaths.expand("${HOME/foo")
      #expect(result == "${HOME/foo")
    }
  }

  // MARK: - configDir / themesDir
  //
  // NOTE: `configDir` and `themesDir` are `static let` computed once at
  // first access. We can't reliably reset them per test, so we verify the
  // current process state instead of mutating env and re-reading.

  @Test("themesDir is non-empty when HOME or XDG_CONFIG_HOME is set")
  func themesDirIsPopulated() {
    // Either HOME or XDG_CONFIG_HOME is set in every real test env
    let xdg = getenv("XDG_CONFIG_HOME").map { String(cString: $0) }
    let home = getenv("HOME").map { String(cString: $0) }
    if (xdg != nil && !xdg!.isEmpty) || (home != nil && !home!.isEmpty) {
      #expect(!ConfigPaths.themesDir.isEmpty)
    }
  }

  @Test("themesDir ends with /dog/themes")
  func themesDirSuffix() {
    guard !ConfigPaths.themesDir.isEmpty else { return }
    #expect(ConfigPaths.themesDir.hasSuffix("/dog/themes"))
  }

  @Test("configDir ends with /dog")
  func configDirSuffix() {
    guard !ConfigPaths.configDir.isEmpty else { return }
    #expect(ConfigPaths.configDir.hasSuffix("/dog"))
  }

  // MARK: - Helpers

  /// Set an env var, run a closure, restore prior value.
  private func withEnv(_ name: String, value: String, _ body: () -> Void) {
    let previous = getenv(name).map { String(cString: $0) }
    setenv(name, value, 1)
    defer {
      if let previous {
        setenv(name, previous, 1)
      } else {
        unsetenv(name)
      }
    }
    body()
  }
}
