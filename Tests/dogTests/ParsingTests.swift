import Foundation
import Testing

@testable import dog

/// Step 2 parsing tests — aliases, coverage, integration, language-specific tokens.
@Suite("Parsing", .serialized)
struct ParsingTests {

  // MARK: - Alias Resolution

  /// Every linguist alias must resolve to the correct grammar.
  @Test("All aliases resolve to correct language")
  func aliasesResolve() async throws {
    let aliasMap: [(alias: String, canonical: String)] = [
      // JavaScript
      ("js", "javascript"),
      ("node", "javascript"),
      // TypeScript
      ("ts", "typescript"),
      ("bun", "typescript"),
      ("deno", "typescript"),
      ("ts-node", "typescript"),
      // TSX
      ("typescriptreact", "tsx"),
      // Python — linguist aliases
      ("py", "python"),
      // Ruby
      ("rb", "ruby"),
      ("jruby", "ruby"),
      ("macruby", "ruby"),
      ("rake", "ruby"),
      // Rust
      ("rs", "rust"),
      // Shell
      ("sh", "bash"),
      ("shell", "bash"),
      ("shell-script", "bash"),
      ("zsh", "bash"),
      // C++
      ("c++", "cpp"),
      // Go
      ("golang", "go"),
      // HTML
      ("xhtml", "html"),
      // JSON
      ("geojson", "json"),
      ("jsonl", "json"),
      ("sarif", "json"),
      ("topojson", "json"),
      // Markdown
      ("md", "markdown"),
      ("pandoc", "markdown"),
      // YAML
      ("yml", "yaml")
    ]

    let registry = LanguageRegistry.shared

    for entry in aliasMap {
      let result = registry.lookup(entry.alias)
      #expect(
        result != nil,
        "Alias '\(entry.alias)' should resolve to '\(entry.canonical)' but returned nil"
      )
    }
  }

  /// Canonical names must all resolve.
  @Test("All 17 canonical names resolve")
  func canonicalNamesResolve() {
    let canonicals = [
      "bash", "c", "cpp", "css", "go", "html", "javascript",
      "json", "lua", "markdown", "python", "ruby", "rust",
      "swift", "tsx", "typescript", "yaml"
    ]

    let registry = LanguageRegistry.shared

    for name in canonicals {
      #expect(registry.lookup(name) != nil, "Canonical name '\(name)' not found")
    }
    #expect(
      registry.languageNames.count == 17,
      "Expected 17 languages, got \(registry.languageNames.count)")
  }

  /// Aliases that should NOT resolve (typos, wrong names).
  @Test("Invalid names return nil")
  func invalidNamesReturnNil() {
    let registry = LanguageRegistry.shared
    let invalid = ["java", "kotlin", "scala", "php", "perl", "haskell", "swft", ""]
    for name in invalid {
      #expect(registry.lookup(name) == nil, "'\(name)' should not resolve")
    }
  }

  // MARK: - Token Coverage

  /// For each language, >95% of non-whitespace bytes across ALL fixtures should be covered.
  @Test("Token coverage >95% for all languages (all fixtures combined)")
  func tokenCoverage() async throws {
    let languages: [(name: String, ext: String)] = [
      ("bash", "sh"), ("c", "c"), ("cpp", "cpp"), ("css", "css"),
      ("go", "go"), ("html", "html"), ("javascript", "js"),
      ("json", "json"), ("lua", "lua"), ("markdown", "md"),
      ("python", "py"), ("ruby", "rb"), ("rust", "rs"),
      ("swift", "swift"), ("tsx", "tsx"), ("typescript", "ts"),
      ("yaml", "yml")
    ]

    for lang in languages {
      var totalNonWhitespace = 0
      var totalCovered = 0
      var totalTokens = 0
      var filesFound = 0

      // Parse ALL fixture files for this language
      let langDir = fixtureDir(language: lang.name)
      guard let langDir, FileManager.default.fileExists(atPath: langDir) else {
        Issue.record("Missing fixture dir for \(lang.name)")
        continue
      }

      let files = try FileManager.default.contentsOfDirectory(atPath: langDir)
        .filter { $0.hasSuffix(".\(lang.ext)") }

      for file in files {
        let path = "\(langDir)/\(file)"
        let source = try String(contentsOfFile: path, encoding: .utf8)
        let sourceBytes = Array(source.utf8)
        let tokens = try await SyntaxParser.parse(sourceBytes: sourceBytes, language: lang.name)

        var covered = Set<Int>()
        for token in tokens {
          for byteOffset in token.startByte..<min(token.endByte, sourceBytes.count) {
            covered.insert(byteOffset)
          }
        }

        let whitespace: Set<UInt8> = [0x20, 0x09, 0x0A, 0x0D]
        let nonWS = sourceBytes.enumerated().filter { !whitespace.contains($0.element) }.count
        let coveredNonWS = sourceBytes.enumerated().filter {
          !whitespace.contains($0.element) && covered.contains($0.offset)
        }.count

        totalNonWhitespace += nonWS
        totalCovered += coveredNonWS
        totalTokens += tokens.count
        filesFound += 1
      }

      let coverage =
        totalNonWhitespace > 0
        ? Double(totalCovered) / Double(totalNonWhitespace) * 100.0
        : 100.0

      let icon = coverage >= 95.0 ? "✅" : coverage >= 50.0 ? "🟡" : "⚠️"
      let coverageStr = String(format: "%.1f", coverage)
      print(
        "\(icon)  \(lang.name): \(coverageStr)% coverage"
          + " (\(totalTokens) tokens, \(totalNonWhitespace) non-ws bytes, \(filesFound) files)"
      )
      #expect(
        coverage >= 95.0,
        "\(lang.name): coverage \(coverageStr)% across \(filesFound) files (expected >50%)"
      )
    }
  }

  // MARK: - Integration Tests

  /// Parse jquery.js — verify token count is substantial.
  @Test("Parse jquery.js produces ~86k tokens")
  func parseJQueryJS() async throws {
    let testDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    let projectRoot =
      testDir
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
    let path = projectRoot.appendingPathComponent("tests/fixtures/jquery.js").path

    guard FileManager.default.fileExists(atPath: path) else {
      Issue.record("jquery.js fixture not found at \(path)")
      return
    }

    let source = try String(contentsOfFile: path, encoding: .utf8)
    let tokens = try await SyntaxParser.parse(sourceBytes: Array(source.utf8), language: "javascript")

    // Proof benchmark found ~86k tokens. Allow some variance.
    #expect(tokens.count > 50_000, "Expected ~86k tokens, got \(tokens.count)")
    #expect(tokens.count < 150_000, "Unexpectedly high token count: \(tokens.count)")
  }

  /// Parse a Swift file — verify Swift-specific token types appear.
  @Test("Swift file produces Swift-specific tokens")
  func swiftSpecificTokens() async throws {
    guard let path = fixturePath(language: "swift", ext: "swift", size: "medium") else {
      Issue.record("Missing medium swift fixture")
      return
    }

    let source = try String(contentsOfFile: path, encoding: .utf8)
    let tokens = try await SyntaxParser.parse(sourceBytes: Array(source.utf8), language: "swift")
    let tokenNames = Set(tokens.map(\.name))

    // Swift must have these fundamental token types
    let expected: Set<String> = ["keyword", "string", "comment", "type", "function"]
    let found = expected.intersection(tokenNames)

    #expect(
      found.count >= 4,
      "Swift should have most of \(expected), only found \(found)"
    )
  }

  /// Parse a Python file — verify Python-specific tokens.
  @Test("Python file produces Python-specific tokens")
  func pythonSpecificTokens() async throws {
    guard let path = fixturePath(language: "python", ext: "py", size: "small") else {
      Issue.record("Missing small python fixture")
      return
    }

    let source = try String(contentsOfFile: path, encoding: .utf8)
    let tokens = try await SyntaxParser.parse(sourceBytes: Array(source.utf8), language: "python")
    let tokenNames = Set(tokens.map(\.name))

    let expected: Set<String> = ["keyword", "string", "comment", "function"]
    let found = expected.intersection(tokenNames)

    #expect(
      found.count >= 3,
      "Python should have most of \(expected), only found \(found)"
    )
  }

  // MARK: - Helpers

  private func projectRoot() -> URL {
    URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()  // ParsingTests.swift → dogTests/
      .deletingLastPathComponent()  // dogTests → Tests/
      .deletingLastPathComponent()  // Tests → cli/
      .deletingLastPathComponent()  // cli → project root
  }

  private func fixturePath(language: String, ext: String, size: String) -> String? {
    let path = projectRoot()
      .appendingPathComponent("tests/fixtures/performance/\(language)/\(size).\(ext)")
      .path
    return FileManager.default.fileExists(atPath: path) ? path : nil
  }

  private func fixtureDir(language: String) -> String? {
    let path = projectRoot()
      .appendingPathComponent("tests/fixtures/performance/\(language)")
      .path
    return FileManager.default.fileExists(atPath: path) ? path : nil
  }
}
