// Theme protocol indirection benchmark
// Tests: direct static call vs protocol witness table call
// Goal: confirm protocol dispatch adds zero measurable overhead
import Foundation

// --- Simulated TokenType (95 cases, same as dog) ---
enum TokenType: Int, CaseIterable {
  case keyword = 0, keywordConditional, keywordCoroutine, keywordDirective
  case keywordException, keywordFunction, keywordImport, keywordModifier
  case keywordOperator, keywordRepeat, keywordReturn, keywordType
  case function, functionBuiltin, functionCall, functionMethod
  case type, typeBuiltin, typeDefinition
  case variable, variableBuiltin, variableMember, variableParameter
  case string, stringEscape, stringRegex, stringSpecial
  case number, numberFloat, boolean
  case constant, constantBuiltin
  case comment, commentDocumentation
  case punctuationBracket, punctuationDelimiter, `operator`
  case property, attribute, tag, embedded, error
}

// --- Pre-computed ANSI bytes (same pattern as UtilityDarkTheme) ---
let kwBytes: [UInt8] = [0x1B, 0x5B, 0x31, 0x6D, 0x1B, 0x5B, 0x33, 0x6D, 0x1B, 0x5B, 0x33, 0x38, 0x3B, 0x32, 0x3B, 0x32, 0x33, 0x38, 0x3B, 0x31, 0x31, 0x30, 0x3B, 0x35, 0x37, 0x6D]
let fnBytes: [UInt8] = [0x1B, 0x5B, 0x33, 0x38, 0x3B, 0x32, 0x3B, 0x31, 0x32, 0x39, 0x3B, 0x31, 0x35, 0x39, 0x3B, 0x31, 0x33, 0x32, 0x6D]
let strBytes: [UInt8] = [0x1B, 0x5B, 0x33, 0x6D, 0x1B, 0x5B, 0x33, 0x38, 0x3B, 0x32, 0x3B, 0x32, 0x30, 0x35, 0x3B, 0x31, 0x39, 0x30, 0x3B, 0x31, 0x37, 0x31, 0x6D]
let commentBytes: [UInt8] = [0x1B, 0x5B, 0x33, 0x38, 0x3B, 0x32, 0x3B, 0x31, 0x32, 0x39, 0x3B, 0x31, 0x31, 0x36, 0x3B, 0x31, 0x30, 0x30, 0x6D]
let punctBytes: [UInt8] = [0x1B, 0x5B, 0x33, 0x38, 0x3B, 0x32, 0x3B, 0x32, 0x31, 0x37, 0x3B, 0x32, 0x31, 0x37, 0x3B, 0x32, 0x31, 0x37, 0x6D]
let baseBytes: [UInt8] = [0x1B, 0x5B, 0x33, 0x38, 0x3B, 0x32, 0x3B, 0x32, 0x30, 0x35, 0x3B, 0x31, 0x39, 0x30, 0x3B, 0x31, 0x37, 0x31, 0x6D]

// --- Approach 1: Direct static (current dog pattern) ---
enum DirectTheme {
  static let baseColor: [UInt8] = baseBytes
  @inline(never)
  static func color(for token: TokenType) -> [UInt8] {
    switch token {
    case .keyword, .keywordConditional, .keywordCoroutine, .keywordDirective,
         .keywordException, .keywordFunction, .keywordImport, .keywordModifier,
         .keywordOperator, .keywordRepeat, .keywordReturn, .keywordType:
      return kwBytes
    case .function, .functionBuiltin, .functionCall, .functionMethod:
      return fnBytes
    case .string, .stringEscape, .stringRegex, .stringSpecial:
      return strBytes
    case .comment, .commentDocumentation:
      return commentBytes
    case .punctuationBracket, .punctuationDelimiter, .operator:
      return punctBytes
    default:
      return baseBytes
    }
  }
}

// --- Approach 2: Protocol ---
protocol Theme {
  var baseColor: [UInt8] { get }
  func color(for token: TokenType) -> [UInt8]
}

struct ProtocolTheme: Theme {
  let baseColor: [UInt8] = baseBytes
  @inline(never)
  func color(for token: TokenType) -> [UInt8] {
    switch token {
    case .keyword, .keywordConditional, .keywordCoroutine, .keywordDirective,
         .keywordException, .keywordFunction, .keywordImport, .keywordModifier,
         .keywordOperator, .keywordRepeat, .keywordReturn, .keywordType:
      return kwBytes
    case .function, .functionBuiltin, .functionCall, .functionMethod:
      return fnBytes
    case .string, .stringEscape, .stringRegex, .stringSpecial:
      return strBytes
    case .comment, .commentDocumentation:
      return commentBytes
    case .punctuationBracket, .punctuationDelimiter, .operator:
      return punctBytes
    default:
      return baseBytes
    }
  }
}

// --- Approach 3: Array lookup (pre-built [TokenType.rawValue] → [UInt8]) ---
struct ArrayTheme {
  let baseColor: [UInt8] = baseBytes
  let table: [[UInt8]]

  init() {
    var t = [[UInt8]](repeating: baseBytes, count: TokenType.allCases.count)
    for c in TokenType.allCases {
      switch c {
      case .keyword, .keywordConditional, .keywordCoroutine, .keywordDirective,
           .keywordException, .keywordFunction, .keywordImport, .keywordModifier,
           .keywordOperator, .keywordRepeat, .keywordReturn, .keywordType:
        t[c.rawValue] = kwBytes
      case .function, .functionBuiltin, .functionCall, .functionMethod:
        t[c.rawValue] = fnBytes
      case .string, .stringEscape, .stringRegex, .stringSpecial:
        t[c.rawValue] = strBytes
      case .comment, .commentDocumentation:
        t[c.rawValue] = commentBytes
      case .punctuationBracket, .punctuationDelimiter, .operator:
        t[c.rawValue] = punctBytes
      default:
        break
      }
    }
    table = t
  }

  @inline(never)
  func color(for token: TokenType) -> [UInt8] {
    table[token.rawValue]
  }
}

// --- Benchmark harness ---
func bench(_ label: String, iterations: Int, _ body: () -> [UInt8]) {
  // Warm up
  for _ in 0..<1000 { _ = body() }

  let t0 = DispatchTime.now()
  var sink: UInt8 = 0
  for _ in 0..<iterations {
    let result = body()
    sink &+= result[0]
  }
  let elapsed = Double(DispatchTime.now().uptimeNanoseconds - t0.uptimeNanoseconds)
  let perCall = elapsed / Double(iterations)
  print("\(label.padding(toLength: 20, withPad: " ", startingAt: 0)) \(String(format: "%8.2f", perCall)) ns/call  (\(iterations) iters, sink=\(sink))")
}

// --- Simulate real render loop: iterate tokens, look up color for each ---
func benchRenderLoop(_ label: String, rounds: Int, colorFn: (TokenType) -> [UInt8]) {
  // Simulate ~2000 tokens (typical medium file)
  let tokens: [TokenType] = (0..<2000).map { _ in TokenType.allCases.randomElement()! }

  // Warm up
  for _ in 0..<10 {
    var sink: UInt8 = 0
    for t in tokens { sink &+= colorFn(t)[0] }
    _ = sink
  }

  let t0 = DispatchTime.now()
  var sink: UInt8 = 0
  for _ in 0..<rounds {
    for t in tokens {
      sink &+= colorFn(t)[0]
    }
  }
  let elapsed = Double(DispatchTime.now().uptimeNanoseconds - t0.uptimeNanoseconds)
  let totalCalls = rounds * tokens.count
  let perCall = elapsed / Double(totalCalls)
  let perRound = elapsed / Double(rounds) / 1_000_000
  print("\(label.padding(toLength: 20, withPad: " ", startingAt: 0)) \(String(format: "%8.2f", perCall)) ns/call  \(String(format: "%.3f", perRound)) ms/round  (\(tokens.count) tokens × \(rounds) rounds, sink=\(sink))")
}

// --- Run ---
let iters = 10_000_000
let protocolTheme = ProtocolTheme()
let arrayTheme = ArrayTheme()

print("=== Single call benchmark (\(iters) iterations) ===")
bench("Direct static", iterations: iters) { DirectTheme.color(for: .keyword) }
bench("Protocol", iterations: iters) { protocolTheme.color(for: .keyword) }
bench("Array lookup", iterations: iters) { arrayTheme.color(for: .keyword) }

print("")
print("=== Render loop benchmark (2000 tokens, mixed types) ===")
let rounds = 5000
benchRenderLoop("Direct static", rounds: rounds) { DirectTheme.color(for: $0) }
benchRenderLoop("Protocol", rounds: rounds) { protocolTheme.color(for: $0) }
benchRenderLoop("Array lookup", rounds: rounds) { arrayTheme.color(for: $0) }
