import Testing

@testable import dog

/// A token that spans a blank line (a block comment, a heredoc, a raw string)
/// must keep its style after the blank line. The renderers used to drop such
/// a token on the blank line, because nothing of it was left to draw there.
@Suite("Blank line inside a multi-line token")
struct BlankLineTokenTests {

  private static let commentStyle = Style(red: 1, green: 2, blue: 3)
  private static let baseStyle = Style(red: 9, green: 9, blue: 9)

  /// A comment covering the whole source, which has a blank line in its middle.
  private static let source = Array("/* start\ninside one\n\ninside two\n*/\n".utf8)

  private func render(wrap: WrapOption, width: Int?) -> String {
    var table = [Style](repeating: Self.baseStyle, count: TokenType.allCases.count)
    table[TokenType.comment.rawValue] = Self.commentStyle
    let command = PrintCommand(
      file: nil, language: "c", plain: false, colorEnabled: true,
      paging: .never, wrap: wrap, terminalWidthOverride: width,
      colorTable: table, baseColor: Self.baseStyle,
      lineNumberStyle: nil, gutterBgStyle: nil, editorBgStyle: nil)
    let token = SyntaxToken(
      tokenType: .comment, startByte: 0, endByte: Self.source.count - 1, name: "comment")
    let (output, _) = command.renderColorized(sourceBytes: Self.source, tokens: [token])
    return String(decoding: output.buffer, as: UTF8.self)
  }

  private func styleBefore(_ word: String, in rendered: String) -> String? {
    guard let range = rendered.range(of: word) else { return nil }
    let before = rendered[..<range.lowerBound]
    guard let last = before.range(of: "\u{1b}[", options: .backwards) else { return nil }
    // The escape sequence alone, up to its closing "m", without the text that follows it.
    let sequence = before[last.lowerBound...]
    guard let end = sequence.firstIndex(of: "m") else { return nil }
    return String(sequence[...end])
  }

  @Test("bulk path keeps the comment style after the blank line")
  func bulkPath() {
    let rendered = render(wrap: .never, width: nil)
    #expect(styleBefore("inside two", in: rendered) == styleBefore("inside one", in: rendered))
    #expect(styleBefore("*/", in: rendered) == styleBefore("inside one", in: rendered))
  }

  @Test("wrapping path keeps the comment style after the blank line")
  func wrappingPath() {
    // .auto with a width override turns wrapping on even when stdout is not a terminal
    let rendered = render(wrap: .auto, width: 12)
    #expect(styleBefore("two", in: rendered) == styleBefore("one", in: rendered))
  }

  @Test("truncating path keeps the comment style after the blank line")
  func truncatingPath() {
    // .never with a width override clips long lines, the third renderer path
    let rendered = render(wrap: .never, width: 12)
    #expect(styleBefore("*/", in: rendered) == styleBefore("start", in: rendered))
  }
}
