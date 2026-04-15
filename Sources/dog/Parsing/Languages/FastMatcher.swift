/// Byte-level pattern matchers for tree-sitter query predicates like `^[A-Z]`.
///
/// These operate directly on `[UInt8]` source bytes — no String conversion,
/// no regex engine, no allocations.
enum FastMatcher {
  case startsUppercase
  case allCapsConstant
  case startsLowerOrUnderscore
  case dunder
  case shebang
  case doubleDash
  case tripleDash
  case tripleSlashExact
  case tripleSlashContent
  case mixedCase
  case builtinPrefix
  case luaAnnotation
  case startsNewOrMake
  case docCommentBlock
  case memberPrefix

  @inline(always)
  func matches(source: [UInt8], start: Int, end: Int) -> Bool {
    guard start < end else { return false }
    switch self {
    case .startsUppercase:
      return isUpperASCII(source[start])
    case .allCapsConstant:
      return matchesAllCaps(source: source, start: start, end: end)
    case .startsLowerOrUnderscore:
      return isLowerASCII(source[start]) || source[start] == 0x5F
    case .dunder:
      return matchesDunder(source: source, start: start, end: end)
    case .shebang:
      return matchesShebang(source: source, start: start, end: end)
    case .doubleDash:
      return end - start >= 2 && source[start] == 0x2D && source[start + 1] == 0x2D
    case .tripleSlashExact:
      return end - start == 3 && source[start] == 0x2F && source[start + 1] == 0x2F
        && source[start + 2] == 0x2F
    case .tripleSlashContent:
      return end - start >= 4 && source[start] == 0x2F && source[start + 1] == 0x2F
        && source[start + 2] == 0x2F && source[start + 3] != 0x2F
    case .mixedCase:
      return matchesMixedCase(source: source, start: start, end: end)
    case .tripleDash:
      return end - start >= 3 && source[start] == 0x2D && source[start + 1] == 0x2D
        && source[start + 2] == 0x2D
    case .builtinPrefix:
      return matchesPrefix(source: source, start: start, end: end, prefix: Self.builtinBytes)
    case .luaAnnotation:
      return matchesLuaAnnotation(source: source, start: start, end: end)
    case .startsNewOrMake:
      return matchesNewOrMake(source: source, start: start, end: end)
    case .docCommentBlock:
      return matchesDocCommentBlock(source: source, start: start, end: end)
    case .memberPrefix:
      return end - start >= 2 && source[start] == 0x6D && source[start + 1] == 0x5F
    }
  }

  /// Try to compile a regex pattern string into a fast matcher.
  /// Returns nil for patterns that need real regex.
  static func from(pattern: String) -> FastMatcher? {
    switch pattern {
    case "^[A-Z]", "^[[A-Z]]":
      return .startsUppercase
    case "^[A-Z][A-Z_0-9]*$", "^[A-Z][A-Z[0-9]_]*$", "^_*[A-Z][A-Z[0-9]_]*$",
      "^[A-Z][A-Z0-9_]+$":
      return .allCapsConstant
    case "^[[a-z]_].*$", "^[a-z]", "^[a-zA-Z_][a-zA-Z0-9_]*$":
      return .startsLowerOrUnderscore
    case "^__[a-zA-Z0-9_]*__$":
      return .dunder
    case "^#!/", "^#![ \\t]*/":
      return .shebang
    case "^--":
      return .doubleDash
    case "^///$":
      return .tripleSlashExact
    case "^///[^/]":
      return .tripleSlashContent
    case "^[A-Z].*[a-z]":
      return .mixedCase
    case "^[-][-][-]":
      return .tripleDash
    case "^__builtin_":
      return .builtinPrefix
    case "^[-][-](%s?)@":
      return .luaAnnotation
    case "^[nN]ew.+$", "^[mM]ake.+$":
      return .startsNewOrMake
    case "^/[*][*][^*].*[*]/$":
      return .docCommentBlock
    case "^m_.*$":
      return .memberPrefix
    default:
      return nil
    }
  }

  // MARK: - Private

  private func isUpperASCII(_ byte: UInt8) -> Bool {
    byte >= 0x41 && byte <= 0x5A
  }

  private func isLowerASCII(_ byte: UInt8) -> Bool {
    byte >= 0x61 && byte <= 0x7A
  }

  private func matchesAllCaps(source: [UInt8], start: Int, end: Int) -> Bool {
    guard isUpperASCII(source[start]) else { return false }
    for offset in (start + 1)..<end {
      let byte = source[offset]
      let isValid = isUpperASCII(byte) || (byte >= 0x30 && byte <= 0x39) || byte == 0x5F
      if !isValid { return false }
    }
    return true
  }

  private func matchesDunder(source: [UInt8], start: Int, end: Int) -> Bool {
    let len = end - start
    guard len >= 4 else { return false }
    return source[start] == 0x5F && source[start + 1] == 0x5F
      && source[end - 1] == 0x5F && source[end - 2] == 0x5F
  }

  private func matchesShebang(source: [UInt8], start: Int, end: Int) -> Bool {
    guard end - start >= 2 else { return false }
    return source[start] == 0x23 && source[start + 1] == 0x21
  }

  private func matchesMixedCase(source: [UInt8], start: Int, end: Int) -> Bool {
    guard isUpperASCII(source[start]) else { return false }
    for offset in (start + 1)..<end where isLowerASCII(source[offset]) {
      return true
    }
    return false
  }

  // __builtin_ as bytes
  private static let builtinBytes: [UInt8] = Array("__builtin_".utf8)

  private func matchesPrefix(
    source: [UInt8], start: Int, end: Int, prefix: [UInt8]
  ) -> Bool {
    guard end - start >= prefix.count else { return false }
    return source[start..<(start + prefix.count)].elementsEqual(prefix)
  }

  // ^[-][-](%s?)@ — two dashes, optional whitespace, then @
  private func matchesLuaAnnotation(source: [UInt8], start: Int, end: Int) -> Bool {
    guard end - start >= 3, source[start] == 0x2D, source[start + 1] == 0x2D else { return false }
    var idx = start + 2
    // skip optional whitespace
    while idx < end && (source[idx] == 0x20 || source[idx] == 0x09) { idx += 1 }
    return idx < end && source[idx] == 0x40  // @
  }

  // ^[nN]ew.+$ or ^[mM]ake.+$ — starts with new/New/make/Make, has more chars
  private func matchesNewOrMake(source: [UInt8], start: Int, end: Int) -> Bool {
    let len = end - start
    guard len >= 4 else { return false }
    let first = source[start]
    let second = source[start + 1]
    let third = source[start + 2]
    let fourth = source[start + 3]
    // new or New — len >= 4 already ensures there's content after "new"
    if (first == 0x6E || first == 0x4E) && second == 0x65 && third == 0x77 { return true }
    // make or Make — needs 5+ chars
    if len >= 5 && (first == 0x6D || first == 0x4D) && second == 0x61 && third == 0x6B
      && fourth == 0x65
    {
      return true
    }
    return false
  }

  // ^/[*][*][^*].*[*]/$ — starts with /**, not /***, ends with */
  private func matchesDocCommentBlock(source: [UInt8], start: Int, end: Int) -> Bool {
    let len = end - start
    guard len >= 5 else { return false }  // /** + */ minimum
    guard source[start] == 0x2F,  // /
      source[start + 1] == 0x2A,  // *
      source[start + 2] == 0x2A,  // *
      source[start + 3] != 0x2A,  // not *
      source[end - 1] == 0x2F,  // /
      source[end - 2] == 0x2A  // *
    else { return false }
    return true
  }
}
