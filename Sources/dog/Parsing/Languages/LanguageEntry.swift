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
/// Immutable result of highlight-query compilation. Safe to send across task
/// boundaries for the same reason as SendablePointer: the query pointer is
/// created once inside compileQuery and never mutated afterwards.
struct CompiledQuery: @unchecked Sendable {
  let query: SendablePointer
  let patternPredicates: [[PredicateEvaluator.QueryPredicate]]
  /// Pre-resolved TokenType per capture index. Built once from the query at compile time.
  /// Eliminates ts_query_capture_name_for_id + String alloc + dict lookup from the hot loop.
  let captureTokenTypes: [TokenType?]
}

actor LanguageEntry {
  private let tsLanguage: SendablePointer
  private let queryBytes: [UInt8]?
  /// Precompiled query blob (ts_query_serialize output, generated at build
  /// time by scripts/generate/query-blobs.sh). nil or rejected-by-validation
  /// falls back to compiling queryBytes with ts_query_new.
  private let compiledQueryBlob: [UInt8]?
  /// Canonical language name, used in user-facing degradation warnings.
  private let languageName: String
  /// In-flight or finished query compilation. Created on first parse; later
  /// parses (and reentrant callers during the first await) reuse the same task,
  /// so the query compiles exactly once. Task.value caches its result.
  private var compileTask: Task<CompiledQuery?, Never>?
  private var compiledQuery: CompiledQuery?

  init(
    tsLanguage: SendablePointer, queryBytes: [UInt8]?,
    compiledQueryBlob: [UInt8]? = nil, languageName: String
  ) {
    self.tsLanguage = tsLanguage
    self.queryBytes = queryBytes
    self.compiledQueryBlob = compiledQueryBlob
    self.languageName = languageName
  }

  deinit {
    if let compiledQuery { ts_query_delete(compiledQuery.query.raw) }
    // If compileTask finished but its result was never committed (parse threw
    // before the await), the TSQuery leaks until process exit — acceptable for
    // a single-invocation CLI, and the next parse() would reclaim it by
    // awaiting the same task.
  }

  /// Parse source code and return syntax tokens with UTF-8 byte offsets.
  ///
  /// Query compilation overlaps with parsing (perf experiment 004): the
  /// compile runs on a detached task while the tree parses on the actor,
  /// hiding min(parse, compile) — up to 36% of the pipeline on heavy-grammar
  /// files. Warm calls await the already-finished task at no cost.
  func parse(sourceBytes: [UInt8]) async throws -> [SyntaxToken] {
    let compileTask = ensureCompileTask()

    let tsTree = try parseTree(sourceBytes: sourceBytes)
    defer { ts_tree_delete(tsTree) }

    guard let compiled = await compileTask.value else { return [] }
    compiledQuery = compiled

    return executeQuery(compiled, tree: tsTree, sourceBytes: sourceBytes)
  }

  // MARK: - Private

  /// Start (or reuse) the one-shot query compilation task. Stored before any
  /// suspension point, so a reentrant caller during the first parse's await
  /// picks up the same task instead of compiling twice.
  private func ensureCompileTask() -> Task<CompiledQuery?, Never> {
    if let compileTask { return compileTask }
    let language = tsLanguage
    let bytes = queryBytes
    let blob = compiledQueryBlob
    let name = languageName
    let task = Task.detached(priority: .userInitiated) {
      Self.compileQuery(
        tsLanguage: language, queryBytes: bytes,
        compiledQueryBlob: blob, languageName: name)
    }
    compileTask = task
    return task
  }

  /// Parse the source into a tree-sitter tree. Runs synchronously on the actor
  /// while the compile task runs on the global executor — this is the overlap.
  private func parseTree(sourceBytes: [UInt8]) throws -> OpaquePointer {
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
    return tsTree
  }

  private func executeQuery(
    _ compiled: CompiledQuery, tree: OpaquePointer, sourceBytes: [UInt8]
  ) -> [SyntaxToken] {
    let query = compiled.query.raw
    let patternPredicates = compiled.patternPredicates
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

      appendCaptures(
        from: match, query: query,
        captureTokenTypes: compiled.captureTokenTypes,
        sourceBytes: sourceBytes, to: &tokens
      )
    }

    return tokens
  }

  private func appendCaptures(
    from match: TSQueryMatch, query: OpaquePointer,
    captureTokenTypes: [TokenType?],
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

  /// Compile the highlight query and derive its lookup tables. Pure: touches
  /// no actor state, so it can run on a detached task concurrently with
  /// parsing. Returns nil on failure — caller renders unhighlighted.
  ///
  /// Fast path: a precompiled blob deserializes in ~3µs instead of the
  /// 10-130ms ts_query_new pattern analysis (perf experiment 003).
  /// ts_query_deserialize validates magic/format/struct-sizes/grammar-ABI/
  /// query-hash internally; ANY mismatch (e.g. stale blob after a query edit
  /// without regenerating) returns nil here and falls through to ts_query_new
  /// — slower but never wrong.
  private nonisolated static func compileQuery(
    tsLanguage: SendablePointer, queryBytes: [UInt8]?,
    compiledQueryBlob: [UInt8]?, languageName: String
  ) -> CompiledQuery? {
    guard let bytes = queryBytes else {
      Bark.releaseWarning(
        "no highlight query for '\(languageName)'; rendering without highlighting")
      return nil
    }

    if let blob = compiledQueryBlob {
      let deserializedQuery = blob.withUnsafeBufferPointer { blobBuffer -> OpaquePointer? in
        bytes.withUnsafeBufferPointer { queryBuffer -> OpaquePointer? in
          guard let blobPointer = blobBuffer.baseAddress,
            let queryPointer = queryBuffer.baseAddress
          else { return nil }
          return ts_query_deserialize(
            tsLanguage.raw,
            blobPointer, UInt32(blobBuffer.count),
            UnsafeRawPointer(queryPointer).assumingMemoryBound(to: CChar.self),
            UInt32(queryBuffer.count)
          )
        }
      }
      if let deserializedQuery {
        return buildCompiledQuery(from: deserializedQuery)
      }
      Bark.releaseWarning(
        "precompiled query for '\(languageName)' rejected (stale or mismatched blob); "
          + "compiling from source — regenerate with scripts/generate/query-blobs.sh")
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
      Bark.releaseWarning(
        "highlight query for '\(languageName)' failed to compile "
          + "(offset \(errorOffset), error type \(errorType.rawValue)); "
          + "rendering without highlighting")
      return nil
    }

    return buildCompiledQuery(from: query)
  }

  /// Derive the per-query lookup tables (predicates, capture -> TokenType).
  /// Shared by both the deserialize fast path and the ts_query_new fallback —
  /// tables build from the query pointer via public API in microseconds.
  private nonisolated static func buildCompiledQuery(from query: OpaquePointer) -> CompiledQuery {
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

    return CompiledQuery(
      query: SendablePointer(raw: query),
      patternPredicates: PredicateEvaluator.parseAll(query: query),
      captureTokenTypes: table
    )
  }
}
