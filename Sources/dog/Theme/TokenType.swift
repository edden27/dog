/// Maps tree-sitter capture names to known token types for theming.
///
/// All 73 capture names from the 17 v1 language highlight queries are covered.
/// The theme layer assigns a color to each case. Unknown capture names fall
/// back via `from(captureName:)` which tries hierarchical matching
/// (e.g. "function.method" → try exact, fall back to "function").
@usableFromInline
enum TokenType: Int, CaseIterable, Sendable {
  // MARK: - Keywords & Control Flow
  case keyword = 0
  case keywordConditional, keywordConditionalTernary
  case keywordCoroutine, keywordDirective, keywordDirectiveDefine
  case keywordException, keywordFunction, keywordImport
  case keywordModifier, keywordOperator, keywordRepeat
  case keywordReturn, keywordType, conditional, `repeat`, include

  // MARK: - Functions & Methods
  case function, functionBuiltin, functionCall, functionMacro
  case functionMethod, functionMethodBuiltin, functionMethodCall
  case functionSpecial, functionCommand, method, constructor

  // MARK: - Types
  case type, typeBuiltin, typeDefinition

  // MARK: - Variables & Parameters
  case variable, variableBuiltin, variableMember, variableParameter
  case parameter, field, property, label

  // MARK: - Modules
  case module, moduleBuiltin

  // MARK: - Literals
  case string, stringDocumentation, stringEscape, stringRegex
  case stringRegexp, stringSpecial, stringSpecialKey, stringSpecialPath
  case stringSpecialRegex, stringSpecialSymbol, stringSpecialUrl
  case character, characterSpecial
  case number, numberFloat, float, boolean
  case constant, constantBuiltin, constantMacro

  // MARK: - Punctuation
  case punctuationBracket, punctuationDelimiter, punctuationSpecial
  case delimiter, `operator`

  // MARK: - Markup
  case markupHeading, markupHeading1, markupHeading2, markupHeading3
  case markupHeading4, markupHeading5, markupLinkLabel, markupList
  case markupQuote, markupRawBlock

  // MARK: - Tags & Attributes
  case tag, tagAttribute, tagBuiltin, tagDelimiter, tagError
  case attribute, attributeBuiltin

  // MARK: - Text
  case textLiteral, textTitle, textReference, textUri
  case spell, nospell, none, conceal

  // MARK: - Other
  case comment, commentDocumentation, escape, embedded, error

  // MARK: - Lookup

  /// Capture name → TokenType dictionary (built once).
  private static let nameMap: [String: TokenType] = {
    let pairs: [(String, TokenType)] = [
      ("keyword", .keyword), ("keyword.conditional", .keywordConditional),
      ("keyword.conditional.ternary", .keywordConditionalTernary),
      ("keyword.coroutine", .keywordCoroutine), ("keyword.directive", .keywordDirective),
      ("keyword.directive.define", .keywordDirectiveDefine),
      ("keyword.exception", .keywordException), ("keyword.function", .keywordFunction),
      ("keyword.import", .keywordImport), ("keyword.modifier", .keywordModifier),
      ("keyword.operator", .keywordOperator), ("keyword.repeat", .keywordRepeat),
      ("keyword.return", .keywordReturn), ("keyword.type", .keywordType),
      ("conditional", .conditional), ("repeat", .repeat), ("include", .include),
      ("function", .function), ("function.builtin", .functionBuiltin),
      ("function.call", .functionCall), ("function.macro", .functionMacro),
      ("function.method", .functionMethod), ("function.method.builtin", .functionMethodBuiltin),
      ("function.method.call", .functionMethodCall), ("function.special", .functionSpecial),
      ("function.command", .functionCommand),
      ("method", .method), ("constructor", .constructor),
      ("type", .type), ("type.builtin", .typeBuiltin), ("type.definition", .typeDefinition),
      ("variable", .variable), ("variable.builtin", .variableBuiltin),
      ("variable.member", .variableMember), ("variable.parameter", .variableParameter),
      ("parameter", .parameter), ("field", .field), ("property", .property), ("label", .label),
      ("module", .module), ("module.builtin", .moduleBuiltin),
      ("string", .string), ("string.documentation", .stringDocumentation),
      ("string.escape", .stringEscape), ("string.regex", .stringRegex),
      ("string.regexp", .stringRegexp), ("string.special", .stringSpecial),
      ("string.special.key", .stringSpecialKey), ("string.special.path", .stringSpecialPath),
      ("string.special.regex", .stringSpecialRegex),
      ("string.special.symbol", .stringSpecialSymbol),
      ("string.special.url", .stringSpecialUrl),
      ("character", .character), ("character.special", .characterSpecial),
      ("number", .number), ("number.float", .numberFloat), ("float", .float),
      ("boolean", .boolean),
      ("constant", .constant), ("constant.builtin", .constantBuiltin),
      ("constant.macro", .constantMacro),
      ("punctuation.bracket", .punctuationBracket),
      ("punctuation.delimiter", .punctuationDelimiter),
      ("punctuation.special", .punctuationSpecial), ("delimiter", .delimiter),
      ("operator", .operator),
      ("markup.heading", .markupHeading), ("markup.heading.1", .markupHeading1),
      ("markup.heading.2", .markupHeading2), ("markup.heading.3", .markupHeading3),
      ("markup.heading.4", .markupHeading4), ("markup.heading.5", .markupHeading5),
      ("markup.link.label", .markupLinkLabel), ("markup.list", .markupList),
      ("markup.quote", .markupQuote), ("markup.raw.block", .markupRawBlock),
      ("tag", .tag), ("tag.attribute", .tagAttribute), ("tag.builtin", .tagBuiltin),
      ("tag.delimiter", .tagDelimiter), ("tag.error", .tagError),
      ("attribute", .attribute), ("attribute.builtin", .attributeBuiltin),
      ("text.literal", .textLiteral), ("text.title", .textTitle),
      ("text.reference", .textReference), ("text.uri", .textUri),
      ("spell", .spell), ("nospell", .nospell), ("none", TokenType.none), ("conceal", .conceal),
      ("comment", .comment), ("comment.documentation", .commentDocumentation),
      ("escape", .escape), ("embedded", .embedded), ("error", .error),
    ]
    return Dictionary(uniqueKeysWithValues: pairs)
  }()

  /// Resolve a tree-sitter capture name to a token type.
  ///
  /// Tries exact match first, then falls back to the base name
  /// (e.g. "string.special.key" → "string.special" → "string").
  static func from(captureName: String) -> TokenType? {
    if let exact = nameMap[captureName] { return exact }

    // Hierarchical fallback: strip last component and retry
    var name = captureName
    while let dotIndex = name.lastIndex(of: ".") {
      name = String(name[name.startIndex..<dotIndex])
      if let match = nameMap[name] { return match }
    }

    return nil
  }

  /// Exact-only lookup with no hierarchical fallback. Callers that need to
  /// distinguish "this scope is a known token" from "we matched a parent"
  /// must use this — `from(captureName:)` swallows that distinction.
  static func exact(captureName: String) -> TokenType? {
    nameMap[captureName]
  }

  /// Reverse lookup: TokenType → capture name string.
  /// Built once lazily from `nameMap`.
  private static let reverseMap: [TokenType: String] = {
    var map = [TokenType: String]()
    map.reserveCapacity(nameMap.count)
    for (name, tokenType) in nameMap {
      // Prefer the longest (most specific) name for each token type
      if let existing = map[tokenType], existing.count > name.count {
        continue
      }
      map[tokenType] = name
    }
    return map
  }()

  /// The capture name string for this token type, if one exists.
  var captureName: String? {
    Self.reverseMap[self]
  }
}
