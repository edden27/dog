// One cohesive byte-scanner state machine — splitting it would scatter shared parsing state.
// swiftlint:disable type_body_length

/// Zero-copy JSON byte scanner for Zed theme files.
///
/// Extracts syntax scope entries from the `"syntax"` block without allocating
/// intermediate JSON objects. Handles both shorthand (`"scope": "#hex"`) and
/// full object (`"scope": { "color": "#hex", "font_weight": 700 }`) formats.
enum ZedThemeScanner {

  /// Locate a variant inside a Zed theme bundle by matching the top-level
  /// `"name"` field in the `themes[]` array. See `ZedThemeVariantWalker`.
  @inline(__always)
  static func findVariantRange(
    _ bytes: [UInt8], target: [UInt8]?
  ) -> (start: Int, end: Int)? {
    ZedThemeVariantWalker.findVariantRange(bytes, target: target)
  }

  /// Enumerate every `themes[].name` in a bundle. See `ZedThemeVariantWalker`.
  @inline(__always)
  static func listVariantNames(_ bytes: [UInt8]) -> [String] {
    ZedThemeVariantWalker.listVariantNames(bytes)
  }

  /// Scan the `"syntax"` block and return all scope entries.
  ///
  /// When `range` is nil, scans the whole buffer (legacy behavior for
  /// top-level `syntax` blocks). When provided, scans only within `[start, end)` —
  /// used by `ThemeResolver` to scope the walk to a single bundle variant.
  static func scanSyntaxEntries(
    _ bytes: [UInt8],
    range: (start: Int, end: Int)? = nil
  ) -> [ZedSyntaxEntry] {
    let count = range?.end ?? bytes.count
    var position = range?.start ?? 0

    guard let syntaxStart = findSyntaxBlock(bytes, count: count, from: &position) else {
      return []
    }
    position = syntaxStart

    var entries = [ZedSyntaxEntry]()
    entries.reserveCapacity(48)
    var depth = 1

    while position < count, depth > 0 {
      skipWhitespace(bytes, count: count, position: &position)
      if position >= count { break }

      let byte = bytes[position]
      if byte == 0x7D {
        depth -= 1
        position += 1
        continue
      }
      if byte == 0x7B {
        depth += 1
        position += 1
        continue
      }
      if byte == 0x2C {
        position += 1
        continue
      }

      if byte == 0x22, depth == 1 {
        if let entry = parseScopeEntry(bytes, count: count, position: &position, depth: &depth) {
          entries.append(entry)
        }
      } else {
        position += 1
      }
    }
    return entries
  }

  /// Scan for `"text": "#hex"` in the style block and return the hex value.
  static func scanTextColor(
    _ bytes: [UInt8],
    range: (start: Int, end: Int)? = nil
  ) -> String? {
    scanStyleValue(bytes, key: "text", range: range)
  }

  /// Scan for a flat key in the style block and return its string value.
  /// Works for dotted keys like "editor.gutter.background" — they're flat
  /// JSON keys in the Zed theme schema, not nested objects.
  ///
  /// Pass `range` to scope the search to a single bundle variant object.
  static func scanStyleValue(
    _ bytes: [UInt8],
    key: String,
    range: (start: Int, end: Int)? = nil
  ) -> String? {
    let count = range?.end ?? bytes.count
    let keyBytes = Array(key.utf8)
    let keyLen = keyBytes.count
    var position = range?.start ?? 0

    while position < count - (keyLen + 1) {
      // Look for `"<key>"`
      if bytes[position] == 0x22 {
        var match = true
        for offset in 0..<keyLen
        where bytes[position + 1 + offset] != keyBytes[offset] {
          match = false
          break
        }
        if match, bytes[position + 1 + keyLen] == 0x22 {
          position += keyLen + 2
          // Skip colon and whitespace to value
          while position < count, bytes[position] != 0x22,
            bytes[position] != 0x7D
          {  // swiftlint:disable:this opening_brace
            position += 1
          }
          if position < count, bytes[position] == 0x22 {
            position += 1
            let valueStart = position
            while position < count, bytes[position] != 0x22 { position += 1 }
            return String(decoding: bytes[valueStart..<position], as: UTF8.self)
          }
          return nil
        }
      }
      position += 1
    }
    return nil
  }

  // MARK: - Block Finding

  private static func findSyntaxBlock(
    _ bytes: [UInt8],
    count: Int,
    from position: inout Int
  ) -> Int? {
    while position < count - 10 {
      if bytes[position] == 0x22,
        bytes[position + 1] == 0x73,
        bytes[position + 2] == 0x79,
        bytes[position + 3] == 0x6E,
        bytes[position + 4] == 0x74,
        bytes[position + 5] == 0x61,
        bytes[position + 6] == 0x78,
        bytes[position + 7] == 0x22
      {
        position += 8
        while position < count, bytes[position] != 0x7B { position += 1 }
        position += 1
        return position
      }
      position += 1
    }
    return nil
  }

  private static func skipWhitespace(
    _ bytes: [UInt8],
    count: Int,
    position: inout Int
  ) {
    while position < count, bytes[position] <= 0x20 { position += 1 }
  }

  // MARK: - Entry Parsing

  private static func parseScopeEntry(
    _ bytes: [UInt8],
    count: Int,
    position: inout Int,
    depth: inout Int
  ) -> ZedSyntaxEntry? {
    position += 1
    let keyStart = position
    while position < count, bytes[position] != 0x22 { position += 1 }
    let keyEnd = position
    position += 1

    skipColonAndWhitespace(bytes, count: count, position: &position)

    let scopeName = String(decoding: bytes[keyStart..<keyEnd], as: UTF8.self)

    // Object value: { "color": "#hex", "font_weight": 700, ... }
    if position < count, bytes[position] == 0x7B {
      position += 1
      depth += 1
      return parseScopeObject(
        bytes, count: count, position: &position,
        depth: &depth, scopeName: scopeName
      )
    }

    // String value: "#hex" shorthand
    if position < count, bytes[position] == 0x22 {
      position += 1
      let valueStart = position
      while position < count, bytes[position] != 0x22 { position += 1 }
      let colorValue = String(decoding: bytes[valueStart..<position], as: UTF8.self)
      position += 1
      return ZedSyntaxEntry(scope: scopeName, color: colorValue, fontWeight: 400, fontStyle: nil)
    }

    skipToNextEntry(bytes, count: count, position: &position)
    return nil
  }

  private static func parseScopeObject(
    _ bytes: [UInt8],
    count: Int,
    position: inout Int,
    depth: inout Int,
    scopeName: String
  ) -> ZedSyntaxEntry? {
    var colorValue: String?
    var fontWeight = 400
    var fontStyle: String?

    while position < count, depth > 1 {
      skipWhitespace(bytes, count: count, position: &position)
      if position >= count { break }

      if bytes[position] == 0x7D {
        depth -= 1
        position += 1
        break
      }
      if bytes[position] == 0x2C {
        position += 1
        continue
      }

      guard bytes[position] == 0x22 else {
        position += 1
        continue
      }

      position += 1
      let fieldKeyStart = position
      while position < count, bytes[position] != 0x22 { position += 1 }
      let fieldKeyLength = position - fieldKeyStart
      position += 1

      skipColonAndWhitespace(bytes, count: count, position: &position)

      if fieldKeyLength == 5, bytes[fieldKeyStart] == 0x63 {
        colorValue = readStringValue(bytes, count: count, position: &position)
      } else if fieldKeyLength == 11, bytes[fieldKeyStart] == 0x66 {
        fontWeight = readIntValue(bytes, count: count, position: &position)
      } else if fieldKeyLength == 10, bytes[fieldKeyStart] == 0x66 {
        fontStyle = readStringValue(bytes, count: count, position: &position)
      } else {
        skipValue(bytes, count: count, position: &position)
      }
    }

    guard let color = colorValue else { return nil }
    return ZedSyntaxEntry(
      scope: scopeName, color: color, fontWeight: fontWeight, fontStyle: fontStyle)
  }

  // MARK: - Value Reading

  private static func readStringValue(
    _ bytes: [UInt8],
    count: Int,
    position: inout Int
  ) -> String? {
    guard position < count, bytes[position] == 0x22 else {
      skipValue(bytes, count: count, position: &position)
      return nil
    }
    position += 1
    let valueStart = position
    while position < count, bytes[position] != 0x22 { position += 1 }
    let value = String(decoding: bytes[valueStart..<position], as: UTF8.self)
    position += 1
    return value
  }

  private static func readIntValue(
    _ bytes: [UInt8],
    count: Int,
    position: inout Int
  ) -> Int {
    var result = 0
    while position < count, bytes[position] >= 0x30, bytes[position] <= 0x39 {
      result = result * 10 + Int(bytes[position] - 0x30)
      position += 1
    }
    return result
  }

  private static func skipValue(
    _ bytes: [UInt8],
    count: Int,
    position: inout Int
  ) {
    if position < count, bytes[position] == 0x22 {
      position += 1
      while position < count, bytes[position] != 0x22 { position += 1 }
      position += 1
    } else {
      while position < count, bytes[position] != 0x2C,
        bytes[position] != 0x7D
      {
        position += 1
      }
    }
  }

  private static func skipColonAndWhitespace(
    _ bytes: [UInt8],
    count: Int,
    position: inout Int
  ) {
    while position < count,
      bytes[position] == 0x20 || bytes[position] == 0x3A
        || bytes[position] <= 0x0D
    {
      position += 1
    }
  }

  private static func skipToNextEntry(
    _ bytes: [UInt8],
    count: Int,
    position: inout Int
  ) {
    while position < count, bytes[position] != 0x2C,
      bytes[position] != 0x7D
    {
      position += 1
    }
  }
}

/// A parsed scope entry from a Zed theme's syntax block.
struct ZedSyntaxEntry {
  let scope: String
  let color: String
  let fontWeight: Int
  let fontStyle: String?
}

// swiftlint:enable type_body_length
