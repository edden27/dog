import TreeSitter

/// Zero-cost Sendable wrapper for tree-sitter C pointers.
/// Safe because TSLanguage* is immutable static data and TSQuery* is created
/// once during init and never mutated after. Both are safe to share across
/// isolation boundaries.
struct SendablePointer: @unchecked Sendable {
  let raw: OpaquePointer
}

/// Wraps a single tree-sitter grammar and its highlight query. Lazy-loads on first parse.
///
/// Uses the tree-sitter C API directly for maximum performance.
/// SwiftTreeSitter's wrapper adds ~67% overhead from string splitting,
/// Dictionary allocation, and redundant predicate lookups per match.
actor LanguageEntry {
  private let tsLanguage: SendablePointer
  private let queryBytes: [UInt8]?
  private var tsQuery: SendablePointer?
  private var patternPredicates: [[PredicateEvaluator.QueryPredicate]] = []
  /// Pre-resolved TokenType per capture index. Built once from the query at ready time.
  /// Eliminates ts_query_capture_name_for_id + String alloc + dict lookup from the hot loop.
  private var captureTokenTypes: [TokenType?] = []
  private var isReady = false

  init(tsLanguage: SendablePointer, queryBytes: [UInt8]?) {
    self.tsLanguage = tsLanguage
    self.queryBytes = queryBytes
  }

  deinit {
    if let tsQuery { ts_query_delete(tsQuery.raw) }
  }

  /// Parse source code and return syntax tokens with UTF-8 byte offsets.
  func parse(sourceBytes: [UInt8]) throws -> [SyntaxToken] {
    try ensureReady()
    guard let tsQuery else { return [] }

    let tsParser = ts_parser_new()!
    defer { ts_parser_delete(tsParser) }
    ts_parser_set_language(tsParser, tsLanguage.raw)
    guard
      let tsTree = sourceBytes.withUnsafeBufferPointer({ buf in
        ts_parser_parse_string(tsParser, nil, buf.baseAddress, UInt32(buf.count))
      })
    else {
      throw DogError.parseError(
        language: "unknown",
        detail: "tree-sitter returned nil tree"
      )
    }
    defer { ts_tree_delete(tsTree) }

    return executeQuery(tsQuery.raw, tree: tsTree, sourceBytes: sourceBytes)
  }

  // MARK: - Private

  private func executeQuery(
    _ query: OpaquePointer, tree: OpaquePointer, sourceBytes: [UInt8]
  ) -> [SyntaxToken] {
    let rootNode = ts_tree_root_node(tree)
    let tsCursor = ts_query_cursor_new()!
    defer { ts_query_cursor_delete(tsCursor) }
    ts_query_cursor_exec(tsCursor, query, rootNode)

    var tokens: [SyntaxToken] = []
    var match = TSQueryMatch()

    while ts_query_cursor_next_match(tsCursor, &match) {
      let patternIndex = Int(match.pattern_index)

      if patternIndex < patternPredicates.count,
        !patternPredicates[patternIndex].isEmpty
      {  // swiftlint:disable:this opening_brace
        if !PredicateEvaluator.evaluate(
          patternPredicates[patternIndex], match: match, source: sourceBytes)
        {  // swiftlint:disable:this opening_brace
          continue
        }
      }

      appendCaptures(from: match, query: query, sourceBytes: sourceBytes, to: &tokens)
    }

    return tokens
  }

  private func appendCaptures(
    from match: TSQueryMatch, query: OpaquePointer,
    sourceBytes: [UInt8], to tokens: inout [SyntaxToken]
  ) {
    let captureCount = Int(match.capture_count)
    guard let captures = match.captures else { return }

    for idx in 0..<captureCount {
      let capture = captures[idx]
      let captureIndex = Int(capture.index)

      // nil = underscore-prefixed capture, skip entirely
      guard captureIndex < captureTokenTypes.count,
        let tokenType = captureTokenTypes[captureIndex]
      else { continue }

      let startByte = Int(ts_node_start_byte(capture.node))
      let endByte = Int(ts_node_end_byte(capture.node))
      guard startByte >= 0, endByte <= sourceBytes.count else { continue }

      #if DEBUG
        var nameLen: UInt32 = 0
        let name =
          ts_query_capture_name_for_id(query, capture.index, &nameLen)
          .map { String(cString: $0) } ?? ""
        tokens.append(
          SyntaxToken(
            tokenType: tokenType,
            startByte: startByte,
            endByte: endByte,
            name: name
          ))
      #else
        tokens.append(
          SyntaxToken(
            tokenType: tokenType,
            startByte: startByte,
            endByte: endByte
          ))
      #endif
    }
  }

  private func ensureReady() throws {
    guard !isReady else { return }
    defer { isReady = true }

    guard let bytes = queryBytes else {
      Bark.warning("no highlight query for language")
      return
    }

    var errorOffset: UInt32 = 0
    var errorType: TSQueryError = TSQueryErrorNone

    let query = bytes.withUnsafeBufferPointer { buf -> OpaquePointer? in
      guard let ptr = buf.baseAddress else { return nil }
      return ts_query_new(
        tsLanguage.raw,
        UnsafeRawPointer(ptr).assumingMemoryBound(to: CChar.self),
        UInt32(buf.count), &errorOffset, &errorType
      )
    }

    guard let query else {
      Bark.warning(
        "failed to compile query: error at offset \(errorOffset), type \(errorType.rawValue)")
      return
    }

    self.tsQuery = SendablePointer(raw: query)
    self.patternPredicates = PredicateEvaluator.parseAll(query: query)

    // Build capture index → TokenType? table once.
    // ts_query_capture_count returns the number of unique capture names in the query.
    let captureCount = Int(ts_query_capture_count(query))
    var table = [TokenType?](repeating: nil, count: captureCount)
    for i in 0..<captureCount {
      var nameLen: UInt32 = 0
      guard let namePtr = ts_query_capture_name_for_id(query, UInt32(i), &nameLen) else { continue }
      if namePtr[0] == UInt8(ascii: "_") { continue }
      // nil in table = skip (underscore captures). TokenType.none = recognised but unstyled.
      table[i] = TokenType.from(captureName: String(cString: namePtr)) ?? TokenType.none
    }
    self.captureTokenTypes = table
  }
}
