// Zed theme scanner benchmark — 3 modes compared.
//
// Mode A: current production path (String scope, String color)
// Mode B: byte-keyed scope → TokenType, String color
// Mode C: byte-keyed scope → TokenType, inline hex → RGB, zero String allocs
//
// Run:
//   swift tests/themes/bench_scanner.swift themes/Catppuccin.json
//   swift tests/themes/bench_scanner.swift themes/Nord.json
//
// All three modes also extract variant name + appearance from themes[] array.

#if canImport(Darwin)
  import Darwin
#elseif canImport(Glibc)
  import Glibc
#endif

// MARK: - TokenType (copied from cli/Sources/dog/Theme/TokenType.swift)

enum TokenType: Int, CaseIterable, Sendable {
  case keyword = 0
  case keywordConditional, keywordConditionalTernary
  case keywordCoroutine, keywordDirective, keywordDirectiveDefine
  case keywordException, keywordFunction, keywordImport
  case keywordModifier, keywordOperator, keywordRepeat
  case keywordReturn, keywordType, conditional, `repeat`, include
  case function, functionBuiltin, functionCall, functionMacro
  case functionMethod, functionMethodBuiltin, functionMethodCall
  case functionSpecial, method, constructor
  case type, typeBuiltin, typeDefinition
  case variable, variableBuiltin, variableMember, variableParameter
  case parameter, field, property, label
  case module, moduleBuiltin
  case string, stringDocumentation, stringEscape, stringRegex
  case stringRegexp, stringSpecial, stringSpecialKey, stringSpecialPath
  case stringSpecialRegex, stringSpecialSymbol, stringSpecialUrl
  case character, characterSpecial
  case number, numberFloat, float, boolean
  case constant, constantBuiltin, constantMacro
  case punctuationBracket, punctuationDelimiter, punctuationSpecial
  case delimiter, `operator`
  case markupHeading, markupHeading1, markupHeading2, markupHeading3
  case markupHeading4, markupHeading5, markupLinkLabel, markupList
  case markupQuote, markupRawBlock
  case tag, tagAttribute, tagBuiltin, tagDelimiter, tagError
  case attribute, attributeBuiltin
  case textLiteral, textTitle, textReference, textUri
  case spell, nospell, none, conceal
  case comment, commentDocumentation, escape, embedded, error

  private static let nameMap: [String: TokenType] = {
    let pairs: [(String, TokenType)] = [
      ("keyword", .keyword), ("keyword.conditional", .keywordConditional),
      ("keyword.conditional.ternary", .keywordConditionalTernary),
      ("keyword.coroutine", .keywordCoroutine), ("keyword.directive", .keywordDirective),
      ("keyword.directive.define", .keywordDirectiveDefine),
      ("keyword.exception", .keywordException), ("keyword.function", .keywordFunction),
      ("keyword.import", .keywordImport), ("keyword.modifier", .keywordModifier),
      ("keyword.operator", .keywordOperator), ("keyword.repeat", .keywordRepeat),
      ("keyword.return", .keywordReturn), ("keyword.type", .keywordType),
      ("conditional", .conditional), ("repeat", .repeat), ("include", .include),
      ("function", .function), ("function.builtin", .functionBuiltin),
      ("function.call", .functionCall), ("function.macro", .functionMacro),
      ("function.method", .functionMethod), ("function.method.builtin", .functionMethodBuiltin),
      ("function.method.call", .functionMethodCall), ("function.special", .functionSpecial),
      ("method", .method), ("constructor", .constructor),
      ("type", .type), ("type.builtin", .typeBuiltin), ("type.definition", .typeDefinition),
      ("variable", .variable), ("variable.builtin", .variableBuiltin),
      ("variable.member", .variableMember), ("variable.parameter", .variableParameter),
      ("parameter", .parameter), ("field", .field), ("property", .property), ("label", .label),
      ("module", .module), ("module.builtin", .moduleBuiltin),
      ("string", .string), ("string.documentation", .stringDocumentation),
      ("string.escape", .stringEscape), ("string.regex", .stringRegex),
      ("string.regexp", .stringRegexp), ("string.special", .stringSpecial),
      ("string.special.key", .stringSpecialKey), ("string.special.path", .stringSpecialPath),
      ("string.special.regex", .stringSpecialRegex),
      ("string.special.symbol", .stringSpecialSymbol),
      ("string.special.url", .stringSpecialUrl),
      ("character", .character), ("character.special", .characterSpecial),
      ("number", .number), ("number.float", .numberFloat), ("float", .float),
      ("boolean", .boolean),
      ("constant", .constant), ("constant.builtin", .constantBuiltin),
      ("constant.macro", .constantMacro),
      ("punctuation.bracket", .punctuationBracket),
      ("punctuation.delimiter", .punctuationDelimiter),
      ("punctuation.special", .punctuationSpecial), ("delimiter", .delimiter),
      ("operator", .operator),
      ("markup.heading", .markupHeading), ("markup.heading.1", .markupHeading1),
      ("markup.heading.2", .markupHeading2), ("markup.heading.3", .markupHeading3),
      ("markup.heading.4", .markupHeading4), ("markup.heading.5", .markupHeading5),
      ("markup.link.label", .markupLinkLabel), ("markup.list", .markupList),
      ("markup.quote", .markupQuote), ("markup.raw.block", .markupRawBlock),
      ("tag", .tag), ("tag.attribute", .tagAttribute), ("tag.builtin", .tagBuiltin),
      ("tag.delimiter", .tagDelimiter), ("tag.error", .tagError),
      ("attribute", .attribute), ("attribute.builtin", .attributeBuiltin),
      ("text.literal", .textLiteral), ("text.title", .textTitle),
      ("text.reference", .textReference), ("text.uri", .textUri),
      ("spell", .spell), ("nospell", .nospell), ("none", TokenType.none), ("conceal", .conceal),
      ("comment", .comment), ("comment.documentation", .commentDocumentation),
      ("escape", .escape), ("embedded", .embedded), ("error", .error),
    ]
    return Dictionary(uniqueKeysWithValues: pairs)
  }()

  static func from(captureName: String) -> TokenType? {
    if let exact = nameMap[captureName] { return exact }
    var name = captureName
    while let dotIndex = name.lastIndex(of: ".") {
      name = String(name[name.startIndex..<dotIndex])
      if let match = nameMap[name] { return match }
    }
    return nil
  }

  /// Flat pairs exported for the byte-keyed table (Mode B/C).
  static var namePairs: [(String, TokenType)] {
    nameMap.map { ($0.key, $0.value) }
  }
}

// MARK: - Byte-keyed scope table (Mode B/C)

/// Precomputed `([UInt8], TokenType.RawValue)` sorted by length desc then lex.
/// Longest-match-first so "keyword.conditional.ternary" beats "keyword".
struct ByteScopeTable {
  let entries: [(key: [UInt8], raw: Int32)]

  init() {
    var pairs = TokenType.namePairs.map { (Array($0.0.utf8), Int32($0.1.rawValue)) }
    pairs.sort { lhs, rhs in
      if lhs.0.count != rhs.0.count { return lhs.0.count > rhs.0.count }
      return lhs.0.lexicographicallyPrecedes(rhs.0)
    }
    self.entries = pairs.map { (key: $0.0, raw: $0.1) }
  }

  /// Match a byte range against the table, with hierarchical fallback.
  /// Returns -1 if no match.
  @inline(__always)
  func lookup(_ bytes: UnsafePointer<UInt8>, start: Int, end: Int) -> Int32 {
    var hi = end
    while hi > start {
      if let raw = exactLookup(bytes, start: start, end: hi) { return raw }
      // Strip last dot segment
      var dotPos = hi - 1
      while dotPos > start, bytes[dotPos] != 0x2E { dotPos -= 1 }
      if dotPos == start { return -1 }
      hi = dotPos
    }
    return -1
  }

  @inline(__always)
  private func exactLookup(_ bytes: UnsafePointer<UInt8>, start: Int, end: Int) -> Int32? {
    let length = end - start
    for entry in entries {
      if entry.key.count != length { continue }
      var matched = true
      for index in 0..<length {
        if entry.key[index] != bytes[start + index] {
          matched = false
          break
        }
      }
      if matched { return entry.raw }
    }
    return nil
  }
}

// MARK: - Variant metadata (themes[] array walk)

struct VariantInfo {
  let name: String
  let appearance: String
}

/// Scan themes[] array top-level "name" + "appearance" for each entry.
/// Simple depth tracker to only grab keys at depth == 1 within an object.
func scanVariants(_ bytes: [UInt8]) -> [VariantInfo] {
  let count = bytes.count
  var position = 0

  // Find "themes" : [
  let themesKey: [UInt8] = [0x74, 0x68, 0x65, 0x6D, 0x65, 0x73]  // "themes"
  var found = false
  while position < count - 10 {
    if bytes[position] == 0x22 {
      var matched = true
      for index in 0..<themesKey.count {
        if bytes[position + 1 + index] != themesKey[index] {
          matched = false
          break
        }
      }
      if matched, bytes[position + 1 + themesKey.count] == 0x22 {
        position += themesKey.count + 2
        while position < count, bytes[position] != 0x5B { position += 1 }
        position += 1
        found = true
        break
      }
    }
    position += 1
  }
  guard found else { return [] }

  var variants = [VariantInfo]()
  var depth = 0
  var objectStart = -1

  let nameKey: [UInt8] = [0x6E, 0x61, 0x6D, 0x65]  // "name"
  let apprKey: [UInt8] = [
    0x61, 0x70, 0x70, 0x65, 0x61, 0x72, 0x61, 0x6E, 0x63, 0x65,
  ]  // "appearance"

  while position < count {
    let byte = bytes[position]
    if byte == 0x5D, depth == 0 { break }  // end of themes array
    if byte == 0x7B {
      if depth == 0 { objectStart = position }
      depth += 1
      position += 1
      continue
    }
    if byte == 0x7D {
      depth -= 1
      if depth == 0 {
        if let info = extractVariantInfo(
          bytes, start: objectStart, end: position,
          nameKey: nameKey, apprKey: apprKey
        ) {
          variants.append(info)
        }
      }
      position += 1
      continue
    }
    position += 1
  }
  return variants
}

/// Pull "name" + "appearance" from a single theme object (depth-1 keys only).
private func extractVariantInfo(
  _ bytes: [UInt8],
  start: Int,
  end: Int,
  nameKey: [UInt8],
  apprKey: [UInt8]
) -> VariantInfo? {
  var position = start + 1
  var depth = 1
  var nameValue: String?
  var apprValue: String?

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
    if byte == 0x22, depth == 1 {
      position += 1
      let keyStart = position
      while position < end, bytes[position] != 0x22 { position += 1 }
      let keyEnd = position
      position += 1
      while position < end,
        bytes[position] == 0x20 || bytes[position] == 0x3A || bytes[position] <= 0x0D
      {
        position += 1
      }

      let keyLen = keyEnd - keyStart
      var matchName = keyLen == nameKey.count
      if matchName {
        for index in 0..<keyLen where bytes[keyStart + index] != nameKey[index] {
          matchName = false
          break
        }
      }
      var matchAppr = keyLen == apprKey.count
      if matchAppr {
        for index in 0..<keyLen where bytes[keyStart + index] != apprKey[index] {
          matchAppr = false
          break
        }
      }

      if matchName || matchAppr, position < end, bytes[position] == 0x22 {
        position += 1
        let valStart = position
        while position < end, bytes[position] != 0x22 { position += 1 }
        let value = String(decoding: bytes[valStart..<position], as: UTF8.self)
        if matchName { nameValue = value }
        if matchAppr { apprValue = value }
        position += 1
      } else {
        // Skip value
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
    } else {
      position += 1
    }
  }

  guard let name = nameValue else { return nil }
  return VariantInfo(name: name, appearance: apprValue ?? "unknown")
}

// MARK: - Mode A: String-based scanner (current production path)

struct ZedSyntaxEntryA {
  let scope: String
  let color: String
  let fontWeight: Int
  let fontStyle: String?
}

enum ScannerA {

  static func scan(_ bytes: [UInt8]) -> [ZedSyntaxEntryA] {
    let count = bytes.count
    var position = 0
    guard let syntaxStart = findSyntaxBlock(bytes, count: count, from: &position) else {
      return []
    }
    position = syntaxStart

    var entries = [ZedSyntaxEntryA]()
    entries.reserveCapacity(48)
    var depth = 1

    while position < count, depth > 0 {
      while position < count, bytes[position] <= 0x20 { position += 1 }
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
        if let entry = parseEntry(bytes, count: count, position: &position, depth: &depth) {
          entries.append(entry)
        }
      } else {
        position += 1
      }
    }
    return entries
  }

  private static func findSyntaxBlock(
    _ bytes: [UInt8], count: Int, from position: inout Int
  ) -> Int? {
    while position < count - 10 {
      if bytes[position] == 0x22,
        bytes[position + 1] == 0x73, bytes[position + 2] == 0x79,
        bytes[position + 3] == 0x6E, bytes[position + 4] == 0x74,
        bytes[position + 5] == 0x61, bytes[position + 6] == 0x78,
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

  private static func parseEntry(
    _ bytes: [UInt8], count: Int, position: inout Int, depth: inout Int
  ) -> ZedSyntaxEntryA? {
    position += 1
    let keyStart = position
    while position < count, bytes[position] != 0x22 { position += 1 }
    let keyEnd = position
    position += 1
    while position < count,
      bytes[position] == 0x20 || bytes[position] == 0x3A || bytes[position] <= 0x0D
    {
      position += 1
    }

    let scope = String(decoding: bytes[keyStart..<keyEnd], as: UTF8.self)

    if position < count, bytes[position] == 0x7B {
      position += 1
      depth += 1
      return parseObject(
        bytes, count: count, position: &position, depth: &depth, scope: scope
      )
    }
    if position < count, bytes[position] == 0x22 {
      position += 1
      let valStart = position
      while position < count, bytes[position] != 0x22 { position += 1 }
      let color = String(decoding: bytes[valStart..<position], as: UTF8.self)
      position += 1
      return ZedSyntaxEntryA(scope: scope, color: color, fontWeight: 400, fontStyle: nil)
    }
    return nil
  }

  private static func parseObject(
    _ bytes: [UInt8], count: Int, position: inout Int, depth: inout Int, scope: String
  ) -> ZedSyntaxEntryA? {
    var color: String?
    var fontWeight = 400
    var fontStyle: String?

    while position < count, depth > 1 {
      while position < count, bytes[position] <= 0x20 { position += 1 }
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
      let fieldStart = position
      while position < count, bytes[position] != 0x22 { position += 1 }
      let fieldLen = position - fieldStart
      position += 1
      while position < count,
        bytes[position] == 0x20 || bytes[position] == 0x3A || bytes[position] <= 0x0D
      {
        position += 1
      }
      if fieldLen == 5, bytes[fieldStart] == 0x63 {
        color = readString(bytes, count: count, position: &position)
      } else if fieldLen == 11, bytes[fieldStart] == 0x66 {
        fontWeight = readInt(bytes, count: count, position: &position)
      } else if fieldLen == 10, bytes[fieldStart] == 0x66 {
        fontStyle = readString(bytes, count: count, position: &position)
      } else {
        skipValue(bytes, count: count, position: &position)
      }
    }
    guard let finalColor = color else { return nil }
    return ZedSyntaxEntryA(
      scope: scope, color: finalColor, fontWeight: fontWeight, fontStyle: fontStyle
    )
  }

  private static func readString(
    _ bytes: [UInt8], count: Int, position: inout Int
  ) -> String? {
    guard position < count, bytes[position] == 0x22 else { return nil }
    position += 1
    let start = position
    while position < count, bytes[position] != 0x22 { position += 1 }
    let value = String(decoding: bytes[start..<position], as: UTF8.self)
    position += 1
    return value
  }

  private static func readInt(
    _ bytes: [UInt8], count: Int, position: inout Int
  ) -> Int {
    var result = 0
    while position < count, bytes[position] >= 0x30, bytes[position] <= 0x39 {
      result = result * 10 + Int(bytes[position] - 0x30)
      position += 1
    }
    return result
  }

  private static func skipValue(_ bytes: [UInt8], count: Int, position: inout Int) {
    if position < count, bytes[position] == 0x22 {
      position += 1
      while position < count, bytes[position] != 0x22 { position += 1 }
      position += 1
    } else {
      while position < count, bytes[position] != 0x2C, bytes[position] != 0x7D {
        position += 1
      }
    }
  }
}

// MARK: - Mode B: Byte-keyed scope, String color

struct ZedSyntaxEntryB {
  let tokenType: Int32  // -1 if unresolved
  let color: String
  let fontWeight: Int
  let italic: Bool
}

enum ScannerB {

  static func scan(_ bytes: [UInt8], table: ByteScopeTable) -> [ZedSyntaxEntryB] {
    let count = bytes.count
    var position = 0
    guard let syntaxStart = findSyntaxBlock(bytes, count: count, from: &position) else {
      return []
    }
    position = syntaxStart

    var entries = [ZedSyntaxEntryB]()
    entries.reserveCapacity(48)
    var depth = 1

    bytes.withUnsafeBufferPointer { buffer in
      let base = buffer.baseAddress!
      while position < count, depth > 0 {
        while position < count, base[position] <= 0x20 { position += 1 }
        if position >= count { break }
        let byte = base[position]
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
          if let entry = parseEntry(
            base, count: count, position: &position, depth: &depth, table: table
          ) {
            entries.append(entry)
          }
        } else {
          position += 1
        }
      }
    }
    return entries
  }

  private static func findSyntaxBlock(
    _ bytes: [UInt8], count: Int, from position: inout Int
  ) -> Int? {
    while position < count - 10 {
      if bytes[position] == 0x22,
        bytes[position + 1] == 0x73, bytes[position + 2] == 0x79,
        bytes[position + 3] == 0x6E, bytes[position + 4] == 0x74,
        bytes[position + 5] == 0x61, bytes[position + 6] == 0x78,
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

  private static func parseEntry(
    _ base: UnsafePointer<UInt8>, count: Int,
    position: inout Int, depth: inout Int, table: ByteScopeTable
  ) -> ZedSyntaxEntryB? {
    position += 1
    let keyStart = position
    while position < count, base[position] != 0x22 { position += 1 }
    let keyEnd = position
    position += 1
    while position < count,
      base[position] == 0x20 || base[position] == 0x3A || base[position] <= 0x0D
    {
      position += 1
    }

    let raw = table.lookup(base, start: keyStart, end: keyEnd)

    if position < count, base[position] == 0x7B {
      position += 1
      depth += 1
      return parseObject(
        base, count: count, position: &position, depth: &depth, tokenRaw: raw
      )
    }
    if position < count, base[position] == 0x22 {
      position += 1
      let valStart = position
      while position < count, base[position] != 0x22 { position += 1 }
      let color = String(
        decoding: UnsafeBufferPointer(start: base + valStart, count: position - valStart),
        as: UTF8.self
      )
      position += 1
      return ZedSyntaxEntryB(tokenType: raw, color: color, fontWeight: 400, italic: false)
    }
    return nil
  }

  private static func parseObject(
    _ base: UnsafePointer<UInt8>, count: Int,
    position: inout Int, depth: inout Int, tokenRaw: Int32
  ) -> ZedSyntaxEntryB? {
    var color: String?
    var fontWeight = 400
    var italic = false

    while position < count, depth > 1 {
      while position < count, base[position] <= 0x20 { position += 1 }
      if position >= count { break }
      if base[position] == 0x7D {
        depth -= 1
        position += 1
        break
      }
      if base[position] == 0x2C {
        position += 1
        continue
      }
      guard base[position] == 0x22 else {
        position += 1
        continue
      }
      position += 1
      let fieldStart = position
      while position < count, base[position] != 0x22 { position += 1 }
      let fieldLen = position - fieldStart
      position += 1
      while position < count,
        base[position] == 0x20 || base[position] == 0x3A || base[position] <= 0x0D
      {
        position += 1
      }
      if fieldLen == 5, base[fieldStart] == 0x63 {
        if position < count, base[position] == 0x22 {
          position += 1
          let valStart = position
          while position < count, base[position] != 0x22 { position += 1 }
          color = String(
            decoding: UnsafeBufferPointer(start: base + valStart, count: position - valStart),
            as: UTF8.self
          )
          position += 1
        }
      } else if fieldLen == 11, base[fieldStart] == 0x66 {
        var result = 0
        while position < count, base[position] >= 0x30, base[position] <= 0x39 {
          result = result * 10 + Int(base[position] - 0x30)
          position += 1
        }
        fontWeight = result
      } else if fieldLen == 10, base[fieldStart] == 0x66 {
        if position < count, base[position] == 0x22 {
          position += 1
          let valStart = position
          while position < count, base[position] != 0x22 { position += 1 }
          // "italic" = 6 bytes, starts with 'i' = 0x69
          italic =
            (position - valStart) == 6 && base[valStart] == 0x69
          position += 1
        }
      } else {
        skipValue(base, count: count, position: &position)
      }
    }
    guard let finalColor = color else { return nil }
    return ZedSyntaxEntryB(
      tokenType: tokenRaw, color: finalColor, fontWeight: fontWeight, italic: italic
    )
  }

  private static func skipValue(
    _ base: UnsafePointer<UInt8>, count: Int, position: inout Int
  ) {
    if position < count, base[position] == 0x22 {
      position += 1
      while position < count, base[position] != 0x22 { position += 1 }
      position += 1
    } else {
      while position < count, base[position] != 0x2C, base[position] != 0x7D {
        position += 1
      }
    }
  }
}

// MARK: - Mode C: Byte-keyed scope + inline hex → RGB (zero String allocs)

struct ZedSyntaxEntryC {
  let tokenType: Int32
  let red: UInt8
  let green: UInt8
  let blue: UInt8
  let fontWeight: Int
  let italic: Bool
}

enum ScannerC {

  @inline(__always)
  private static func hexDigit(_ byte: UInt8) -> Int32 {
    if byte >= 0x30 && byte <= 0x39 { return Int32(byte - 0x30) }
    if byte >= 0x61 && byte <= 0x66 { return Int32(byte - 0x61 + 10) }
    if byte >= 0x41 && byte <= 0x46 { return Int32(byte - 0x41 + 10) }
    return -1
  }

  /// Parse `#rrggbb` or `#rrggbbaa` from bytes starting at `start` (the '#').
  /// Returns (r, g, b) or nil on failure.
  @inline(__always)
  private static func parseHex(
    _ base: UnsafePointer<UInt8>, start: Int, length: Int
  ) -> (UInt8, UInt8, UInt8)? {
    guard length >= 7, base[start] == 0x23 else { return nil }
    let red1 = hexDigit(base[start + 1])
    let red2 = hexDigit(base[start + 2])
    let green1 = hexDigit(base[start + 3])
    let green2 = hexDigit(base[start + 4])
    let blue1 = hexDigit(base[start + 5])
    let blue2 = hexDigit(base[start + 6])
    if red1 < 0 || red2 < 0 || green1 < 0 || green2 < 0 || blue1 < 0 || blue2 < 0 {
      return nil
    }
    return (
      UInt8(red1 * 16 + red2),
      UInt8(green1 * 16 + green2),
      UInt8(blue1 * 16 + blue2)
    )
  }

  static func scan(_ bytes: [UInt8], table: ByteScopeTable) -> [ZedSyntaxEntryC] {
    let count = bytes.count
    var position = 0
    guard let syntaxStart = findSyntaxBlock(bytes, count: count, from: &position) else {
      return []
    }
    position = syntaxStart

    var entries = [ZedSyntaxEntryC]()
    entries.reserveCapacity(48)
    var depth = 1

    bytes.withUnsafeBufferPointer { buffer in
      let base = buffer.baseAddress!
      while position < count, depth > 0 {
        while position < count, base[position] <= 0x20 { position += 1 }
        if position >= count { break }
        let byte = base[position]
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
          if let entry = parseEntry(
            base, count: count, position: &position, depth: &depth, table: table
          ) {
            entries.append(entry)
          }
        } else {
          position += 1
        }
      }
    }
    return entries
  }

  private static func findSyntaxBlock(
    _ bytes: [UInt8], count: Int, from position: inout Int
  ) -> Int? {
    while position < count - 10 {
      if bytes[position] == 0x22,
        bytes[position + 1] == 0x73, bytes[position + 2] == 0x79,
        bytes[position + 3] == 0x6E, bytes[position + 4] == 0x74,
        bytes[position + 5] == 0x61, bytes[position + 6] == 0x78,
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

  private static func parseEntry(
    _ base: UnsafePointer<UInt8>, count: Int,
    position: inout Int, depth: inout Int, table: ByteScopeTable
  ) -> ZedSyntaxEntryC? {
    position += 1
    let keyStart = position
    while position < count, base[position] != 0x22 { position += 1 }
    let keyEnd = position
    position += 1
    while position < count,
      base[position] == 0x20 || base[position] == 0x3A || base[position] <= 0x0D
    {
      position += 1
    }

    let raw = table.lookup(base, start: keyStart, end: keyEnd)

    if position < count, base[position] == 0x7B {
      position += 1
      depth += 1
      return parseObject(
        base, count: count, position: &position, depth: &depth, tokenRaw: raw
      )
    }
    if position < count, base[position] == 0x22 {
      position += 1
      let valStart = position
      while position < count, base[position] != 0x22 { position += 1 }
      let valLen = position - valStart
      position += 1
      guard let rgb = parseHex(base, start: valStart, length: valLen) else { return nil }
      return ZedSyntaxEntryC(
        tokenType: raw, red: rgb.0, green: rgb.1, blue: rgb.2,
        fontWeight: 400, italic: false
      )
    }
    return nil
  }

  private static func parseObject(
    _ base: UnsafePointer<UInt8>, count: Int,
    position: inout Int, depth: inout Int, tokenRaw: Int32
  ) -> ZedSyntaxEntryC? {
    var red: UInt8 = 0
    var green: UInt8 = 0
    var blue: UInt8 = 0
    var hasColor = false
    var fontWeight = 400
    var italic = false

    while position < count, depth > 1 {
      while position < count, base[position] <= 0x20 { position += 1 }
      if position >= count { break }
      if base[position] == 0x7D {
        depth -= 1
        position += 1
        break
      }
      if base[position] == 0x2C {
        position += 1
        continue
      }
      guard base[position] == 0x22 else {
        position += 1
        continue
      }
      position += 1
      let fieldStart = position
      while position < count, base[position] != 0x22 { position += 1 }
      let fieldLen = position - fieldStart
      position += 1
      while position < count,
        base[position] == 0x20 || base[position] == 0x3A || base[position] <= 0x0D
      {
        position += 1
      }
      if fieldLen == 5, base[fieldStart] == 0x63 {
        if position < count, base[position] == 0x22 {
          position += 1
          let valStart = position
          while position < count, base[position] != 0x22 { position += 1 }
          if let rgb = parseHex(base, start: valStart, length: position - valStart) {
            red = rgb.0
            green = rgb.1
            blue = rgb.2
            hasColor = true
          }
          position += 1
        }
      } else if fieldLen == 11, base[fieldStart] == 0x66 {
        var result = 0
        while position < count, base[position] >= 0x30, base[position] <= 0x39 {
          result = result * 10 + Int(base[position] - 0x30)
          position += 1
        }
        fontWeight = result
      } else if fieldLen == 10, base[fieldStart] == 0x66 {
        if position < count, base[position] == 0x22 {
          position += 1
          let valStart = position
          while position < count, base[position] != 0x22 { position += 1 }
          italic = (position - valStart) == 6 && base[valStart] == 0x69
          position += 1
        }
      } else {
        skipValue(base, count: count, position: &position)
      }
    }
    guard hasColor else { return nil }
    return ZedSyntaxEntryC(
      tokenType: tokenRaw, red: red, green: green, blue: blue,
      fontWeight: fontWeight, italic: italic
    )
  }

  private static func skipValue(
    _ base: UnsafePointer<UInt8>, count: Int, position: inout Int
  ) {
    if position < count, base[position] == 0x22 {
      position += 1
      while position < count, base[position] != 0x22 { position += 1 }
      position += 1
    } else {
      while position < count, base[position] != 0x2C, base[position] != 0x7D {
        position += 1
      }
    }
  }
}

// MARK: - Timing

@inline(__always)
func nowNanos() -> UInt64 {
  var timespec = timespec()
  clock_gettime(CLOCK_MONOTONIC, &timespec)
  return UInt64(timespec.tv_sec) * 1_000_000_000 + UInt64(timespec.tv_nsec)
}

struct Stats {
  let min: UInt64
  let median: UInt64
  let mean: UInt64
  let max: UInt64

  init(_ samples: [UInt64]) {
    let sorted = samples.sorted()
    self.min = sorted.first!
    self.max = sorted.last!
    self.median = sorted[sorted.count / 2]
    self.mean = samples.reduce(0, +) / UInt64(samples.count)
  }

  func format(label: String) -> String {
    return
      "\(label)  min=\(nsToString(min))  median=\(nsToString(median))  mean=\(nsToString(mean))  max=\(nsToString(max))"
  }
}

/// Format nanoseconds with scale suffix. Foundation-free.
func nsToString(_ nanos: UInt64) -> String {
  if nanos < 1_000 { return "\(nanos)ns" }
  if nanos < 1_000_000 {
    // microseconds with 2 decimals
    let hundredths = (nanos + 5) / 10  // round to 0.01µs
    let whole = hundredths / 100
    let frac = hundredths % 100
    return "\(whole).\(frac < 10 ? "0" : "")\(frac)µs"
  }
  // milliseconds with 3 decimals
  let micros = (nanos + 500) / 1_000  // round to 0.001ms
  let whole = micros / 1_000
  let frac = micros % 1_000
  var fracStr = "\(frac)"
  while fracStr.count < 3 { fracStr = "0" + fracStr }
  return "\(whole).\(fracStr)ms"
}

func benchmark(
  iterations: Int, warmup: Int, label: String, _ body: () -> Int
) -> (stats: Stats, count: Int) {
  for _ in 0..<warmup { _ = body() }
  var samples = [UInt64]()
  samples.reserveCapacity(iterations)
  var lastCount = 0
  for _ in 0..<iterations {
    let start = nowNanos()
    lastCount = body()
    let end = nowNanos()
    samples.append(end - start)
  }
  return (Stats(samples), lastCount)
}

// MARK: - Main

let defaultPath = "themes/Catppuccin.json"
let path =
  CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : defaultPath

let fileDescriptor = open(path, O_RDONLY)
guard fileDescriptor >= 0 else {
  fputs("ERROR: could not open \(path)\n", stderr)
  exit(1)
}
var fileStat = stat()
fstat(fileDescriptor, &fileStat)
let fileSize = Int(fileStat.st_size)
var sourceBytes = [UInt8](repeating: 0, count: fileSize)
let bytesRead = sourceBytes.withUnsafeMutableBytes {
  read(fileDescriptor, $0.baseAddress, fileSize)
}
close(fileDescriptor)
guard bytesRead == fileSize else {
  fputs("ERROR: incomplete read\n", stderr)
  exit(1)
}

let table = ByteScopeTable()

print("File: \(path) (\(fileSize) bytes)")
print("")

// Correctness check + variant dump
let variants = scanVariants(sourceBytes)
print("Variants (\(variants.count)):")
for variant in variants {
  print("  - \(variant.name) [\(variant.appearance)]")
}
print("")

let sampleA = ScannerA.scan(sourceBytes)
let sampleB = ScannerB.scan(sourceBytes, table: table)
let sampleC = ScannerC.scan(sourceBytes, table: table)
print(
  "Entries: A=\(sampleA.count)  B=\(sampleB.count)  C=\(sampleC.count)"
)
let resolvedB = sampleB.filter { $0.tokenType >= 0 }.count
let resolvedC = sampleC.filter { $0.tokenType >= 0 }.count
print(
  "Byte-keyed resolved: B=\(resolvedB)/\(sampleB.count)  C=\(resolvedC)/\(sampleC.count)"
)
print("")

let iters = 1_000
let warmups = 100
print("Benchmarking (warmup=\(warmups), iters=\(iters)):")
print("")

let resultA = benchmark(iterations: iters, warmup: warmups, label: "A") {
  ScannerA.scan(sourceBytes).count
}
let resultB = benchmark(iterations: iters, warmup: warmups, label: "B") {
  ScannerB.scan(sourceBytes, table: table).count
}
let resultC = benchmark(iterations: iters, warmup: warmups, label: "C") {
  ScannerC.scan(sourceBytes, table: table).count
}

// Include variant scan in its own line so we can see its cost
let resultV = benchmark(iterations: iters, warmup: warmups, label: "V") {
  scanVariants(sourceBytes).count
}

print(resultA.stats.format(label: "A (String scope + color)          "))
print(resultB.stats.format(label: "B (byte scope → int, String color)"))
print(resultC.stats.format(label: "C (byte scope + inline hex RGB)   "))
print(resultV.stats.format(label: "V (variant name + appearance)     "))
print("")

func deltaPercent(_ baseline: UInt64, _ other: UInt64) -> String {
  // percent * 10 for one decimal, rounded
  let numer = (Int64(other) - Int64(baseline)) * 1_000
  let tenths = numer / Int64(baseline)
  let whole = tenths / 10
  let frac = abs(tenths % 10)
  let sign = tenths >= 0 ? "+" : "-"
  let absWhole = abs(whole)
  return "\(sign)\(absWhole).\(frac)%"
}

print("Delta vs A (median):")
print("  B: \(deltaPercent(resultA.stats.median, resultB.stats.median))")
print("  C: \(deltaPercent(resultA.stats.median, resultC.stats.median))")
