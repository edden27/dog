import TreeSitter

/// Parses and evaluates tree-sitter query predicates (#match?, #eq?, etc.)
/// using the C API directly.
///
/// All match predicates use fast byte-level matchers (FastMatcher).
/// Common patterns like `^[A-Z]` are checked with simple byte comparisons.
enum PredicateEvaluator {

  // MARK: - Types

  /// Parsed predicate for a single query pattern.
  enum QueryPredicate {
    case matchFast(FastMatcher, captureIndex: UInt32)
    case notMatchFast(FastMatcher, captureIndex: UInt32)
    case equal(String, captureIndex: UInt32)
    case notEqual(String, captureIndex: UInt32)
    case anyOf(Set<String>, captureIndex: UInt32)
    case notAnyOf(Set<String>, captureIndex: UInt32)
  }

  // MARK: - Parsing

  /// Parse all predicates from a compiled query, once at init.
  static func parseAll(query: OpaquePointer) -> [[QueryPredicate]] {
    let patternCount = Int(ts_query_pattern_count(query))
    var result = [[QueryPredicate]](repeating: [], count: patternCount)

    for patternIdx in 0..<patternCount {
      result[patternIdx] = parsePattern(query: query, patternIndex: UInt32(patternIdx))
    }

    return result
  }

  /// Returns true if the match passes all predicates for its pattern.
  static func evaluate(
    _ predicates: [QueryPredicate], match: TSQueryMatch, source: [UInt8]
  ) -> Bool {
    let captureCount = Int(match.capture_count)
    guard let captures = match.captures else { return true }

    return predicates.allSatisfy { predicate in
      evaluateSingle(predicate, captures: captures, captureCount: captureCount, source: source)
    }
  }
}

// MARK: - Predicate Parsing

extension PredicateEvaluator {

  private static func parsePattern(
    query: OpaquePointer, patternIndex: UInt32
  ) -> [QueryPredicate] {
    var stepCount: UInt32 = 0
    guard let steps = ts_query_predicates_for_pattern(query, patternIndex, &stepCount) else {
      return []
    }
    if stepCount == 0 { return [] }

    var predicates: [QueryPredicate] = []
    var cursor = 0

    while cursor < Int(stepCount) {
      guard steps[cursor].type == TSQueryPredicateStepTypeString else {
        cursor += 1
        continue
      }

      let (predicate, nextCursor) = parseSinglePredicate(
        steps: steps, startAt: cursor, stepCount: Int(stepCount), query: query)
      cursor = nextCursor
      if let predicate { predicates.append(predicate) }
    }

    return predicates
  }

  private static func parseSinglePredicate(
    steps: UnsafePointer<TSQueryPredicateStep>,
    startAt: Int, stepCount: Int, query: OpaquePointer
  ) -> (QueryPredicate?, Int) {
    var nameLen: UInt32 = 0
    guard
      let namePtr = ts_query_string_value_for_id(
        query, steps[startAt].value_id, &nameLen)
    else {
      return (nil, startAt + 1)
    }
    let name = String(cString: namePtr)

    let args = collectArguments(
      steps: steps, startAt: startAt + 1, stepCount: stepCount, query: query)

    guard args.hasCaptureArg else { return (nil, args.endCursor) }

    let predicate = buildPredicate(name: name, strings: args.strings, captureIdx: args.captureIdx)
    return (predicate, args.endCursor)
  }

  private struct CollectedArgs {
    var captureIdx: UInt32 = 0
    var strings: [String] = []
    var hasCaptureArg = false
    var endCursor: Int = 0
  }

  private static func collectArguments(
    steps: UnsafePointer<TSQueryPredicateStep>,
    startAt: Int, stepCount: Int, query: OpaquePointer
  ) -> CollectedArgs {
    var result = CollectedArgs()
    var cursor = startAt

    while cursor < stepCount && steps[cursor].type != TSQueryPredicateStepTypeDone {
      if steps[cursor].type == TSQueryPredicateStepTypeCapture {
        result.captureIdx = steps[cursor].value_id
        result.hasCaptureArg = true
      } else if steps[cursor].type == TSQueryPredicateStepTypeString {
        var sLen: UInt32 = 0
        if let sPtr = ts_query_string_value_for_id(query, steps[cursor].value_id, &sLen) {
          result.strings.append(String(cString: sPtr))
        }
      }
      cursor += 1
    }
    result.endCursor = cursor + 1
    return result
  }

  private static func buildPredicate(
    name: String, strings: [String], captureIdx: UInt32
  ) -> QueryPredicate? {
    switch name {
    case "match?", "lua-match?":
      return buildMatchPredicate(strings: strings, captureIdx: captureIdx, negated: false)
    case "not-match?":
      return buildMatchPredicate(strings: strings, captureIdx: captureIdx, negated: true)
    case "eq?":
      guard let value = strings.first else { return nil }
      return .equal(value, captureIndex: captureIdx)
    case "not-eq?":
      guard let value = strings.first else { return nil }
      return .notEqual(value, captureIndex: captureIdx)
    case "any-of?":
      return .anyOf(Set(strings), captureIndex: captureIdx)
    case "not-any-of?":
      return .notAnyOf(Set(strings), captureIndex: captureIdx)
    default:
      return nil
    }
  }

  private static func buildMatchPredicate(
    strings: [String], captureIdx: UInt32, negated: Bool
  ) -> QueryPredicate? {
    guard let pattern = strings.first else { return nil }
    guard let fast = FastMatcher.from(pattern: pattern) else { return nil }
    return negated
      ? .notMatchFast(fast, captureIndex: captureIdx)
      : .matchFast(fast, captureIndex: captureIdx)
  }
}

// MARK: - Predicate Evaluation

extension PredicateEvaluator {

  @inline(always)
  private static func evaluateSingle(
    _ predicate: QueryPredicate,
    captures: UnsafePointer<TSQueryCapture>, captureCount: Int, source: [UInt8]
  ) -> Bool {
    switch predicate {
    case .matchFast(let fast, let captureIndex):
      return evaluateFastMatch(
        fast, captureIndex: captureIndex,
        captures: captures, captureCount: captureCount, source: source)

    case .notMatchFast(let fast, let captureIndex):
      return !evaluateFastMatch(
        fast, captureIndex: captureIndex,
        captures: captures, captureCount: captureCount, source: source)

    case .equal, .notEqual, .anyOf, .notAnyOf:
      return evaluateTextPredicate(
        predicate, captures: captures, captureCount: captureCount, source: source)
    }
  }

  private static func evaluateTextPredicate(
    _ predicate: QueryPredicate,
    captures: UnsafePointer<TSQueryCapture>, captureCount: Int, source: [UInt8]
  ) -> Bool {
    switch predicate {
    case .equal(let value, let captureIndex):
      guard
        let text = textForCapture(
          captureIndex, captures: captures, count: captureCount, source: source)
      else { return false }
      return text == value

    case .notEqual(let value, let captureIndex):
      guard
        let text = textForCapture(
          captureIndex, captures: captures, count: captureCount, source: source)
      else { return false }
      return text != value

    case .anyOf(let set, let captureIndex):
      guard
        let text = textForCapture(
          captureIndex, captures: captures, count: captureCount, source: source)
      else { return false }
      return set.contains(text)

    case .notAnyOf(let set, let captureIndex):
      guard
        let text = textForCapture(
          captureIndex, captures: captures, count: captureCount, source: source)
      else { return false }
      return !set.contains(text)

    default:
      return true
    }
  }

  @inline(always)
  private static func evaluateFastMatch(
    _ fast: FastMatcher, captureIndex: UInt32,
    captures: UnsafePointer<TSQueryCapture>, captureCount: Int, source: [UInt8]
  ) -> Bool {
    guard
      let (start, end) = byteRange(
        for: captureIndex, captures: captures, count: captureCount, source: source)
    else { return false }
    return fast.matches(source: source, start: start, end: end)
  }

}

// MARK: - Capture Helpers

extension PredicateEvaluator {

  @inline(always)
  private static func byteRange(
    for captureIndex: UInt32, captures: UnsafePointer<TSQueryCapture>,
    count: Int, source: [UInt8]
  ) -> (Int, Int)? {
    for idx in 0..<count where captures[idx].index == captureIndex {
      let start = Int(ts_node_start_byte(captures[idx].node))
      let end = Int(ts_node_end_byte(captures[idx].node))
      guard start >= 0, end <= source.count else { return nil }
      return (start, end)
    }
    return nil
  }

  private static func textForCapture(
    _ captureIndex: UInt32, captures: UnsafePointer<TSQueryCapture>,
    count: Int, source: [UInt8]
  ) -> String? {
    guard
      let (start, end) = byteRange(
        for: captureIndex, captures: captures, count: count, source: source)
    else { return nil }
    return String(bytes: source[start..<end], encoding: .utf8)
  }
}
