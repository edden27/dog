/// UtilityDark theme — pre-computed Style values per TokenType.
enum UtilityDarkTheme {

  // MARK: - Named styles

  private static let kwBoldItalic = Style(r: 238, g: 110, b: 57, bold: true, italic: true)
  private static let kwBold = Style(r: 238, g: 110, b: 57, bold: true)
  private static let kwItalic = Style(r: 238, g: 110, b: 57, italic: true)
  private static let kwPlain = Style(r: 238, g: 110, b: 57)
  private static let pink = Style(r: 227, g: 132, b: 167)
  private static let fnColor = Style(r: 129, g: 159, b: 132)
  private static let fnBuiltin = Style(r: 129, g: 159, b: 132, italic: true)
  private static let typeBuiltin = Style(r: 129, g: 159, b: 132, bold: true)
  private static let yellow = Style(r: 232, g: 166, b: 85)
  private static let str = Style(r: 205, g: 190, b: 171, italic: true)
  private static let blueItalic = Style(r: 158, g: 178, b: 201, italic: true)
  private static let blue = Style(r: 158, g: 178, b: 201)
  private static let purple = Style(r: 207, g: 149, b: 249)
  private static let red = Style(r: 204, g: 67, b: 61)
  private static let comment = Style(r: 129, g: 116, b: 100)
  private static let punct = Style(r: 217, g: 217, b: 217)
  private static let link = Style(r: 39, g: 112, b: 189)
  private static let base = Style(r: 205, g: 190, b: 171)

  /// Base text style for unhighlighted content.
  static let baseColor: Style = base

  // MARK: - Editor UI colors

  /// editor.foreground — Foreground (CDBEAB)
  static let editorFgStyle: Style? = base

  /// editor.line_number — SubtitleFG (817464)
  static let lineNumberStyle: Style? = Style(r: 129, g: 116, b: 100)

  /// editor.active_line_number — Foreground (CDBEAB)
  static let activeLineNumberStyle: Style? = base

  /// editor.gutter.background — BlackMainBG (1D1D1D)
  static let gutterBgStyle: Style? = Style(r: 29, g: 29, b: 29)

  /// editor.background — ElementBackground (2B2B2B)
  static let editorBgStyle: Style? = Style(r: 43, g: 43, b: 43)

  // MARK: - Help styling

  /// Style for a `--help` output role. Drives `HelpFormatter`.
  static func helpStyle(for role: HelpRole) -> Style {
    switch role {
    case .heading: return kwBold
    case .command: return typeBuiltin
    case .flag: return blue
    case .metavar: return Style(r: 232, g: 166, b: 85, italic: true)
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
