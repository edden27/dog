import Testing

@testable import dog

@Suite("TokenType")
struct TokenTypeTests {

  /// Every capture name from all 17 grammar highlight queries must resolve.
  @Test("All 96 real capture names resolve to a TokenType")
  func allCaptureNamesResolve() {
    let allCaptureNames = [
      // Keywords & Control Flow
      "keyword", "keyword.conditional", "keyword.conditional.ternary",
      "keyword.coroutine", "keyword.directive", "keyword.directive.define",
      "keyword.exception", "keyword.function", "keyword.import",
      "keyword.modifier", "keyword.operator", "keyword.repeat",
      "keyword.return", "keyword.type",
      "conditional", "repeat", "include",
      // Functions & Methods
      "function", "function.builtin", "function.call", "function.macro",
      "function.method", "function.method.builtin", "function.method.call",
      "function.special", "function.command", "method", "constructor",
      // Types
      "type", "type.builtin", "type.definition",
      // Variables & Parameters
      "variable", "variable.builtin", "variable.member", "variable.parameter",
      "parameter", "field", "property", "label",
      // Modules
      "module", "module.builtin",
      // Literals
      "string", "string.documentation", "string.escape", "string.regex",
      "string.regexp", "string.special", "string.special.key",
      "string.special.path", "string.special.regex", "string.special.symbol",
      "string.special.url",
      "character", "character.special",
      "number", "number.float", "float",
      "boolean", "constant", "constant.builtin", "constant.macro",
      // Punctuation
      "punctuation.bracket", "punctuation.delimiter", "punctuation.special",
      "delimiter", "operator",
      // Markup
      "markup.heading", "markup.heading.1", "markup.heading.2",
      "markup.heading.3", "markup.heading.4", "markup.heading.5",
      "markup.link.label", "markup.list", "markup.quote", "markup.raw.block",
      // Tags & Attributes
      "tag", "tag.attribute", "tag.builtin", "tag.delimiter", "tag.error",
      "attribute", "attribute.builtin",
      // Text
      "text.literal", "text.reference", "text.title", "text.uri",
      "spell", "nospell", "none", "conceal",
      // Other
      "comment", "comment.documentation",
      "escape", "embedded", "error"
    ]

    #expect(allCaptureNames.count == 96, "Expected 96 capture names, got \(allCaptureNames.count)")

    for name in allCaptureNames {
      let resolved = TokenType.from(captureName: name)
      #expect(resolved != nil, "Capture name '\(name)' did not resolve to a TokenType")
    }
  }

  @Test("Exact match works")
  func exactMatch() {
    #expect(TokenType.from(captureName: "keyword") == .keyword)
    #expect(TokenType.from(captureName: "function.builtin") == .functionBuiltin)
    #expect(TokenType.from(captureName: "string.special.key") == .stringSpecialKey)
    #expect(TokenType.from(captureName: "tag.error") == .tagError)
    #expect(TokenType.from(captureName: "text.uri") == .textUri)
  }

  @Test("Hierarchical fallback works")
  func hierarchicalFallback() {
    // Unknown sub-type falls back to parent
    #expect(TokenType.from(captureName: "keyword.something.new") == .keyword)
    #expect(TokenType.from(captureName: "function.unknown") == .function)
    #expect(TokenType.from(captureName: "string.special.unknown") == .stringSpecial)
  }

  @Test("Completely unknown name returns nil")
  func unknownReturnsNil() {
    #expect(TokenType.from(captureName: "totallyFake") == nil)
    #expect(TokenType.from(captureName: "") == nil)
  }

  @Test("CaseIterable covers all 96 token types")
  func caseCount() {
    #expect(TokenType.allCases.count == 96, "Expected 96 cases, got \(TokenType.allCases.count)")
  }
}
