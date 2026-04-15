/// Parses source code into syntax tokens using tree-sitter.
///
/// This is the public API for the parsing layer. The rest of the CLI
/// interacts with tree-sitter only through this type.
enum SyntaxParser {
  /// Parse source code and return syntax tokens with UTF-8 byte offsets.
  ///
  /// - Parameters:
  ///   - sourceBytes: The source code as raw UTF-8 bytes.
  ///   - language: Language name or alias (e.g. "swift", "js", "py").
  /// - Returns: Tokens sorted by position, with byte offsets into the source.
  /// - Throws: `DogError.unknownLanguage` if the language is not supported.
  static func parse(sourceBytes: [UInt8], language: String) async throws -> [SyntaxToken] {
    guard let entry = LanguageRegistry.shared.lookup(language) else {
      throw DogError.unknownLanguage(
        name: language,
        suggestion: findSuggestion(for: language)
      )
    }

    Bark.debug("parsing \(sourceBytes.count) bytes as \(language)")

    let tokens = try await entry.parse(sourceBytes: sourceBytes)

    Bark.debug("got \(tokens.count) tokens")

    // Tokens are nearly sorted (tree-sitter returns matches in document order
    // with minor out-of-order from overlapping patterns). Check if already sorted
    // first — O(n) — and only sort if needed.
    if tokens.count <= 1 { return tokens }
    var needsSort = false
    for i in 1..<tokens.count {
      if tokens[i].startByte < tokens[i - 1].startByte {
        needsSort = true
        break
      }
    }
    return needsSort ? tokens.sorted { $0.startByte < $1.startByte } : tokens
  }

  // MARK: - Private

  /// Find a close match for a misspelled language name.
  private static func findSuggestion(for name: String) -> String? {
    let lowered = name.lowercased()
    let names = LanguageRegistry.shared.languageNames

    // Exact prefix match
    if let match = names.first(where: { $0.hasPrefix(lowered) }) {
      return match
    }

    // Contains match
    if let match = names.first(where: { $0.contains(lowered) || lowered.contains($0) }) {
      return match
    }

    return nil
  }
}
