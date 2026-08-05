/// UtilityDark theme — pre-computed Style values per TokenType.
enum UtilityDarkTheme {

  // MARK: - Named styles

  private static let keywordBoldItalic = Style(
    red: 238, green: 110, blue: 57, bold: true, italic: true)
  private static let keywordBold = Style(red: 238, green: 110, blue: 57, bold: true)
  private static let keywordItalic = Style(red: 238, green: 110, blue: 57, italic: true)
  private static let keywordPlain = Style(red: 238, green: 110, blue: 57)
  private static let pink = Style(red: 227, green: 132, blue: 167)
  private static let functionColor = Style(red: 129, green: 159, blue: 132)
  private static let functionBuiltin = Style(red: 129, green: 159, blue: 132, italic: true)
  private static let typeBuiltin = Style(red: 129, green: 159, blue: 132, bold: true)
  private static let yellow = Style(red: 232, green: 166, blue: 85)
  private static let string = Style(red: 205, green: 190, blue: 171, italic: true)
  private static let blueItalic = Style(red: 158, green: 178, blue: 201, italic: true)
  private static let blue = Style(red: 158, green: 178, blue: 201)
  private static let purple = Style(red: 207, green: 149, blue: 249)
  private static let red = Style(red: 204, green: 67, blue: 61)
  private static let comment = Style(red: 129, green: 116, blue: 100)
  private static let punctuation = Style(red: 217, green: 217, blue: 217)
  private static let link = Style(red: 39, green: 112, blue: 189)
  private static let base = Style(red: 205, green: 190, blue: 171)

  /// Base text style for unhighlighted content.
  static let baseColor: Style = base

  // MARK: - Editor UI colors

  /// editor.foreground — Foreground (CDBEAB)
  static let editorFgStyle: Style? = base

  /// editor.line_number — SubtitleFG (817464)
  static let lineNumberStyle: Style? = Style(red: 129, green: 116, blue: 100)

  /// editor.active_line_number — Foreground (CDBEAB)
  static let activeLineNumberStyle: Style? = base

  /// editor.gutter.background — BlackMainBG (1D1D1D)
  static let gutterBgStyle: Style? = Style(red: 29, green: 29, blue: 29)

  /// editor.background — ElementBackground (2B2B2B)
  static let editorBgStyle: Style? = Style(red: 43, green: 43, blue: 43)

  // MARK: - Help styling

  /// Style for a `--help` output role. Drives `HelpFormatter`.
  static func helpStyle(for role: HelpRole) -> Style {
    switch role {
    case .heading: return keywordBold
    case .command: return typeBuiltin
    case .flag: return blue
    case .metavar: return Style(red: 232, green: 166, blue: 85, italic: true)
    case .defaultValue: return comment
    case .punctuation: return punctuation
    case .discussion: return base
    case .dim: return comment
    case .listPrimary: return yellow
    case .listSecondary: return blue
    }
  }

  // MARK: - Lookup

  // Returns the Style for a token type.
  // Switch compiles to a jump table — O(1), zero allocation.
  // swiftlint:disable:next function_body_length
  static func color(for token: TokenType) -> Style {
    switch token {
    case .keyword, .keywordFunction, .keywordImport, .keywordType, .keywordDirective,
      .keywordDirectiveDefine, .keywordModifier, .include:
      return keywordBoldItalic
    case .keywordConditional, .keywordConditionalTernary, .keywordCoroutine, .keywordException,
      .keywordOperator, .keywordRepeat, .keywordReturn, .conditional, .repeat:
      return keywordItalic
    case .stringSpecial, .stringSpecialSymbol, .constantBuiltin:
      return keywordPlain
    case .stringEscape, .boolean:
      return pink
    case .function, .functionCall, .functionMethod, .functionMethodCall, .functionSpecial, .method,
      .constructor:
      return functionColor
    case .functionCommand:
      return keywordBold
    case .functionBuiltin, .functionMethodBuiltin:
      return functionBuiltin
    case .typeBuiltin, .moduleBuiltin:
      return typeBuiltin
    case .type, .typeDefinition, .constant, .module, .variableParameter, .parameter, .label,
      .functionMacro, .constantMacro, .stringSpecialKey, .tag, .tagBuiltin:
      return yellow
    case .variable:
      return yellow
    case .string, .stringDocumentation, .stringSpecialPath:
      return string
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
      return punctuation
    case .markupLinkLabel, .textReference, .textUri, .stringSpecialUrl:
      return link
    case .markupHeading, .markupHeading1, .markupHeading2, .markupHeading3, .markupHeading4,
      .markupHeading5, .textTitle:
      return keywordBoldItalic
    case .markupList:
      return pink
    case .textLiteral:
      return string
    case .markupRawBlock:
      return comment
    case .spell, .nospell, .none, .conceal:
      return base
    }
  }
}
