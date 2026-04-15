/// A single syntax token produced by tree-sitter, with UTF-8 byte offsets into the source.
@frozen @usableFromInline
struct SyntaxToken: Sendable {
  /// Resolved token type for theme lookup.
  let tokenType: TokenType?
  /// Start position as a UTF-8 byte offset into the source.
  let startByte: Int
  /// End position as a UTF-8 byte offset into the source.
  let endByte: Int
  #if DEBUG
    /// Raw capture name — retained for test auditing only, not used in the render path.
    let name: String
  #endif
}
