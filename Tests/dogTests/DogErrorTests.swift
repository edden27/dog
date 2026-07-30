import Testing

@testable import dog

@Suite("DogError")
struct DogErrorTests {

  @Test("fileNotFound has exit code 1")
  func fileNotFoundExit() {
    let error = DogError.fileNotFound(path: "/tmp/nope.swift")
    #expect(error.exitCode == 1)
  }

  @Test("fileNotFound description includes path")
  func fileNotFoundDescription() {
    let error = DogError.fileNotFound(path: "/tmp/nope.swift")
    #expect(error.description.contains("/tmp/nope.swift"))
    #expect(error.description.contains("not found"))
  }

  @Test("binaryFile has exit code 1")
  func binaryFileExit() {
    let error = DogError.binaryFile(path: "/bin/ls")
    #expect(error.exitCode == 1)
  }

  @Test("unknownLanguage has exit code 2 (bad usage)")
  func unknownLanguageExit() {
    let error = DogError.unknownLanguage(name: "swft", suggestion: "swift")
    #expect(error.exitCode == 2)
  }

  @Test("unknownLanguage with suggestion shows 'Did you mean'")
  func unknownLanguageSuggestion() {
    let error = DogError.unknownLanguage(name: "swft", suggestion: "swift")
    #expect(error.description.contains("Did you mean"))
    #expect(error.description.contains("swift"))
  }

  @Test("unknownLanguage without suggestion shows --list-languages hint")
  func unknownLanguageNoSuggestion() {
    let error = DogError.unknownLanguage(name: "brainfuck", suggestion: nil)
    #expect(error.description.contains("--list-languages"))
  }

  @Test("readError includes path and detail")
  func readErrorDescription() {
    let error = DogError.readError(path: "/tmp/dir", detail: "it is a directory")
    #expect(error.description.contains("/tmp/dir"))
    #expect(error.description.contains("it is a directory"))
  }

  @Test("readError from stdin reads as a stdin message")
  func readErrorStdinDescription() {
    let error = DogError.readError(path: "<stdin>", detail: "input is not valid UTF-8")
    #expect(error.description == "stdin input is not valid UTF-8")
  }

  @Test("parseError has exit code 1")
  func parseErrorExit() {
    let error = DogError.parseError(language: "swift", detail: "bad tree")
    #expect(error.exitCode == 1)
  }

  @Test("invalidConfig has exit code 1")
  func invalidConfigExit() {
    let error = DogError.invalidConfig(path: "~/.config/dog/config.toml", detail: "bad key")
    #expect(error.exitCode == 1)
    #expect(error.description.contains("config.toml"))
  }

  @Test("invalidTheme has exit code 1")
  func invalidThemeExit() {
    let error = DogError.invalidTheme(path: "mytheme.json", detail: "bad hex '#XYZ'")
    #expect(error.exitCode == 1)
    #expect(error.description.contains("bad hex"))
  }

  // MARK: - themeNotFound

  @Test("themeNotFound has exit code 1")
  func themeNotFoundExit() {
    let error = DogError.themeNotFound(
      name: "Nord", searchedDir: "/themes", available: []
    )
    #expect(error.exitCode == 1)
  }

  @Test("themeNotFound description includes name and searched dir")
  func themeNotFoundBasic() {
    let error = DogError.themeNotFound(
      name: "Catppuccin", searchedDir: "/themes", available: []
    )
    #expect(error.description.contains("Catppuccin"))
    #expect(error.description.contains("/themes"))
  }

  @Test("themeNotFound suggests close matches via edit distance")
  func themeNotFoundSuggestion() {
    let error = DogError.themeNotFound(
      name: "Cattpuccin",  // one transposition away from Catppuccin
      searchedDir: "/themes",
      available: ["Catppuccin", "Nord", "One Dark Pro"]
    )
    #expect(error.description.contains("Did you mean"))
    #expect(error.description.contains("Catppuccin"))
  }

  @Test("themeNotFound lists names as a Did-you-mean when no close match")
  func themeNotFoundAvailableList() {
    let error = DogError.themeNotFound(
      name: "Dracula Pro Van Helsing",
      searchedDir: "/themes",
      available: ["Catppuccin Latte", "Nord Dark"]
    )
    #expect(error.description.contains("Did you mean: "))
    #expect(error.description.contains("Catppuccin Latte"))
    #expect(error.description.contains("Nord Dark"))
  }

  @Test("themeNotFound caps available list at 10 entries")
  func themeNotFoundTruncatesList() {
    let available = (1...20).map { "Theme\($0)" }
    let error = DogError.themeNotFound(
      name: "Completely Unique Name",
      searchedDir: "/themes",
      available: available
    )
    // Should list only 10 themes then "…"
    #expect(error.description.contains("Theme1"))
    #expect(error.description.contains("Theme10"))
    #expect(error.description.contains("…"))
    #expect(!error.description.contains("Theme11"))
  }

  @Test("themeNotFound with empty available list shows --list-themes hint")
  func themeNotFoundEmptyList() {
    let error = DogError.themeNotFound(
      name: "Missing", searchedDir: "/themes", available: []
    )
    #expect(error.description.contains("--list-themes"))
  }
}
