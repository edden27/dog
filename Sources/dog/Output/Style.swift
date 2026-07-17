/// The visual style for a syntax token: foreground color, optional background color, and text attributes.
///
/// All fields are packed into a single `UInt64` for O(1) equality comparison.
/// ANSI bytes are pre-computed at theme load time — the render loop does one
/// array lookup + one append per token with no per-token allocation.
///
/// UInt64 layout:
///   [63-40: bg RGB (blue@63-56, green@55-48, red@47-40)]
///   [39-16: fg RGB (blue@39-32, green@31-24, red@23-16)]
///   [15-8:  unused]
///   [7:     italic][6: bold][5: hasBg][4-0: unused]
@frozen @usableFromInline
struct Style: Equatable, Sendable {
  @usableFromInline let packed: UInt64
  /// Pre-computed ANSI bytes for this style. Append directly into the output buffer.
  @usableFromInline let bytes: ContiguousArray<UInt8>

  /// Foreground-only style.
  @usableFromInline
  init(r: UInt8, g: UInt8, b: UInt8, bold: Bool = false, italic: Bool = false) {
    packed =
      (UInt64(b) << 32) | (UInt64(g) << 24) | (UInt64(r) << 16) | (bold ? (1 << 6) : 0)
      | (italic ? (1 << 7) : 0)
    bytes = Style.buildBytes(
      r: r, g: g, b: b, bold: bold, italic: italic,
      bgR: 0, bgG: 0, bgB: 0, hasBg: false
    )
  }

  /// Foreground + background style.
  @usableFromInline
  init(
    r: UInt8, g: UInt8, b: UInt8,
    bgR: UInt8, bgG: UInt8, bgB: UInt8,
    bold: Bool = false, italic: Bool = false
  ) {
    packed =
      (UInt64(bgB) << 56) | (UInt64(bgG) << 48) | (UInt64(bgR) << 40) | (UInt64(b) << 32)
      | (UInt64(g) << 24) | (UInt64(r) << 16) | (1 << 5) | (bold ? (1 << 6) : 0)
      | (italic ? (1 << 7) : 0)
    bytes = Style.buildBytes(
      r: r, g: g, b: b, bold: bold, italic: italic,
      bgR: bgR, bgG: bgG, bgB: bgB, hasBg: true
    )
  }

  /// Construct a foreground-only `Style` from a hex color string (e.g. `"#DE7547"`).
  init?(hex: String, bold: Bool = false, italic: Bool = false) {
    guard let rgb = ANSICodes.parseHex(hex) else { return nil }
    self.init(r: rgb.red, g: rgb.green, b: rgb.blue, bold: bold, italic: italic)
  }

  @inlinable var r: UInt8 { UInt8((packed >> 16) & 0xFF) }
  @inlinable var g: UInt8 { UInt8((packed >> 24) & 0xFF) }
  @inlinable var b: UInt8 { UInt8((packed >> 32) & 0xFF) }
  @inlinable var bold: Bool { packed & (1 << 6) != 0 }
  @inlinable var italic: Bool { packed & (1 << 7) != 0 }
  @inlinable var hasBg: Bool { packed & (1 << 5) != 0 }
  @inlinable var bgR: UInt8 { UInt8((packed >> 40) & 0xFF) }
  @inlinable var bgG: UInt8 { UInt8((packed >> 48) & 0xFF) }
  @inlinable var bgB: UInt8 { UInt8((packed >> 56) & 0xFF) }

  // Equatable on packed only — bytes are derived from packed so always in sync.
  @inlinable
  static func == (lhs: Style, rhs: Style) -> Bool { lhs.packed == rhs.packed }

  // swiftlint:disable:next function_parameter_count
  private static func buildBytes(
    r: UInt8, g: UInt8, b: UInt8, bold: Bool, italic: Bool,
    bgR: UInt8, bgG: UInt8, bgB: UInt8, hasBg: Bool
  ) -> ContiguousArray<UInt8> {
    var out = ContiguousArray<UInt8>()
    out.reserveCapacity(hasBg ? 48 : 28)
    // Always clear bold/italic before setting — styles are applied cumulatively
    // without a reset between them, so a prior italic run would bleed into a
    // non-italic style otherwise.
    out.append(contentsOf: bold ? ANSICodes.bold : ANSICodes.notBold)
    out.append(contentsOf: italic ? ANSICodes.italic : ANSICodes.notItalic)
    // ESC[38;2;R;G;Bm — foreground
    out.append(contentsOf: [0x1B, 0x5B, 0x33, 0x38, 0x3B, 0x32, 0x3B])
    ANSICodes.appendDecimal(r, into: &out)
    out.append(0x3B)
    ANSICodes.appendDecimal(g, into: &out)
    out.append(0x3B)
    ANSICodes.appendDecimal(b, into: &out)
    out.append(0x6D)
    if hasBg {
      // ESC[48;2;R;G;Bm — background
      out.append(contentsOf: [0x1B, 0x5B, 0x34, 0x38, 0x3B, 0x32, 0x3B])
      ANSICodes.appendDecimal(bgR, into: &out)
      out.append(0x3B)
      ANSICodes.appendDecimal(bgG, into: &out)
      out.append(0x3B)
      ANSICodes.appendDecimal(bgB, into: &out)
      out.append(0x6D)
    }
    return out
  }
}
