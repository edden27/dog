#!/usr/bin/env swift
/// Optimized vs baseline render loop — all winners applied.
///
/// Baseline (proof-style, slowest):
///   1. Theme lookup:       Dictionary
///   2. TokenType resolve:  Per-token string matching
///   3. Reset strategy:     Reset after every token AND every gap
///   4. Gap filling:        baseColor + gap text + reset
///   5. Buffer write:       3x append per token
///
/// Optimized (all benchmark winners):
///   1. Theme lookup:       Switch (jump table)
///   2. TokenType resolve:  Pre-resolved during parsing
///   3. Reset strategy:     No reset, overwrite color
///   4. Gap filling:        Track last color, emit on change
///   5. Buffer write:       2x append (color + text, no reset)
///
/// Results (86k tokens × 50 iterations, Apple Silicon, -O, avg of 3 runs):
///   Baseline:                       13.39ms  (6,105,473 bytes)  proof-style
///   v1 (switch, all safe winners):   8.24ms  (5,417,473 bytes)  39% faster — our target
///   v2 (array index):                8.13ms                     ~same as v1
///   v3 (@inline switch):             8.17ms                     ~same as v1
///   v4 (exact pre-size):             8.20ms                     ~same as v1
///   v5 (UnsafeBufferPointer reads):  6.83ms                     49% faster — unsafe source reads
///
///   v1 is the winner for production. v2/v3/v4 are within noise — compiler already optimizes.
///   v5 saves 1.4ms more with unsafe reads (safe writes) — lower risk than full unsafe,
///   but not worth it for 1.4ms. Ship v1.
///
///   Total savings: 13.39ms → 8.24ms = 5.15ms saved (38% faster render loop).
///   Biggest single win: pre-resolved TokenType (-3.86ms, 31% of baseline).
import Foundation

func now() -> UInt64 { DispatchTime.now().uptimeNanoseconds }

// MARK: - TokenType enum (matches real TokenType — String raw for capture matching, Int index for flat)

enum TokenType: Int, CaseIterable {
  case keyword = 0, keywordConditional, keywordConditionalTernary
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

  /// String→TokenType lookup table (built once, used by from(captureName:))
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
      ("string.special.regex", .stringSpecialRegex), ("string.special.symbol", .stringSpecialSymbol),
      ("string.special.url", .stringSpecialUrl),
      ("character", .character), ("character.special", .characterSpecial),
      ("number", .number), ("number.float", .numberFloat), ("float", .float),
      ("boolean", .boolean),
      ("constant", .constant), ("constant.builtin", .constantBuiltin),
      ("constant.macro", .constantMacro),
      ("punctuation.bracket", .punctuationBracket), ("punctuation.delimiter", .punctuationDelimiter),
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
    while let dot = name.lastIndex(of: ".") {
      name = String(name[name.startIndex..<dot])
      if let match = nameMap[name] { return match }
    }
    return nil
  }
}

// MARK: - Theme colors

func fg(_ hex: String) -> [UInt8] {
  var h = hex; if h.hasPrefix("#") { h = String(h.dropFirst()) }
  let v = UInt32(h, radix: 16)!
  return Array("\u{1B}[38;2;\(UInt8((v >> 16) & 0xFF));\(UInt8((v >> 8) & 0xFF));\(UInt8(v & 0xFF))m".utf8)
}

let bold: [UInt8] = Array("\u{1B}[1m".utf8)
let italic: [UInt8] = Array("\u{1B}[3m".utf8)
let resetBytes: [UInt8] = Array("\u{1B}[0m".utf8)
let baseColor: [UInt8] = fg("#CDBEAB")

let kwBoldItalic = bold + italic + fg("#EE6E39")
let kwPlain = fg("#EE6E39")
let pinkColor = fg("#E384A7")
let fnColor = fg("#819F84")
let fnBuiltin = italic + fg("#819F84")
let typeBuiltinColor = bold + fg("#819F84")
let yellowColor = fg("#E8A655")
let varBold = bold + fg("#C4B098")
let strColor = italic + fg("#CDBEAB")
let blueItalic = italic + fg("#9EB2C9")
let bluePlain = fg("#9EB2C9")
let purpleColor = fg("#CF95F9")
let redColor = fg("#CC433D")
let commentColor = fg("#817464")
let punctColor = fg("#D9D9D9")
let linkColor = fg("#2770BD")
let baseBold = bold + fg("#CDBEAB")

// Switch lookup (Option B from theme bench — the winner)
func themeSwitch(_ t: TokenType) -> [UInt8] {
  switch t {
  case .keyword, .keywordConditional, .keywordConditionalTernary,
       .keywordCoroutine, .keywordDirective, .keywordDirectiveDefine,
       .keywordException, .keywordFunction, .keywordImport,
       .keywordModifier, .keywordOperator, .keywordRepeat,
       .keywordReturn, .keywordType, .conditional, .repeat, .include:
    return kwBoldItalic
  case .stringSpecial, .stringSpecialSymbol, .constantBuiltin:
    return kwPlain
  case .stringEscape, .boolean:
    return pinkColor
  case .function, .functionCall, .functionMethod, .functionMethodCall,
       .functionSpecial, .method, .constructor:
    return fnColor
  case .functionBuiltin, .functionMethodBuiltin:
    return fnBuiltin
  case .functionMacro:
    return yellowColor
  case .type, .typeDefinition, .constant, .module:
    return yellowColor
  case .typeBuiltin, .moduleBuiltin:
    return typeBuiltinColor
  case .variable:
    return varBold
  case .variableBuiltin:
    return blueItalic
  case .variableMember, .variableParameter, .parameter, .field, .property, .label:
    return yellowColor
  case .string, .stringDocumentation, .stringSpecialPath:
    return strColor
  case .character:
    return blueItalic
  case .characterSpecial:
    return redColor
  case .attribute, .tagAttribute, .attributeBuiltin:
    return bluePlain
  case .number, .numberFloat, .float:
    return purpleColor
  case .constantMacro, .stringSpecialKey:
    return yellowColor
  case .stringRegex, .stringRegexp, .stringSpecialRegex:
    return redColor
  case .stringSpecialUrl:
    return linkColor
  case .comment, .commentDocumentation:
    return commentColor
  case .punctuationBracket, .punctuationDelimiter, .punctuationSpecial,
       .delimiter, .operator, .embedded:
    return punctColor
  case .tag, .tagBuiltin:
    return yellowColor
  case .tagDelimiter:
    return punctColor
  case .tagError, .error, .escape:
    return redColor
  case .markupHeading, .markupHeading1, .markupHeading2, .markupHeading3,
       .markupHeading4, .markupHeading5, .markupList, .textLiteral, .textTitle:
    return baseBold
  case .markupLinkLabel, .textReference, .textUri:
    return linkColor
  case .markupQuote:
    return blueItalic
  case .markupRawBlock:
    return baseColor
  case .spell, .nospell, TokenType.none, .conceal:
    return baseColor
  }
}

// Dict lookup
let themeDict: [TokenType: [UInt8]] = {
  var d = [TokenType: [UInt8]]()
  for t in TokenType.allCases { d[t] = themeSwitch(t) }
  return d
}()

// Flat lookup
struct FlatTheme {
  let data: [UInt8]
  let offsets: [(start: Int, count: Int)]
  init() {
    var buf: [UInt8] = []
    var off = [(start: Int, count: Int)]()
    for t in TokenType.allCases {
      let c = themeSwitch(t)
      let s = buf.count
      buf.append(contentsOf: c)
      off.append((s, c.count))
    }
    self.data = buf
    self.offsets = off
  }
  func lookup(_ t: TokenType) -> ArraySlice<UInt8> {
    let o = offsets[t.rawValue]
    return data[o.start..<(o.start + o.count)]
  }
}
let flatTheme = FlatTheme()

// MARK: - Source + Tokens

let sourceSize = 2_000_000
var sourceBytes: [UInt8] = []
sourceBytes.reserveCapacity(sourceSize)
for i in 0..<sourceSize { sourceBytes.append(UInt8(32 + (i % 95))) }

struct RawToken {
  let name: String
  let start: Int
  let end: Int
}

// Realistic distribution from jquery.js token audit
let captureNames: [(String, Int)] = [
  ("keyword", 800), ("keyword.function", 300), ("keyword.return", 200),
  ("keyword.conditional", 200), ("keyword.operator", 300),
  ("function", 500), ("function.call", 1200), ("function.method.call", 400),
  ("function.builtin", 200),
  ("variable", 1000), ("variable.member", 800), ("variable.parameter", 500),
  ("variable.builtin", 200),
  ("string", 800), ("string.escape", 100),
  ("number", 300), ("boolean", 100),
  ("comment", 400),
  ("punctuation.bracket", 1000), ("punctuation.delimiter", 600),
  ("operator", 800), ("constructor", 200),
  ("property", 500), ("type", 200), ("type.builtin", 100),
  ("constant.builtin", 100), ("constant", 100),
  ("tag", 50), ("attribute", 50),
]

var namePool: [String] = []
for (name, weight) in captureNames { for _ in 0..<weight { namePool.append(name) } }

var rawTokens: [RawToken] = []
rawTokens.reserveCapacity(86_000)
var pos = 0
for i in 0..<86_000 {
  let gap = 2 + (i % 8)
  let len = 3 + (i % 15)
  let start = pos + gap
  let end = start + len
  if end >= sourceSize { break }
  rawTokens.append(RawToken(name: namePool[i % namePool.count], start: start, end: end))
  pos = end
}

// Pre-resolved tokens (for benchmarks that skip string resolution)
struct ResolvedToken {
  let tokenType: TokenType
  let start: Int
  let end: Int
}

let resolvedTokens: [ResolvedToken] = rawTokens.map {
  ResolvedToken(tokenType: TokenType.from(captureName: $0.name) ?? TokenType.none, start: $0.start, end: $0.end)
}

// Cached string→TokenType (for cache benchmark)
let resolveCache: [String: TokenType] = {
  var cache = [String: TokenType]()
  for t in rawTokens {
    if cache[t.name] == nil {
      cache[t.name] = TokenType.from(captureName: t.name) ?? TokenType.none
    }
  }
  return cache
}()

let tokenCount = rawTokens.count
let iterations = 50

var buffer: [UInt8] = []
buffer.reserveCapacity(sourceSize * 3)

// MARK: - Baseline: proof-style (dict + per-token resolve + reset every + 3x append)

var baselineTotal: UInt64 = 0
for _ in 0..<iterations {
  buffer.removeAll(keepingCapacity: true)
  let start = now()
  var p = 0
  for t in rawTokens {
    let tt = TokenType.from(captureName: t.name) ?? TokenType.none
    let color = themeDict[tt]!
    if t.start > p {
      buffer.append(contentsOf: baseColor)
      buffer.append(contentsOf: sourceBytes[p..<t.start])
      buffer.append(contentsOf: resetBytes)
    }
    buffer.append(contentsOf: color)
    buffer.append(contentsOf: sourceBytes[t.start..<t.end])
    buffer.append(contentsOf: resetBytes)
    p = t.end
  }
  if p < sourceSize {
    buffer.append(contentsOf: baseColor)
    buffer.append(contentsOf: sourceBytes[p...])
    buffer.append(contentsOf: resetBytes)
  }
  let end = now()
  baselineTotal += (end - start)
}
let baselineSize = buffer.count

// MARK: - Optimized: switch + pre-resolved + no reset + track gap + safe [UInt8] append

var optimizedTotal: UInt64 = 0
for _ in 0..<iterations {
  buffer.removeAll(keepingCapacity: true)
  let start = now()
  var p = 0
  var lastColor = -1
  for t in resolvedTokens {
    let colorIndex = t.tokenType.rawValue
    if t.start > p {
      if lastColor != -2 {
        buffer.append(contentsOf: baseColor)
        lastColor = -2
      }
      buffer.append(contentsOf: sourceBytes[p..<t.start])
    }
    if colorIndex != lastColor {
      buffer.append(contentsOf: themeSwitch(t.tokenType))
      lastColor = colorIndex
    }
    buffer.append(contentsOf: sourceBytes[t.start..<t.end])
    p = t.end
  }
  if p < sourceSize {
    if lastColor != -2 {
      buffer.append(contentsOf: baseColor)
    }
    buffer.append(contentsOf: sourceBytes[p...])
  }
  buffer.append(contentsOf: resetBytes)
  let end = now()
  optimizedTotal += (end - start)
}
let optimizedSize = buffer.count

// MARK: - Optimized v2: array-indexed color table (no switch, no function call)

let colorTable: [[UInt8]] = TokenType.allCases.map { themeSwitch($0) }

var optimized2Total: UInt64 = 0
for _ in 0..<iterations {
  buffer.removeAll(keepingCapacity: true)
  let start = now()
  var p = 0
  var lastColor = -1
  for t in resolvedTokens {
    let colorIndex = t.tokenType.rawValue
    if t.start > p {
      if lastColor != -2 {
        buffer.append(contentsOf: baseColor)
        lastColor = -2
      }
      buffer.append(contentsOf: sourceBytes[p..<t.start])
    }
    if colorIndex != lastColor {
      buffer.append(contentsOf: colorTable[colorIndex])
      lastColor = colorIndex
    }
    buffer.append(contentsOf: sourceBytes[t.start..<t.end])
    p = t.end
  }
  if p < sourceSize {
    if lastColor != -2 {
      buffer.append(contentsOf: baseColor)
    }
    buffer.append(contentsOf: sourceBytes[p...])
  }
  buffer.append(contentsOf: resetBytes)
  let end = now()
  optimized2Total += (end - start)
}
let optimized2Size = buffer.count

func ms(_ ns: UInt64) -> String {
  String(format: "%.2f", Double(ns) / Double(iterations) / 1_000_000)
}

let baseMs = Double(baselineTotal) / Double(iterations) / 1_000_000
let optMs = Double(optimizedTotal) / Double(iterations) / 1_000_000
let speedup = baseMs / optMs

let opt2Ms = Double(optimized2Total) / Double(iterations) / 1_000_000

// MARK: - v3: @inline(__always) on switch

@inline(__always)
func themeSwitchInlined(_ t: TokenType) -> [UInt8] {
  themeSwitch(t)
}

var optimized3Total: UInt64 = 0
for _ in 0..<iterations {
  buffer.removeAll(keepingCapacity: true)
  let start = now()
  var p = 0
  var lastColor = -1
  for t in resolvedTokens {
    let colorIndex = t.tokenType.rawValue
    if t.start > p {
      if lastColor != -2 {
        buffer.append(contentsOf: baseColor)
        lastColor = -2
      }
      buffer.append(contentsOf: sourceBytes[p..<t.start])
    }
    if colorIndex != lastColor {
      buffer.append(contentsOf: themeSwitchInlined(t.tokenType))
      lastColor = colorIndex
    }
    buffer.append(contentsOf: sourceBytes[t.start..<t.end])
    p = t.end
  }
  if p < sourceSize {
    if lastColor != -2 {
      buffer.append(contentsOf: baseColor)
    }
    buffer.append(contentsOf: sourceBytes[p...])
  }
  buffer.append(contentsOf: resetBytes)
  let end = now()
  optimized3Total += (end - start)
}
let opt3Ms = Double(optimized3Total) / Double(iterations) / 1_000_000

// MARK: - v4: exact buffer pre-size (no growth during loop)

var optimized4Total: UInt64 = 0
for _ in 0..<iterations {
  buffer = [UInt8]()
  buffer.reserveCapacity(5_500_000) // slightly over actual 5.4MB output
  let start = now()
  var p = 0
  var lastColor = -1
  for t in resolvedTokens {
    let colorIndex = t.tokenType.rawValue
    if t.start > p {
      if lastColor != -2 {
        buffer.append(contentsOf: baseColor)
        lastColor = -2
      }
      buffer.append(contentsOf: sourceBytes[p..<t.start])
    }
    if colorIndex != lastColor {
      buffer.append(contentsOf: themeSwitch(t.tokenType))
      lastColor = colorIndex
    }
    buffer.append(contentsOf: sourceBytes[t.start..<t.end])
    p = t.end
  }
  if p < sourceSize {
    if lastColor != -2 {
      buffer.append(contentsOf: baseColor)
    }
    buffer.append(contentsOf: sourceBytes[p...])
  }
  buffer.append(contentsOf: resetBytes)
  let end = now()
  optimized4Total += (end - start)
}
let opt4Ms = Double(optimized4Total) / Double(iterations) / 1_000_000

// MARK: - v5: withUnsafeBufferPointer on source slice (avoid ArraySlice overhead)

var optimized5Total: UInt64 = 0
for _ in 0..<iterations {
  buffer.removeAll(keepingCapacity: true)
  let start = now()
  var p = 0
  var lastColor = -1
  sourceBytes.withUnsafeBufferPointer { srcPtr in
    for t in resolvedTokens {
      let colorIndex = t.tokenType.rawValue
      if t.start > p {
        if lastColor != -2 {
          buffer.append(contentsOf: baseColor)
          lastColor = -2
        }
        buffer.append(contentsOf: UnsafeBufferPointer(start: srcPtr.baseAddress! + p, count: t.start - p))
      }
      if colorIndex != lastColor {
        buffer.append(contentsOf: themeSwitch(t.tokenType))
        lastColor = colorIndex
      }
      buffer.append(contentsOf: UnsafeBufferPointer(start: srcPtr.baseAddress! + t.start, count: t.end - t.start))
      p = t.end
    }
    if p < sourceSize {
      if lastColor != -2 {
        buffer.append(contentsOf: baseColor)
      }
      buffer.append(contentsOf: UnsafeBufferPointer(start: srcPtr.baseAddress! + p, count: sourceSize - p))
    }
  }
  buffer.append(contentsOf: resetBytes)
  let end = now()
  optimized5Total += (end - start)
}
let opt5Ms = Double(optimized5Total) / Double(iterations) / 1_000_000
let optimized5Size = buffer.count

print("""
Render Loop: Baseline vs Optimized — \(tokenCount) tokens × \(iterations) iterations
═══════════════════════════════════════════════════════════
Baseline (proof-style):         \(ms(baselineTotal))ms  (\(baselineSize) bytes)
v1 (switch):                    \(ms(optimizedTotal))ms  (\(optimizedSize) bytes)
v2 (array index):               \(ms(optimized2Total))ms  (\(optimized2Size) bytes)
v3 (@inline switch):            \(String(format: "%.2f", opt3Ms))ms
v4 (exact pre-size):            \(String(format: "%.2f", opt4Ms))ms
v5 (UnsafeBufferPointer slice): \(String(format: "%.2f", opt5Ms))ms  (\(optimized5Size) bytes)
═══════════════════════════════════════════════════════════
""")
