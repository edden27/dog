import Foundation
import Testing

@testable import dog

/// Verifies tree-sitter handles broken syntax gracefully — parses without
/// crashing and still produces tokens for the valid parts of the file.
/// Note: tree-sitter creates ERROR AST nodes for invalid syntax but no
/// highlight query defines @error — error nodes are simply skipped.
@Suite("Error Recovery", .serialized)
struct ErrorRecoveryTests {
  private static func fixturePath(_ sub: String) -> String {
    URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .appendingPathComponent("tests/fixtures/performance/\(sub)")
      .path
  }

  @Test("lua errors.lua parses without crashing and recovers valid tokens")
  func luaErrorRecovery() async throws {
    let path = Self.fixturePath("lua/errors.lua")
    let source = try String(contentsOfFile: path, encoding: .utf8)
    let tokens = try await SyntaxParser.parse(sourceBytes: Array(source.utf8), language: "lua")
    // File has intentional syntax errors but also valid code after them.
    // Tree-sitter should recover and produce tokens for the valid parts.
    #expect(tokens.count > 0, "Expected tokens from valid parts of broken Lua file")
  }

  @Test("yaml escapes.yaml parses and produces tokens")
  func yamlEscapes() async throws {
    let path = Self.fixturePath("yaml/escapes.yaml")
    let source = try String(contentsOfFile: path, encoding: .utf8)
    let tokens = try await SyntaxParser.parse(sourceBytes: Array(source.utf8), language: "yaml")
    #expect(tokens.count > 0, "Expected tokens from YAML with escapes")
  }
}
