import Testing

@testable import dog

// Helper: match a string against a FastMatcher using the full source buffer
private func match(_ matcher: FastMatcher, _ string: String) -> Bool {
  let source = Array(string.utf8)
  return matcher.matches(source: source, start: 0, end: source.count)
}

// Helper: match a substring within a larger buffer (verifies offset handling)
private func matchWithOffset(_ matcher: FastMatcher, source: String, token: String) -> Bool {
  let sourceBytes = Array(source.utf8)
  let tokenBytes = Array(token.utf8)
  guard let start = sourceBytes.firstRange(of: tokenBytes)?.lowerBound else { return false }
  let startIdx = sourceBytes.distance(from: sourceBytes.startIndex, to: start)
  return matcher.matches(source: sourceBytes, start: startIdx, end: startIdx + tokenBytes.count)
}

@Suite("FastMatcher")
struct FastMatcherTests {

  // MARK: - from(pattern:)

  @Suite("from(pattern:)")
  struct FromPattern {

    @Test("known patterns resolve to expected cases", arguments: [
      ("^[A-Z]", FastMatcher.startsUppercase),
      ("^[[A-Z]]", FastMatcher.startsUppercase),
      ("^[A-Z][A-Z_0-9]*$", FastMatcher.allCapsConstant),
      ("^[A-Z][A-Z[0-9]_]*$", FastMatcher.allCapsConstant),
      ("^_*[A-Z][A-Z[0-9]_]*$", FastMatcher.allCapsConstant),
      ("^[A-Z][A-Z0-9_]+$", FastMatcher.allCapsConstant),
      ("^[[a-z]_].*$", FastMatcher.startsLowerOrUnderscore),
      ("^[a-z]", FastMatcher.startsLowerOrUnderscore),
      ("^[a-zA-Z_][a-zA-Z0-9_]*$", FastMatcher.startsLowerOrUnderscore),
      ("^__[a-zA-Z0-9_]*__$", FastMatcher.dunder),
      ("^#!/", FastMatcher.shebang),
      ("^#![ \t]*/", FastMatcher.shebang),
      ("^--", FastMatcher.doubleDash),
      ("^///$", FastMatcher.tripleSlashExact),
      ("^///[^/]", FastMatcher.tripleSlashContent),
      ("^[A-Z].*[a-z]", FastMatcher.mixedCase)
    ] as [(String, FastMatcher)])
    func knownPatterns(pattern: String, expected: FastMatcher) {
      #expect(FastMatcher.from(pattern: pattern) == expected)
    }

    @Test("new patterns resolve to expected cases", arguments: [
      ("^[-][-][-]", FastMatcher.tripleDash),
      ("^__builtin_", FastMatcher.builtinPrefix),
      ("^[-][-](%s?)@", FastMatcher.luaAnnotation),
      ("^[nN]ew.+$", FastMatcher.startsNewOrMake),
      ("^[mM]ake.+$", FastMatcher.startsNewOrMake),
      ("^/[*][*][^*].*[*]/$", FastMatcher.docCommentBlock),
      ("^m_.*$", FastMatcher.memberPrefix),
      ("^[A-Z0-9_]+$", FastMatcher.onlyCapsDigitsUnderscores)
    ] as [(String, FastMatcher)])
    func newPatterns(pattern: String, expected: FastMatcher) {
      #expect(FastMatcher.from(pattern: pattern) == expected)
    }

    @Test("unknown pattern returns nil")
    func unknownPattern() {
      #expect(FastMatcher.from(pattern: "^[0-9]+$") == nil)
      #expect(FastMatcher.from(pattern: "") == nil)
      #expect(FastMatcher.from(pattern: "^something_else") == nil)
    }
  }

  // MARK: - startsUppercase

  @Suite("startsUppercase")
  struct StartsUppercase {
    @Test("matches uppercase first byte", arguments: ["A", "Z", "MyClass", "Hello", "T"])
    func matches(input: String) { #expect(match(.startsUppercase, input)) }

    @Test("rejects lowercase, digit, symbol first byte", arguments: ["a", "z", "1", "_Foo", "myVar", ""])
    func rejects(input: String) { #expect(!match(.startsUppercase, input)) }
  }

  // MARK: - allCapsConstant

  @Suite("allCapsConstant")
  struct AllCapsConstant {
    @Test("matches ALL_CAPS identifiers", arguments: ["MAX", "MAX_SIZE", "HTTP2_OK", "A", "Z9_"])
    func matches(input: String) { #expect(match(.allCapsConstant, input)) }

    @Test("rejects mixed or lowercase", arguments: ["MyClass", "max_size", "Http", "lower", "MAX_size", "_MAX"])
    func rejects(input: String) { #expect(!match(.allCapsConstant, input)) }

    @Test("rejects digit-first identifier")
    func rejectsDigitFirst() { #expect(!match(.allCapsConstant, "1MAX")) }
  }

  // MARK: - onlyCapsDigitsUnderscores

  @Suite("onlyCapsDigitsUnderscores")
  struct OnlyCapsDigitsUnderscores {
    @Test("matches caps, digits, underscores in any order", arguments: ["MAX", "MAX_SIZE", "_MAX", "1MAX", "A", "__"])
    func matches(input: String) { #expect(match(.onlyCapsDigitsUnderscores, input)) }

    @Test("rejects any lowercase or other byte", arguments: ["MyClass", "Foo", "MAX_size", "A-B", ""])
    func rejects(input: String) { #expect(!match(.onlyCapsDigitsUnderscores, input)) }
  }

  // MARK: - startsLowerOrUnderscore

  @Suite("startsLowerOrUnderscore")
  struct StartsLowerOrUnderscore {
    @Test("matches lowercase or underscore start", arguments: ["myVar", "a", "_private", "__x", "_"])
    func matches(input: String) { #expect(match(.startsLowerOrUnderscore, input)) }

    @Test("rejects uppercase or digit start", arguments: ["MyClass", "A", "1foo", ""])
    func rejects(input: String) { #expect(!match(.startsLowerOrUnderscore, input)) }
  }

  // MARK: - dunder

  @Suite("dunder")
  struct Dunder {
    @Test("matches __dunder__ pattern", arguments: ["__init__", "__name__", "__x__", "____"])
    func matches(input: String) { #expect(match(.dunder, input)) }

    @Test("rejects non-dunder", arguments: ["__init", "init__", "_init_", "__", "___", "normal"])
    func rejects(input: String) { #expect(!match(.dunder, input)) }

    @Test("matches when dunder wraps inner content with more underscores")
    func innerUnderscores() { #expect(match(.dunder, "__a__b__")) }

    @Test("rejects single underscore bookends")
    func singleBookends() { #expect(!match(.dunder, "_x_")) }
  }

  // MARK: - shebang

  @Suite("shebang")
  struct Shebang {
    @Test("matches shebang prefix", arguments: ["#!/usr/bin/env python", "#!", "#!/"])
    func matches(input: String) { #expect(match(.shebang, input)) }

    @Test("rejects non-shebang", arguments: ["# comment", "#x", "!", "/usr/bin", ""])
    func rejects(input: String) { #expect(!match(.shebang, input)) }
  }

  // MARK: - doubleDash

  @Suite("doubleDash")
  struct DoubleDash {
    @Test("matches -- prefix", arguments: ["--", "-- comment", "---", "--long-flag"])
    func matches(input: String) { #expect(match(.doubleDash, input)) }

    @Test("rejects single dash or no dash", arguments: ["-", "- comment", "x--", "comment", ""])
    func rejects(input: String) { #expect(!match(.doubleDash, input)) }
  }

  // MARK: - tripleSlashExact

  @Suite("tripleSlashExact")
  struct TripleSlashExact {
    @Test("matches exactly ///")
    func matchesExact() { #expect(match(.tripleSlashExact, "///")) }

    @Test("rejects anything else", arguments: ["////", "/// comment", "//", "/", "// /", ""])
    func rejects(input: String) { #expect(!match(.tripleSlashExact, input)) }
  }

  // MARK: - tripleSlashContent

  @Suite("tripleSlashContent")
  struct TripleSlashContent {
    @Test("matches /// followed by non-slash", arguments: ["/// comment", "///x", "/// ", "///\t"])
    func matches(input: String) { #expect(match(.tripleSlashContent, input)) }

    @Test("rejects //// or short strings", arguments: ["////", "///", "//", "/", ""])
    func rejects(input: String) { #expect(!match(.tripleSlashContent, input)) }
  }

  // MARK: - mixedCase

  @Suite("mixedCase")
  struct MixedCase {
    @Test("matches uppercase start with lowercase somewhere", arguments: ["MyClass", "Hello", "Ab", "XMLParser", "Abc"])
    func matches(input: String) { #expect(match(.mixedCase, input)) }

    @Test("rejects all-caps, all-lower, or digit start", arguments: ["ALLCAPS", "lowercase", "A", "ABC", "1Foo", ""])
    func rejects(input: String) { #expect(!match(.mixedCase, input)) }
  }

  // MARK: - tripleDash

  @Suite("tripleDash")
  struct TripleDash {
    @Test("matches --- prefix", arguments: ["---", "---- ", "---x"])
    func matches(input: String) { #expect(match(.tripleDash, input)) }

    @Test("rejects -- or fewer dashes", arguments: ["--", "-", "x---", ""])
    func rejects(input: String) { #expect(!match(.tripleDash, input)) }
  }

  // MARK: - builtinPrefix

  @Suite("builtinPrefix")
  struct BuiltinPrefix {
    @Test("matches __builtin_ prefix", arguments: ["__builtin_expect", "__builtin_clz", "__builtin_trap", "__builtin_"])
    func matches(input: String) { #expect(match(.builtinPrefix, input)) }

    @Test("rejects non-builtin", arguments: ["__builtin", "__built", "_builtin_x", "builtin_x", "__other_", ""])
    func rejects(input: String) { #expect(!match(.builtinPrefix, input)) }
  }

  // MARK: - luaAnnotation

  @Suite("luaAnnotation")
  struct LuaAnnotation {
    @Test("matches --@ and -- @ with spaces/tabs", arguments: ["--@", "-- @", "--\t@", "--  @"])
    func matches(input: String) { #expect(match(.luaAnnotation, input)) }

    @Test("rejects missing @ or too short", arguments: ["--x", "-@", "--", "- @", "x--@", ""])
    func rejects(input: String) { #expect(!match(.luaAnnotation, input)) }

    @Test("matches mixed whitespace before @")
    func mixedWhitespace() { #expect(match(.luaAnnotation, "-- \t@")) }

    @Test("rejects @ not present after whitespace")
    func noAt() { #expect(!match(.luaAnnotation, "--  x")) }
  }

  // MARK: - startsNewOrMake

  @Suite("startsNewOrMake")
  struct StartsNewOrMake {
    @Test("matches new/New/make/Make with more chars",
      arguments: ["newFoo", "NewFoo", "makeBar", "MakeBar", "newX", "NewX"])
    func matches(input: String) { #expect(match(.startsNewOrMake, input)) }

    @Test("rejects bare new/make or wrong case",
      arguments: ["new", "New", "make", "Make", "mak", "nex", "nEw", "mAke", ""])
    func rejects(input: String) { #expect(!match(.startsNewOrMake, input)) }

    @Test("make requires 5+ chars total")
    func makeMinLength() {
      #expect(!match(.startsNewOrMake, "make"))
      #expect(match(.startsNewOrMake, "makeX"))
    }

    @Test("new requires 4+ chars total")
    func newMinLength() {
      #expect(!match(.startsNewOrMake, "new"))
      #expect(match(.startsNewOrMake, "newX"))
    }

    @Test("rejects wrong second/third letter", arguments: ["NEwFoo", "nEwFoo", "MAkeFoo", "mAkeFoo"])
    func rejectsWrongInternalCase(input: String) { #expect(!match(.startsNewOrMake, input)) }
  }

  // MARK: - docCommentBlock

  @Suite("docCommentBlock")
  struct DocCommentBlock {
    @Test("matches /** ... */ doc comments",
      arguments: ["/** foo */", "/**x*/", "/** a */", "/** multi word */"])
    func matches(input: String) { #expect(match(.docCommentBlock, input)) }

    @Test("rejects /*** or non-doc or missing close",
      arguments: ["/***x*/", "/* foo */", "/** foo *", "/** foo /", "/**x/", ""])
    func rejects(input: String) { #expect(!match(.docCommentBlock, input)) }

    @Test("rejects /***/  — 4th byte is * so it's /***/ not /**x*/")
    func rejectsTripleStar() { #expect(!match(.docCommentBlock, "/***/")) }

    @Test("minimum valid is /**x*/ at 6 chars")
    func minLength() { #expect(match(.docCommentBlock, "/**x*/")) }

    @Test("rejects /* */ — only two stars at open")
    func rejectsTwoStar() { #expect(!match(.docCommentBlock, "/* x */")) }

    @Test("end must be */ not just /")
    func rejectsMissingStarAtEnd() { #expect(!match(.docCommentBlock, "/**x/")) }
  }

  // MARK: - memberPrefix

  @Suite("memberPrefix")
  struct MemberPrefix {
    @Test("matches m_ prefix", arguments: ["m_name", "m_value", "m_x", "m_"])
    func matches(input: String) { #expect(match(.memberPrefix, input)) }

    @Test("rejects non m_ prefix", arguments: ["n_name", "_name", "mx_", "M_name", ""])
    func rejects(input: String) { #expect(!match(.memberPrefix, input)) }

    @Test("rejects bare m with no underscore")
    func rejectsBareM() { #expect(!match(.memberPrefix, "m")) }
  }

  // MARK: - Offset correctness

  @Test("matches correct token within larger source buffer")
  func offsetCorrectness() {
    #expect(matchWithOffset(.startsUppercase, source: "let MyClass = 1", token: "MyClass"))
    #expect(matchWithOffset(.doubleDash, source: "x = 1 -- comment", token: "-- comment"))
    #expect(matchWithOffset(.tripleSlashContent, source: "let x = 1\n/// doc\n", token: "/// doc"))
    #expect(matchWithOffset(.dunder, source: "def __init__(self):", token: "__init__"))
    #expect(matchWithOffset(.tripleDash, source: "x = 1 --- y", token: "--- y"))
    #expect(matchWithOffset(.builtinPrefix, source: "x = __builtin_expect(y, 1)", token: "__builtin_expect"))
    #expect(matchWithOffset(.luaAnnotation, source: "local x --@type string", token: "--@type"))
    #expect(matchWithOffset(.docCommentBlock, source: "int x; /** doc */ int y;", token: "/** doc */"))
    #expect(matchWithOffset(.memberPrefix, source: "this.m_value = 1", token: "m_value"))
    #expect(!matchWithOffset(.startsUppercase, source: "let myVar = 1", token: "myVar"))
  }

  // MARK: - Empty and single-byte edge cases

  @Test("empty range returns false for all matchers")
  func emptyRange() {
    let source: [UInt8] = [0x41]  // 'A'
    for matcher in FastMatcher.allCases {
      #expect(!matcher.matches(source: source, start: 0, end: 0))
    }
  }
}

extension FastMatcher: CaseIterable {
  public static var allCases: [FastMatcher] {
    [.startsUppercase, .allCapsConstant, .onlyCapsDigitsUnderscores, .startsLowerOrUnderscore,
     .dunder, .shebang, .doubleDash, .tripleDash,
     .tripleSlashExact, .tripleSlashContent, .mixedCase,
     .builtinPrefix, .luaAnnotation, .startsNewOrMake, .docCommentBlock, .memberPrefix]
  }
}
