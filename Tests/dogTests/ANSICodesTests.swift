import Testing

@testable import dog

@Suite("ANSICodes")
struct ANSICodesTests {

  @Test("reset is ESC[0m")
  func resetBytes() {
    #expect(Array(ANSICodes.reset) == Array("\u{1B}[0m".utf8))
  }

  @Test("bold is ESC[1m")
  func boldBytes() {
    #expect(Array(ANSICodes.bold) == Array("\u{1B}[1m".utf8))
  }

  @Test("italic is ESC[3m")
  func italicBytes() {
    #expect(Array(ANSICodes.italic) == Array("\u{1B}[3m".utf8))
  }

  @Test("fg(rgb:) produces correct 24-bit sequence")
  func fgRGB() {
    let rgb = ANSICodes.RGB(red: 222, green: 117, blue: 71)
    let result = ANSICodes.fg(rgb)
    let expected = Array("\u{1B}[38;2;222;117;71m".utf8)
    #expect(result == expected)
  }

  @Test("fg(hex:) parses # prefix")
  func fgHexWithHash() {
    let result = ANSICodes.fg(hex: "#DE7547")
    let expected = Array("\u{1B}[38;2;222;117;71m".utf8)
    #expect(result == expected)
  }

  @Test("fg(hex:) works without # prefix")
  func fgHexNoHash() {
    let result = ANSICodes.fg(hex: "DE7547")
    let expected = Array("\u{1B}[38;2;222;117;71m".utf8)
    #expect(result == expected)
  }

  @Test("fg(hex:) returns nil for invalid hex")
  func fgHexInvalid() {
    #expect(ANSICodes.fg(hex: "ZZZZZZ") == nil)
    #expect(ANSICodes.fg(hex: "#abc") == nil)
    #expect(ANSICodes.fg(hex: "") == nil)
  }

  @Test("parseHex produces correct RGB")
  func parseHex() {
    let rgb = ANSICodes.parseHex("#897364")
    #expect(rgb?.red == 137)
    #expect(rgb?.green == 115)
    #expect(rgb?.blue == 100)
  }

  @Test("parseHex returns nil for bad input")
  func parseHexInvalid() {
    #expect(ANSICodes.parseHex("nope") == nil)
    #expect(ANSICodes.parseHex("#12") == nil)
  }
}
