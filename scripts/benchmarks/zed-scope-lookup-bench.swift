// Benchmark: Zed scope name → TokenType dictionary lookup performance
// Tests the translation table that maps Zed theme scope names to dog TokenType cases.
// Run: swift tests/benchmarks/zed-scope-lookup-bench.swift

import Foundation

// ─── TokenType (copied from cli/Sources/dog/Theme/TokenType.swift) ───

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
}

// ─── Translation table: Zed scope → TokenType ───
// Direct matches + name translations from docs/zed-theme-mapping.md

let zedScopeToTokenType: [String: TokenType] = [
  // Direct matches
  "attribute": .attribute,
  "boolean": .boolean,
  "comment": .comment,
  "comment.doc": .commentDocumentation,
  "constant": .constant,
  "constant.builtin": .constantBuiltin,
  "constructor": .constructor,
  "embedded": .embedded,
  "function": .function,
  "keyword": .keyword,
  "label": .label,
  "number": .number,
  "operator": .operator,
  "property": .property,
  "punctuation.bracket": .punctuationBracket,
  "punctuation.delimiter": .punctuationDelimiter,
  "punctuation.special": .punctuationSpecial,
  "string": .string,
  "string.escape": .stringEscape,
  "string.regex": .stringRegex,
  "string.special": .stringSpecial,
  "string.special.symbol": .stringSpecialSymbol,
  "tag": .tag,
  "text.literal": .textLiteral,
  "type": .type,
  "type.builtin": .typeBuiltin,
  "variable": .variable,
  "variable.parameter": .variableParameter,
  // Name translations
  "variable.special": .variableBuiltin,
  "link_uri": .textUri,
  "link_text": .markupLinkLabel,
  "title": .textTitle,
  "punctuation.list_marker": .markupList,
  "tag.doctype": .tagBuiltin,
  // Fallback mappings (Zed scopes with no direct dog equivalent)
  "enum": .type,
  "variant": .constant,
  "preproc": .keywordDirective,
  // Keyword sub-scopes from Zed
  "keyword.operator": .keywordOperator,
]

// ─── Benchmark ───

// Simulate realistic lookup patterns: these are the scopes a real Zed theme file contains
let testScopes = [
  "keyword", "keyword.operator", "function", "variable", "variable.special",
  "type", "type.builtin", "string", "string.escape", "string.regex",
  "string.special.symbol", "comment", "comment.doc", "number", "boolean",
  "operator", "property", "attribute", "constant", "constant.builtin",
  "constructor", "tag", "embedded", "punctuation.bracket", "punctuation.delimiter",
  "punctuation.special", "text.literal", "variable.parameter", "label",
  "link_uri", "link_text", "title", "punctuation.list_marker", "tag.doctype",
  "enum", "variant", "preproc",
  // A few that won't match (to test miss path)
  "hint", "predictive", "primary",
]

let iterations = 1_000_000

// Warmup
for _ in 0..<1000 {
  for scope in testScopes {
    _ = zedScopeToTokenType[scope]
  }
}

// Timed run
let t0 = DispatchTime.now()
var hitCount = 0
var missCount = 0
for _ in 0..<iterations {
  for scope in testScopes {
    if zedScopeToTokenType[scope] != nil {
      hitCount += 1
    } else {
      missCount += 1
    }
  }
}
let t1 = DispatchTime.now()

let totalNs = Double(t1.uptimeNanoseconds - t0.uptimeNanoseconds)
let totalMs = totalNs / 1_000_000
let lookupsTotal = iterations * testScopes.count
let nsPerLookup = totalNs / Double(lookupsTotal)

print("Zed scope → TokenType dictionary lookup benchmark")
print("─────────────────────────────────────────────────")
print("Dictionary size:  \(zedScopeToTokenType.count) entries")
print("Test scopes:      \(testScopes.count) (\(testScopes.count - 3) hits, 3 misses)")
print("Iterations:       \(iterations)")
print("Total lookups:    \(lookupsTotal)")
print(String(format: "Total time:       %.2fms", totalMs))
print(String(format: "Per lookup:       %.1fns", nsPerLookup))
print("Hits:             \(hitCount)")
print("Misses:           \(missCount)")

// Sanity check: verify all expected hits actually hit
print("\n─── Verification ───")
var verified = 0
for scope in testScopes {
  if let token = zedScopeToTokenType[scope] {
    verified += 1
    print("  \(scope) → \(token) (rawValue: \(token.rawValue))")
  } else {
    print("  \(scope) → (no match)")
  }
}
print("Verified: \(verified)/\(testScopes.count - 3) expected hits")
