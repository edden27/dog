#if canImport(Darwin)
  import Darwin
#elseif canImport(Glibc)
  import Glibc
#endif

/// Buffered ANSI output writer using raw `ContiguousArray<UInt8>` for zero-allocation rendering.
///
/// Pre-allocate, append color codes + text as bytes, flush once to stdout.
/// When `enabled` is false, color and reset calls are no-ops.
@frozen @usableFromInline
struct ANSIOutput {
  @usableFromInline var buffer: ContiguousArray<UInt8>
  @usableFromInline let enabled: Bool

  /// Create an output buffer.
  /// - Parameters:
  ///   - enabled: Whether ANSI color codes are emitted.
  ///   - estimatedSize: Hint for pre-allocation (source size × 2 is reasonable).
  init(enabled: Bool, estimatedSize: Int = 64 * 1024) {
    self.enabled = enabled
    self.buffer = ContiguousArray()
    self.buffer.reserveCapacity(estimatedSize)
  }

  /// Append an ANSI color escape sequence.
  @inlinable
  mutating func color(_ ansiBytes: [UInt8]) {
    guard enabled else { return }
    buffer.append(contentsOf: ansiBytes)
  }

  /// Emit the ANSI bytes for a `Style` — pre-computed at theme load, one append.
  @inlinable
  mutating func color(_ style: Style) {
    guard enabled else { return }
    buffer.append(contentsOf: style.bytes)
  }

  /// Emit a bold/italic toggle delta between `previous` and `next`, then the
  /// fg/bg color bytes for `next`. Pass `previous == nil` at the start of a
  /// styled region (after reset) so both bits are forced to their `next`
  /// state. Compared to the fused-prefix approach in `Style.bytes`, this
  /// appends zero toggle bytes when both bits are unchanged — the dominant
  /// case for long runs of same-weight tokens.
  @inlinable
  mutating func colorDelta(from previous: Style?, to next: Style) {
    guard enabled else { return }
    let prevBold = previous?.bold ?? false
    let prevItalic = previous?.italic ?? false
    // Forcing state at the start of a styled region: if previous is nil we
    // came off a reset, so any *set* bit must be emitted (SGR default is off)
    // and any *clear* bit is implicit (no toggle needed — terminal is
    // already in neither-bold-nor-italic after reset).
    if previous == nil {
      if next.bold { buffer.append(contentsOf: ANSICodes.bold) }
      if next.italic { buffer.append(contentsOf: ANSICodes.italic) }
    } else {
      if prevBold != next.bold {
        buffer.append(contentsOf: next.bold ? ANSICodes.bold : ANSICodes.notBold)
      }
      if prevItalic != next.italic {
        buffer.append(contentsOf: next.italic ? ANSICodes.italic : ANSICodes.notItalic)
      }
    }
    buffer.append(contentsOf: next.bytes)
  }

  /// Append raw UTF-8 text bytes from a slice of the source buffer.
  @inlinable
  mutating func text(_ bytes: ArraySlice<UInt8>) {
    buffer.append(contentsOf: bytes)
  }

  /// Append raw UTF-8 bytes from a fixed array (e.g. pre-encoded literals).
  @inlinable
  mutating func text(_ bytes: [UInt8]) {
    buffer.append(contentsOf: bytes)
  }

  /// Append raw UTF-8 bytes from a ContiguousArray (e.g. pre-built gutter).
  @inlinable
  mutating func text(_ bytes: ContiguousArray<UInt8>) {
    buffer.append(contentsOf: bytes)
  }

  /// Append a single ASCII byte directly.
  @inlinable
  mutating func byte(_ value: UInt8) {
    buffer.append(value)
  }

  /// Append a string as UTF-8 bytes.
  @inlinable
  mutating func text(_ string: String) {
    buffer.append(contentsOf: string.utf8)
  }

  /// Append a substring as UTF-8 bytes.
  @inlinable
  mutating func text(_ substring: Substring) {
    buffer.append(contentsOf: substring.utf8)
  }

  /// Append the ANSI reset sequence.
  @inlinable
  mutating func reset() {
    guard enabled else { return }
    buffer.append(contentsOf: ANSICodes.reset)
  }

  /// Append a newline byte.
  @inlinable
  mutating func newline() {
    buffer.append(0x0A)
  }

  /// Write the entire buffer to stdout in one call.
  ///
  /// Uses POSIX `write(2)` syscall directly on file descriptor 1 (stdout).
  /// Avoids both FileHandle's NSException on SIGPIPE and C's `FILE*` globals
  /// which Swift 6 strict concurrency flags as unsafe on Linux.
  @inlinable
  mutating func flush() {
    flushTo(STDOUT_FILENO)
  }

  /// Write the buffer to a specific file descriptor, then clear.
  @inlinable
  // swiftlint:disable:next identifier_name
  mutating func flushTo(_ fd: Int32) {
    guard !buffer.isEmpty else { return }
    buffer.withUnsafeBufferPointer { ptr in
      guard let base = ptr.baseAddress else { return }
      var remaining = ptr.count
      var offset = 0
      while remaining > 0 {
        let written = write(fd, base + offset, remaining)
        if written <= 0 { break }
        offset += written
        remaining -= written
      }
    }
    buffer.removeAll(keepingCapacity: true)
  }
}

/// Pre-computed ANSI escape byte sequences.
@usableFromInline
enum ANSICodes {
  @usableFromInline static let reset: ContiguousArray<UInt8> = ContiguousArray("\u{1B}[0m".utf8)
  @usableFromInline static let bold: ContiguousArray<UInt8> = ContiguousArray("\u{1B}[1m".utf8)
  @usableFromInline static let dim: ContiguousArray<UInt8> = ContiguousArray("\u{1B}[2m".utf8)
  @usableFromInline static let italic: ContiguousArray<UInt8> = ContiguousArray("\u{1B}[3m".utf8)
  @usableFromInline static let underline: ContiguousArray<UInt8> = ContiguousArray("\u{1B}[4m".utf8)
  /// ESC[22m — clears both bold and dim (neither-bold-nor-faint).
  @usableFromInline static let notBold: ContiguousArray<UInt8> = ContiguousArray("\u{1B}[22m".utf8)
  /// ESC[23m — clears italic.
  @usableFromInline static let notItalic: ContiguousArray<UInt8> =
    ContiguousArray("\u{1B}[23m".utf8)

  /// RGB color components.
  struct RGB {
    let red: UInt8
    let green: UInt8
    let blue: UInt8
  }

  /// Build a 24-bit foreground color escape sequence from RGB components.
  static func fg(_ rgb: RGB) -> [UInt8] {
    Array("\u{1B}[38;2;\(rgb.red);\(rgb.green);\(rgb.blue)m".utf8)
  }

  @usableFromInline
  static func appendDecimal(_ value: UInt8, into out: inout ContiguousArray<UInt8>) {
    if value >= 100 { out.append(0x30 &+ value / 100) }
    if value >= 10 { out.append(0x30 &+ (value % 100) / 10) }
    out.append(0x30 &+ value % 10)
  }

  /// Append an Int as decimal ASCII digits. Used for line numbers.
  @usableFromInline
  static func appendDecimal(_ value: Int, digitWidth: Int, into out: inout ContiguousArray<UInt8>) {
    // Write digits from most significant to least
    var divisor = 1
    for _ in 1..<digitWidth { divisor *= 10 }
    let remaining = value
    for _ in 0..<digitWidth {
      out.append(UInt8(0x30 + (remaining / divisor) % 10))
      divisor /= 10
    }
  }

  /// Build a 24-bit foreground color escape sequence from a hex string like "#DE7547".
  static func fg(hex: String) -> [UInt8]? {
    guard let rgb = parseHex(hex) else { return nil }
    return fg(rgb)
  }

  /// Parse a hex color string (`#rrggbb` or `#rrggbbaa`) to RGB components.
  ///
  /// For 8-char hex with alpha, composites against `background` when provided.
  /// When no background is given, drops alpha and returns the raw RGB bytes
  /// (terminals have no transparency — this is the only sane fallback).
  static func parseHex(_ hex: String, background: RGB? = nil) -> RGB? {
    var cleaned = hex
    if cleaned.hasPrefix("#") {
      cleaned = String(cleaned.dropFirst())
    }
    if cleaned.count == 8 {
      if let background {
        return parseHexComposite(hex, over: background)
      }
      guard let value = UInt32(cleaned, radix: 16) else { return nil }
      return RGB(
        red: UInt8((value >> 24) & 0xFF),
        green: UInt8((value >> 16) & 0xFF),
        blue: UInt8((value >> 8) & 0xFF)
      )
    }
    guard cleaned.count == 6, let value = UInt32(cleaned, radix: 16) else {
      return nil
    }
    return RGB(
      red: UInt8((value >> 16) & 0xFF),
      green: UInt8((value >> 8) & 0xFF),
      blue: UInt8(value & 0xFF)
    )
  }

  /// Blend an 8-char hex color (`#rrggbbaa`) over a known background.
  ///
  /// Only called for colors that actually have alpha. Uses integer blend:
  /// `out = (fg*a + bg*(255-a) + 127) / 255`. Terminals have no transparency,
  /// so the composite must be computed at theme-load time against the theme's
  /// editor background.
  static func parseHexComposite(_ hex: String, over background: RGB) -> RGB? {
    var cleaned = hex
    if cleaned.hasPrefix("#") {
      cleaned = String(cleaned.dropFirst())
    }
    guard cleaned.count == 8, let value = UInt32(cleaned, radix: 16) else {
      return nil
    }
    let fgR = UInt32((value >> 24) & 0xFF)
    let fgG = UInt32((value >> 16) & 0xFF)
    let fgB = UInt32((value >> 8) & 0xFF)
    let alpha = UInt32(value & 0xFF)
    if alpha == 255 {
      return RGB(red: UInt8(fgR), green: UInt8(fgG), blue: UInt8(fgB))
    }
    let invAlpha = 255 - alpha
    let bgR = UInt32(background.red)
    let bgG = UInt32(background.green)
    let bgB = UInt32(background.blue)
    let red = (fgR * alpha + bgR * invAlpha + 127) / 255
    let green = (fgG * alpha + bgG * invAlpha + 127) / 255
    let blue = (fgB * alpha + bgB * invAlpha + 127) / 255
    return RGB(red: UInt8(red), green: UInt8(green), blue: UInt8(blue))
  }
}
