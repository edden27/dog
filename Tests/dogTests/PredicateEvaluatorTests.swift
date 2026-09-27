import Testing
import TreeSitterJSON

@testable import dog

/// Pins how dog treats query checks it cannot evaluate: the rule stays off.
/// Before this, an unknown check was dropped and its rule fired everywhere,
/// which made every plain C and C++ function call draw as a builtin.
@Suite("Predicate evaluator")
struct PredicateEvaluatorTests {

  private static let jsonSource = Array("{\"key\": \"value\"}".utf8)

  private func tokens(query: String) async throws -> [SyntaxToken] {
    let entry = LanguageEntry(
      tsLanguage: SendablePointer(raw: tree_sitter_json()!),
      queryBytes: Array(query.utf8),
      languageName: "json-predicate-test"
    )
    return try await entry.parse(sourceBytes: Self.jsonSource)
  }

  @Test("A rule with an unknown check produces no tokens")
  func unknownCheckTurnsRuleOff() async throws {
    let unguarded = try await tokens(query: "(string) @string")
    let guarded = try await tokens(
      query: "((string) @string (#has-ancestor? @string pair))")
    #expect(!unguarded.isEmpty)
    #expect(guarded.isEmpty)
  }

  @Test("A match check with an unknown pattern turns its rule off")
  func unknownMatchPatternTurnsRuleOff() async throws {
    let guarded = try await tokens(
      query: "((string) @string (#match? @string \"^[0-9]+$\"))")
    #expect(guarded.isEmpty)
  }

  @Test("A directive like #set! leaves the rule on")
  func directiveLeavesRuleOn() async throws {
    let annotated = try await tokens(
      query: "((string) @string (#set! @string \"priority\" \"105\"))")
    #expect(!annotated.isEmpty)
  }

  @Test("Plain C and C++ calls draw as calls, not builtins", arguments: ["c", "cpp"])
  func plainCallIsNotBuiltin(language: String) async throws {
    let source = "int main(void) { foo(1); return 0; }"
    let callStart = Array(source.utf8).firstIndex(of: UInt8(ascii: "f"))!
    let tokens = try await SyntaxParser.parse(sourceBytes: Array(source.utf8), language: language)
    // The renderer draws the first token that reaches a byte, so that is the
    // one that must be the call color. No token may claim it is a builtin.
    let callTokens = tokens.filter { $0.startByte == callStart }
    #expect(callTokens.first?.tokenType == .functionCall)
    #expect(!callTokens.contains { $0.tokenType == .functionBuiltin })
  }

  /// Every check the shipped query files use that dog cannot evaluate, by
  /// language. A new entry here means a rule that silently stopped working;
  /// a missing one means support was added and this list should shrink.
  @Test("Shipped queries carry exactly the known unsupported checks")
  func shippedQueriesUnsupportedChecks() async throws {
    let registry = LanguageRegistry.shared
    var unsupportedByLanguage: [String: [String]] = [:]

    for name in registry.languageNames {
      guard let entry = registry.lookup(name) else { continue }
      for predicates in await entry.patternPredicates() {
        for predicate in predicates {
          if case .unsupported(let check) = predicate {
            unsupportedByLanguage[name, default: []].append(check)
          }
        }
      }
    }

    // cpp: a template-method rule and three four-deep `a::b::c::d::name`
    // rules. go: a spell-check hint with no color. rust: the `assert` macro
    // rule, which loses to the macro color anyway. Each has a fallback rule
    // that colors the same word, so being off costs nothing on screen.
    let expected: [String: [String]] = [
      "cpp": ["has-parent?", "has-ancestor?", "has-ancestor?", "has-ancestor?"],
      "go": ["not-has-parent?"],
      "rust": ["contains?"],
    ]
    #expect(unsupportedByLanguage == expected)
  }
}
