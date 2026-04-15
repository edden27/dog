/// UtilityBright theme — pre-computed Style values per TokenType.
/// Light-mode counterpart to `UtilityDarkTheme`. Same structure, different palette.
enum UtilityBrightTheme {

  // MARK: - Named styles

  private static let kwBoldItalic = Style(r: 226, g: 83, b: 45, bold: true, italic: true)
  private static let kwBold = Style(r: 226, g: 83, b: 45, bold: true)
  private static let kwItalic = Style(r: 226, g: 83, b: 45, italic: true)
  private static let kwPlain = Style(r: 226, g: 83, b: 45)
  private static let pink = Style(r: 196, g: 89, b: 121)
  private static let fnColor = Style(r: 97, g: 119, b: 99)
  private static let fnBuiltin = Style(r: 97, g: 119, b: 99, italic: true)
  private static let typeBuiltin = Style(r: 97, g: 119, b: 99, bold: true)
  private static let yellow = Style(r: 203, g: 127, b: 33)
  private static let str = Style(r: 29, g: 29, b: 29, italic: true)
  private static let blueItalic = Style(r: 98, g: 120, b: 139, italic: true)
  private static let blue = Style(r: 98, g: 120, b: 139)
  private static let purple = Style(r: 153, g: 96, b: 183)
  private static let red = Style(r: 153, g: 28, b: 23)
  private static let comment = Style(r: 124, g: 120, b: 116)
  private static let punct = Style(r: 43, g: 43, b: 43)
  private static let link = Style(r: 98, g: 120, b: 188)
  private static let base = Style(r: 29, g: 29, b: 29)

  /// Base text style for unhighlighted content.
  static let baseColor: Style = base

  // MARK: - Editor UI colors

  /// editor.foreground — Foreground (1D1D1D)
  static let editorFgStyle: Style? = base

  /// editor.line_number — SubtitleFG (7C7874)
  static let lineNumberStyle: Style? = Style(r: 124, g: 120, b: 116)

  /// editor.active_line_number — Foreground (1D1D1D)
  static let activeLineNumberStyle: Style? = base

  /// editor.gutter.background — GutterBG (DFD5C9)
  static let gutterBgStyle: Style? = Style(r: 223, g: 213, b: 201)

  /// editor.background — ElementBackground (F5EFE8)
  static let editorBgStyle: Style? = Style(r: 245, g: 239, b: 232)

  // MARK: - Help styling

  /// Style for a `--help` output role. Drives `HelpFormatter`.
  static func helpStyle(for role: HelpRole) -> Style {
    switch role {
    case .heading: return kwBold
    case .command: return typeBuiltin
    case .flag: return blue
    case .metavar: return Style(r: 203, g: 127, b: 33, italic: true)
    case .defaultValue: return comment
    case .punctuation: return punct
    case .discussion: return base
    case .dim: return comment
    case .listPrimary: return yellow
    case .listSecondary: return blue
    }
  }

  // MARK: - Lookup

  // Returns the Style for a token type.
  // Switch compiles to a jump table — O(1), zero allocation.
  // swiftlint:disable:next cyclomatic_complexity
  static func color(for token: TokenType) -> Style {
    switch token {
    case .keyword, .keywordFunction, .keywordImport, .keywordType, .keywordDirective,
      .keywordDirectiveDefine, .keywordModifier, .include:
      return kwBoldItalic
    case .keywordConditional, .keywordConditionalTernary, .keywordCoroutine, .keywordException,
      .keywordOperator, .keywordRepeat, .keywordReturn, .conditional, .repeat:
      return kwItalic
    case .stringSpecial, .stringSpecialSymbol, .constantBuiltin:
      return kwPlain
    case .stringEscape, .boolean:
      return pink
    case .function, .functionCall, .functionMethod, .functionMethodCall, .functionSpecial, .method,
      .constructor:
      return fnColor
    case .functionCommand:
      return kwBold
    case .functionBuiltin, .functionMethodBuiltin:
      return fnBuiltin
    case .typeBuiltin, .moduleBuiltin:
      return typeBuiltin
    case .type, .typeDefinition, .constant, .module, .variableParameter, .parameter, .label,
      .functionMacro, .constantMacro, .stringSpecialKey, .tag, .tagBuiltin:
      return yellow
    case .variable:
      return yellow
    case .string, .stringDocumentation, .stringSpecialPath:
      return str
    case .character, .variableBuiltin, .markupQuote:
      return blueItalic
    case .attribute, .tagAttribute, .attributeBuiltin, .variableMember, .field, .property:
      return blue
    case .number, .numberFloat, .float:
      return purple
    case .stringRegex, .stringRegexp, .stringSpecialRegex, .characterSpecial, .error, .tagError,
      .escape:
      return red
    case .comment, .commentDocumentation:
      return comment
    case .punctuationBracket, .punctuationDelimiter, .punctuationSpecial, .delimiter, .operator,
      .embedded, .tagDelimiter:
      return punct
    case .markupLinkLabel, .textReference, .textUri, .stringSpecialUrl:
      return link
    case .markupHeading, .markupHeading1, .markupHeading2, .markupHeading3, .markupHeading4,
      .markupHeading5, .textTitle:
      return kwBoldItalic
    case .markupList:
      return pink
    case .textLiteral:
      return str
    case .markupRawBlock:
      return comment
    case .spell, .nospell, .none, .conceal:
      return base
    }
  }
}
