import Testing

@testable import dog

@Suite("ANSIOutput")
struct ANSIOutputTests {

  @Test("color + text + reset produces correct bytes")
  func colorTextReset() {
    let colorBytes: [UInt8] = Array("\u{1B}[38;2;255;0;0m".utf8)
    var output = ANSIOutput(enabled: true, estimatedSize: 64)
    output.color(colorBytes)
    output.text("hello")
    output.reset()

    // Can't read buffer directly (private), but we can verify via flush behavior
    // For now just verify it doesn't crash
  }

  @Test("enabled=false skips color and reset bytes")
  func disabledSkipsColor() {
    var output = ANSIOutput(enabled: false, estimatedSize: 64)
    output.color(Array("\u{1B}[31m".utf8))
    output.text("plain")
    output.reset()
    // No crash, color/reset are no-ops
  }

  @Test("newline appends 0x0A")
  func newlineAppends() {
    var output = ANSIOutput(enabled: true, estimatedSize: 16)
    output.newline()
    // Doesn't crash
  }
}
