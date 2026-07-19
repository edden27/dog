import Testing
import TreeSitterJSON

@testable import dog

/// Pins the degradation contract for highlight-query compile failures
/// (perf Phase 3 item 3): a broken query must degrade to zero tokens —
/// plain rendering, no crash, no thrown error. The stderr warning itself is
/// exercised by the same path (visible when running tests with -v).
@Suite("Query compile failure")
struct QueryFailureTests {

  @Test("Broken highlight query degrades to no tokens without crashing")
  func brokenQueryDegrades() async throws {
    // Real grammar pointer, deliberately invalid query source.
    let brokenEntry = LanguageEntry(
      tsLanguage: SendablePointer(raw: tree_sitter_json()!),
      queryBytes: Array("((this is not a valid query".utf8),
      languageName: "json-broken-test"
    )

    let tokens = try await brokenEntry.parse(sourceBytes: Array("{\"key\": 1}".utf8))
    #expect(tokens.isEmpty, "broken query must yield zero tokens, got \(tokens.count)")
  }

  @Test("Missing highlight query degrades to no tokens without crashing")
  func missingQueryDegrades() async throws {
    let querylessEntry = LanguageEntry(
      tsLanguage: SendablePointer(raw: tree_sitter_json()!),
      queryBytes: nil,
      languageName: "json-queryless-test"
    )

    let tokens = try await querylessEntry.parse(sourceBytes: Array("{\"key\": 1}".utf8))
    #expect(tokens.isEmpty, "missing query must yield zero tokens, got \(tokens.count)")
  }
}
