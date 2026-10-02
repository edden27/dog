import Foundation
import Testing

@testable import dog

/// Audit all token types produced by all 17 grammars.
///
/// This test parses a medium-sized fixture for each language and collects
/// every unique capture name. The output documents what tree-sitter produces
/// so Step 4's TokenType enum covers everything.
@Suite("Token Audit", .serialized)
struct TokenAuditTests {

  /// Map of language name → file extension for fixture lookup.
  private static let languages: [(name: String, ext: String)] = [
    ("bash", "sh"),
    ("c", "c"),
    ("cpp", "cpp"),
    ("css", "css"),
    ("go", "go"),
    ("html", "html"),
    ("javascript", "js"),
    ("json", "json"),
    ("lua", "lua"),
    ("markdown", "md"),
    ("python", "py"),
    ("ruby", "rb"),
    ("rust", "rs"),
    ("swift", "swift"),
    ("tsx", "tsx"),
    ("typescript", "ts"),
    ("yaml", "yml")
  ]

  /// Find the fixture directory relative to the test file.
  private static func fixturePath(language: String, ext: String, size: String = "medium") -> String? {
    let path = TestFixtures.path("performance/\(language)/\(size).\(ext)")
    return FileManager.default.fileExists(atPath: path) ? path : nil
  }

  @Test("All 17 languages parse without crashing")
  func allLanguagesParse() async throws {
    for lang in Self.languages {
      guard let path = Self.fixturePath(language: lang.name, ext: lang.ext) else {
        Issue.record("Missing fixture for \(lang.name)")
        continue
      }
      let source = try String(contentsOfFile: path, encoding: .utf8)
      let tokens = try await SyntaxParser.parse(sourceBytes: Array(source.utf8), language: lang.name)
      #expect(tokens.count > 0, "Expected tokens for \(lang.name), got 0")
    }
  }

  @Test("Collect all unique token types per language")
  func auditTokenTypes() async throws {
    var allNames: Set<String> = []
    struct LanguageTokenAudit {
      let language: String
      let names: Set<String>
      let count: Int
    }
    var perLanguage: [LanguageTokenAudit] = []

    for lang in Self.languages {
      guard let path = Self.fixturePath(language: lang.name, ext: lang.ext) else {
        continue
      }
      let source = try String(contentsOfFile: path, encoding: .utf8)
      let tokens = try await SyntaxParser.parse(sourceBytes: Array(source.utf8), language: lang.name)

      var names: Set<String> = []
      for token in tokens {
        names.insert(token.name)
        allNames.insert(token.name)
      }
      perLanguage.append(LanguageTokenAudit(language: lang.name, names: names, count: tokens.count))
    }

    // Print the full audit report
    print("\n━━━ TOKEN AUDIT ━━━\n")
    for entry in perLanguage.sorted(by: { $0.language < $1.language }) {
      let sorted = entry.names.sorted()
      print("\(entry.language) (\(entry.count) tokens, \(sorted.count) types):")
      for name in sorted {
        print("  - \(name)")
      }
      print("")
    }

    print("━━━ ALL UNIQUE TOKEN TYPES (\(allNames.count) total) ━━━\n")
    for name in allNames.sorted() {
      print("  \(name)")
    }
    print("")

    // Must have found token types
    #expect(allNames.count > 0, "No token types found across any language")
    #expect(perLanguage.count == Self.languages.count, "Not all languages parsed")
  }

  /// Extra fixtures that cover capture names missing from the medium files.
  private static let extraFixtures: [(lang: String, file: String)] = [
    ("html", "error-tags.html"),
    ("swift", "regex.swift"),
    ("markdown", "references.md"),
    ("yaml", "escapes.yaml"),
    ("yaml", "errors.yaml"),
    ("lua", "errors.lua")
  ]

  private static func extraFixturePath(language: String, file: String) -> String? {
    let path = TestFixtures.path("performance/\(language)/\(file)")
    return FileManager.default.fileExists(atPath: path) ? path : nil
  }

  @Test("Extra fixtures cover capture names missing from medium files")
  func extraFixturesCoverMissing() async throws {
    // Capture names that appear in extra fixtures but not medium fixtures.
    // nvim-treesitter queries use different naming than TreeSitterLanguages.
    // After switching to nvim queries + predicate resolution, only captures
    // that actually exist in our query files are expected.
    let expectedFromExtras: Set<String> = [
      "string.regexp"
    ]

    var found: Set<String> = []
    for fixture in Self.extraFixtures {
      guard let path = Self.extraFixturePath(language: fixture.lang, file: fixture.file) else {
        Issue.record("Missing extra fixture: \(fixture.lang)/\(fixture.file)")
        continue
      }
      let source = try String(contentsOfFile: path, encoding: .utf8)
      let tokens = try await SyntaxParser.parse(sourceBytes: Array(source.utf8), language: fixture.lang)
      for token in tokens where expectedFromExtras.contains(token.name) {
        found.insert(token.name)
      }
    }

    let stillMissing = expectedFromExtras.subtracting(found)
    #expect(
      stillMissing.isEmpty,
      "These capture names still not found in fixtures: \(stillMissing.sorted())"
    )
  }

  @Test("Token byte ranges are valid UTF-8 offsets")
  func tokenByteRangesValid() async throws {
    for lang in Self.languages {
      guard let path = Self.fixturePath(language: lang.name, ext: lang.ext, size: "small") else {
        continue
      }
      let source = try String(contentsOfFile: path, encoding: .utf8)
      let sourceBytes = Array(source.utf8)
      let tokens = try await SyntaxParser.parse(sourceBytes: Array(source.utf8), language: lang.name)

      for token in tokens {
        #expect(
          token.startByte >= 0 && token.startByte <= sourceBytes.count,
          "\(lang.name): startByte \(token.startByte) out of range (source is \(sourceBytes.count) bytes)"
        )
        #expect(
          token.endByte >= token.startByte && token.endByte <= sourceBytes.count,
          "\(lang.name): endByte \(token.endByte) out of range"
        )
      }
    }
  }

  @Test("Parse empty string returns empty array")
  func emptyStringReturnsEmpty() async throws {
    let tokens = try await SyntaxParser.parse(sourceBytes: Array("".utf8), language: "swift")
    #expect(tokens.isEmpty)
  }

  @Test("Unknown language throws DogError.unknownLanguage")
  func unknownLanguageThrows() async {
    do {
      _ = try await SyntaxParser.parse(sourceBytes: Array("hello".utf8), language: "fakeLang")
      Issue.record("Expected unknownLanguage error")
    } catch let error as DogError {
      if case .unknownLanguage(let name, _) = error {
        #expect(name == "fakeLang")
      } else {
        Issue.record("Wrong error type: \(error)")
      }
    } catch {
      Issue.record("Unexpected error: \(error)")
    }
  }
}
