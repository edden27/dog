/// Byte-level walker for the `themes[]` array in a Zed theme bundle.
///
/// Separated from `ZedThemeScanner` so the scanner can stay focused on
/// syntax/style extraction while this file handles the multi-variant bundle
/// structure (finding a specific variant's byte range, listing all variant
/// names, matching by exact name).
///
/// All walking is depth-tracked so top-level `name` keys inside variant
/// objects are found without confusing them with nested `players[].name`
/// or other nested occurrences.
enum ZedThemeVariantWalker {

  /// Locate a variant inside a Zed theme bundle by matching its top-level
  /// `"name"` field. Returns the byte range `[start, end)` of the matching
  /// variant object, or nil if no variant matches.
  ///
  /// Pass nil `target` to get the first variant — useful when the user
  /// typed the bundle name and the file happens to contain a single theme.
  static func findVariantRange(
    _ bytes: [UInt8], target: [UInt8]?
  ) -> (start: Int, end: Int)? {
    guard let arrayStart = findThemesArray(bytes) else { return nil }

    var position = arrayStart
    let count = bytes.count
    var depth = 0
    var objectStart = -1
    let nameKey: [UInt8] = [0x6E, 0x61, 0x6D, 0x65]  // "name"

    while position < count {
      let byte = bytes[position]
      if byte == 0x5D, depth == 0 { break }
      if byte == 0x7B {
        if depth == 0 { objectStart = position }
        depth += 1
        position += 1
        continue
      }
      if byte == 0x7D {
        depth -= 1
        if depth == 0, objectStart >= 0,
          matchVariantName(
            bytes, start: objectStart, end: position,
            nameKey: nameKey, target: target
          )
        {
          return (objectStart, position + 1)
        }
        position += 1
        continue
      }
      position += 1
    }
    return nil
  }

  /// Enumerate every `themes[].name` in a bundle. Used by `--list-themes`
  /// and the `themeNotFound` error suggestion path.
  static func listVariantNames(_ bytes: [UInt8]) -> [String] {
    guard let arrayStart = findThemesArray(bytes) else { return [] }

    var position = arrayStart
    let count = bytes.count
    var results = [String]()
    var depth = 0
    var objectStart = -1
    let nameKey: [UInt8] = [0x6E, 0x61, 0x6D, 0x65]

    while position < count {
      let byte = bytes[position]
      if byte == 0x5D, depth == 0 { break }
      if byte == 0x7B {
        if depth == 0 { objectStart = position }
        depth += 1
        position += 1
        continue
      }
      if byte == 0x7D {
        depth -= 1
        if depth == 0, objectStart >= 0,
          let name = extractVariantName(
            bytes, start: objectStart, end: position, nameKey: nameKey
          )
        {
          results.append(name)
        }
        position += 1
        continue
      }
      position += 1
    }
    return results
  }

  // MARK: - Private helpers

  /// Locate the `"themes"` key and return the byte offset just past the
  /// opening `[` so callers can begin walking array entries.
  private static func findThemesArray(_ bytes: [UInt8]) -> Int? {
    let count = bytes.count
    var position = 0
    let themesKey: [UInt8] = [0x74, 0x68, 0x65, 0x6D, 0x65, 0x73]

    while position < count - (themesKey.count + 2) {
      if bytes[position] == 0x22 {
        var matched = true
        for index in 0..<themesKey.count
        where bytes[position + 1 + index] != themesKey[index] {
          matched = false
          break
        }
        if matched, bytes[position + 1 + themesKey.count] == 0x22 {
          position += themesKey.count + 2
          while position < count, bytes[position] != 0x5B { position += 1 }
          return position + 1
        }
      }
      position += 1
    }
    return nil
  }

  /// Does the object at `[start, end]` have a top-level `"name"` matching
  /// `target`? If `target` is nil, returns true on any first object.
  private static func matchVariantName(
    _ bytes: [UInt8], start: Int, end: Int,
    nameKey: [UInt8], target: [UInt8]?
  ) -> Bool {
    guard
      let (valStart, valEnd) = findTopLevelNameValue(
        bytes, start: start, end: end, nameKey: nameKey
      )
    else {
      return target == nil
    }
    guard let target else { return true }
    let valLen = valEnd - valStart
    if valLen != target.count { return false }
    for index in 0..<valLen
    where bytes[valStart + index] != target[index] {
      return false
    }
    return true
  }

  /// Extract the `"name"` string value of the object at `[start, end]`.
  private static func extractVariantName(
    _ bytes: [UInt8], start: Int, end: Int, nameKey: [UInt8]
  ) -> String? {
    guard
      let (valStart, valEnd) = findTopLevelNameValue(
        bytes, start: start, end: end, nameKey: nameKey
      )
    else { return nil }
    return String(decoding: bytes[valStart..<valEnd], as: UTF8.self)
  }

  /// Walk a single object's top-level keys looking for `"name"`. Returns
  /// the string value's byte range `[valStart, valEnd)` or nil if absent.
  private static func findTopLevelNameValue(
    _ bytes: [UInt8], start: Int, end: Int, nameKey: [UInt8]
  ) -> (Int, Int)? {
    var position = start + 1
    var depth = 1

    while position < end, depth > 0 {
      while position < end, bytes[position] <= 0x20 { position += 1 }
      if position >= end { break }
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
      guard byte == 0x22, depth == 1 else {
        position += 1
        continue
      }

      if let result = tryMatchNameKey(
        bytes, end: end, position: &position, nameKey: nameKey
      ) {
        return result
      }
    }
    return nil
  }

  /// Parse one key-value pair at `position`. If the key is `name`, returns
  /// the value's byte range. Otherwise advances past the value and returns nil.
  private static func tryMatchNameKey(
    _ bytes: [UInt8], end: Int,
    position: inout Int, nameKey: [UInt8]
  ) -> (Int, Int)? {
    position += 1
    let keyStart = position
    while position < end, bytes[position] != 0x22 { position += 1 }
    let keyEnd = position
    position += 1
    skipColonAndWhitespace(bytes, end: end, position: &position)

    if isNameKey(bytes, keyStart: keyStart, keyEnd: keyEnd, nameKey: nameKey),
      position < end, bytes[position] == 0x22
    {
      position += 1
      let valStart = position
      while position < end, bytes[position] != 0x22 { position += 1 }
      return (valStart, position)
    }

    skipValue(bytes, end: end, position: &position)
    return nil
  }

  @inline(__always)
  private static func isNameKey(
    _ bytes: [UInt8], keyStart: Int, keyEnd: Int, nameKey: [UInt8]
  ) -> Bool {
    let keyLen = keyEnd - keyStart
    if keyLen != nameKey.count { return false }
    for index in 0..<keyLen
    where bytes[keyStart + index] != nameKey[index] {
      return false
    }
    return true
  }

  @inline(__always)
  private static func skipColonAndWhitespace(
    _ bytes: [UInt8], end: Int, position: inout Int
  ) {
    while position < end,
      bytes[position] == 0x20 || bytes[position] == 0x3A
        || bytes[position] <= 0x0D
    {
      position += 1
    }
  }

  /// Skip over a JSON value: string, object (brace-balanced), or primitive.
  private static func skipValue(
    _ bytes: [UInt8], end: Int, position: inout Int
  ) {
    if position < end, bytes[position] == 0x7B {
      var innerDepth = 1
      position += 1
      while position < end, innerDepth > 0 {
        if bytes[position] == 0x7B { innerDepth += 1 }
        if bytes[position] == 0x7D { innerDepth -= 1 }
        position += 1
      }
    } else if position < end, bytes[position] == 0x22 {
      position += 1
      while position < end, bytes[position] != 0x22 { position += 1 }
      position += 1
    } else {
      while position < end, bytes[position] != 0x2C, bytes[position] != 0x7D {
        position += 1
      }
    }
  }
}
