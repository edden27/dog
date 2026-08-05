/// UtilityBright theme — pre-computed Style values per TokenType.
/// Light-mode counterpart to `UtilityDarkTheme`. Same structure, different palette.
enum UtilityBrightTheme {

  // MARK: - Named styles

  private static let keywordBoldItalic = Style(
    red: 226, green: 83, blue: 45, bold: true, italic: true)
  private static let keywordBold = Style(red: 226, green: 83, blue: 45, bold: true)
  private static let keywordItalic = Style(red: 226, green: 83, blue: 45, italic: true)
  private static let keywordPlain = Style(red: 226, green: 83, blue: 45)
  private static let pink = Style(red: 196, green: 89, blue: 121)
  private static let functionColor = Style(red: 97, green: 119, blue: 99)
  private static let functionBuiltin = Style(red: 97, green: 119, blue: 99, italic: true)
  private static let typeBuiltin = Style(red: 97, green: 119, blue: 99, bold: true)
  private static let yellow = Style(red: 203, green: 127, blue: 33)
  private static let string = Style(red: 29, green: 29, blue: 29, italic: true)
  private static let blueItalic = Style(red: 98, green: 120, blue: 139, italic: true)
  private static let blue = Style(red: 98, green: 120, blue: 139)
  private static let purple = Style(red: 153, green: 96, blue: 183)
  private static let red = Style(red: 153, green: 28, blue: 23)
  private static let comment = Style(red: 124, green: 120, blue: 116)
  private static let punctuation = Style(red: 43, green: 43, blue: 43)
  private static let link = Style(red: 98, green: 120, blue: 188)
  private static let base = Style(red: 29, green: 29, blue: 29)

  /// Base text style for unhighlighted content.
  static let baseColor: Style = base

  // MARK: - Editor UI colors

  /// editor.foreground — Foreground (1D1D1D)
  static let editorFgStyle: Style? = base

  /// editor.line_number — SubtitleFG (7C7874)
  static let lineNumberStyle: Style? = Style(red: 124, green: 120, blue: 116)

  /// editor.active_line_number — Foreground (1D1D1D)
  static let activeLineNumberStyle: Style? = base

  /// editor.gutter.background — GutterBG (DFD5C9)
  static let gutterBgStyle: Style? = Style(red: 223, green: 213, blue: 201)

  /// editor.background — ElementBackground (F5EFE8)
  static let editorBgStyle: Style? = Style(red: 245, green: 239, blue: 232)

  // MARK: - Help styling

  /// Style for a `--help` output role. Drives `HelpFormatter`.
  static func helpStyle(for role: HelpRole) -> Style {
    switch role {
    case .heading: return keywordBold
    case .command: return typeBuiltin
    case .flag: return blue
    case .metavar: return Style(red: 203, green: 127, blue: 33, italic: true)
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
