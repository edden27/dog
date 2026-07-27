import Testing

@testable import dog

@Suite("TextMetrics")
struct TextMetricsTests {

  @Test("ASCII width is byte count")
  func asciiWidth() {
    #expect("hello world".terminalWidth == 11)
  }

  @Test("NFC accent is 1 column")
  func nfcAccent() {
    #expect("caf\u{00E9}".terminalWidth == 4)
  }

  @Test("NFD combining accent adds no width")
  func nfdAccent() {
    #expect("cafe\u{0301}".terminalWidth == 4)
  }

  @Test("stacked combining marks add no width")
  func stackedCombiningMarks() {
    #expect("e\u{0301}\u{0302}\u{0303}".terminalWidth == 1)
  }

  @Test("CJK is 2 columns per character")
  func cjkWidth() {
    #expect("漢字テスト".terminalWidth == 10)
  }

  @Test("fullwidth forms are 2 columns")
  func fullwidthForms() {
    #expect("\u{FF21}\u{FF22}".terminalWidth == 4)
  }

  @Test("ZWJ family emoji is one 2-column cluster")
  func zwjFamily() {
    #expect("👨\u{200D}👩\u{200D}👧\u{200D}👦".terminalWidth == 2)
  }

  @Test("skin-tone modifier joins its base")
  func skinTone() {
    #expect("👍🏽".terminalWidth == 2)
  }

  @Test("VS16 upgrades a narrow base to 2 columns")
  func emojiPresentation() {
    #expect("❤\u{FE0F}".terminalWidth == 2)
  }

  @Test("keycap sequence is 2 columns")
  func keycap() {
    #expect("1\u{FE0F}\u{20E3}".terminalWidth == 2)
  }

  @Test("mixed source-code line")
  func mixedLine() {
    #expect("x = \"👍🏽 ok\" # 漢字".terminalWidth == 18)
  }

  @Test("combining mark scalar reports zero width")
  func combiningScalarWidth() {
    #expect(UnicodeScalar(0x0301)!.terminalWidth == 0)
  }

  @Test("control scalar keeps the 1-column policy")
  func controlScalarWidth() {
    #expect(UnicodeScalar(0x07)!.terminalWidth == 1)
  }

  @Test("walker survives slice splits mid-cluster")
  func walkerAcrossSlices() {
    // Family emoji fed one scalar at a time, as token-split slices would.
    var walker = WidthWalker()
    let scalars: [UInt32] = [0x1F468, 0x200D, 0x1F469, 0x200D, 0x1F467]
    let total = scalars.reduce(0) { $0 + walker.consume($1) }
    #expect(total == 2)
  }

  @Test("walker keycap after a bulk ASCII run")
  func walkerKeycapAfterASCIIRun() {
    var walker = WidthWalker()
    walker.noteASCIIRun()  // the '1' was bulk-emitted by the ASCII path
    let width = walker.consume(0xFE0F) + walker.consume(0x20E3)
    #expect(width == 1)  // '1' already contributed 1; FE0F upgrades to 2 total
  }
}
