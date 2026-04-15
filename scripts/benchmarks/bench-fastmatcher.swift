#!/usr/bin/env swift
// Benchmark: NSRegularExpression vs byte-level FastMatcher for patterns
// that currently fall through to regex in FastMatcher.from()
//
// Patterns tested:
//   ^--              (Lua comment prefix)
//   ^__builtin_      (C builtin prefix)
//   ^///$            (Swift doc comment exact)
//   ^///[^/]         (Swift doc comment with content)
//   ^[A-Z].*[a-z]   (mixed case — starts upper, contains lower)

import Foundation

// MARK: - Test inputs per pattern

let luaInputs = ["--comment", "-- another", "-single", "nodash", "--", "x--y"]
let builtinInputs = ["__builtin_expect", "__builtin_clz", "__builtin_trap", "__other", "_builtin_x", "normal"]
let docExactInputs = ["///", "////", "//", "// comment", "///x", "/"]
let docContentInputs = ["/// comment", "///x", "////", "/// ", "//comment", "///"]
let mixedInputs = ["MyClass", "Hello", "ALLCAPS", "lowercase", "Abc", "A1b", "Z", "Zz"]

// MARK: - NSRegularExpression (current path)

func makeRegex(_ pattern: String) -> NSRegularExpression {
  try! NSRegularExpression(pattern: pattern)
}

let luaRegex      = makeRegex("^--")
let builtinRegex  = makeRegex("^__builtin_")
let docExactRegex = makeRegex("^///$")
let docContRegex  = makeRegex("^///[^/]")
let mixedRegex    = makeRegex("^[A-Z].*[a-z]")

@inline(never)
func matchRegex(_ regex: NSRegularExpression, _ inputs: [String]) -> Int {
  var hits = 0
  for s in inputs {
    if regex.firstMatch(in: s, range: NSRange(0..<s.utf16.count)) != nil { hits += 1 }
  }
  return hits
}

// MARK: - Byte-level fast matchers (proposed)

@inline(never)
func matchLuaFast(_ inputs: [String]) -> Int {
  var hits = 0
  for s in inputs {
    let b = s.utf8
    if b.count >= 2, b[b.startIndex] == 0x2D, b[b.index(after: b.startIndex)] == 0x2D { hits += 1 }
  }
  return hits
}

@inline(never)
func matchBuiltinFast(_ inputs: [String]) -> Int {
  // ^__builtin_ — first 10 bytes: _ _ b u i l t i n _
  let prefix: [UInt8] = [0x5F, 0x5F, 0x62, 0x75, 0x69, 0x6C, 0x74, 0x69, 0x6E, 0x5F]
  var hits = 0
  for s in inputs {
    let b = Array(s.utf8)
    if b.count >= prefix.count, b.prefix(prefix.count).elementsEqual(prefix) { hits += 1 }
  }
  return hits
}

@inline(never)
func matchDocExactFast(_ inputs: [String]) -> Int {
  // ^///$ — exactly 3 slashes
  var hits = 0
  for s in inputs {
    let b = Array(s.utf8)
    if b.count == 3, b[0] == 0x2F, b[1] == 0x2F, b[2] == 0x2F { hits += 1 }
  }
  return hits
}

@inline(never)
func matchDocContentFast(_ inputs: [String]) -> Int {
  // ^///[^/] — 3 slashes then a non-slash
  var hits = 0
  for s in inputs {
    let b = Array(s.utf8)
    if b.count >= 4, b[0] == 0x2F, b[1] == 0x2F, b[2] == 0x2F, b[3] != 0x2F { hits += 1 }
  }
  return hits
}

@inline(never)
func matchMixedFast(_ inputs: [String]) -> Int {
  // ^[A-Z].*[a-z] — starts uppercase, contains at least one lowercase
  var hits = 0
  for s in inputs {
    let b = Array(s.utf8)
    guard b.count >= 2, b[0] >= 0x41, b[0] <= 0x5A else { continue }
    if b.dropFirst().contains(where: { $0 >= 0x61 && $0 <= 0x7A }) { hits += 1 }
  }
  return hits
}

// MARK: - Correctness

print("=== Correctness ===")
func check(_ label: String, _ a: Int, _ b: Int) {
  print(a == b ? "OK  \(label) hits=\(a)" : "MISMATCH  \(label) regex=\(a) fast=\(b)")
}
check("^--           ", matchRegex(luaRegex, luaInputs), matchLuaFast(luaInputs))
check("^__builtin_   ", matchRegex(builtinRegex, builtinInputs), matchBuiltinFast(builtinInputs))
check("^///$         ", matchRegex(docExactRegex, docExactInputs), matchDocExactFast(docExactInputs))
check("^///[^/]      ", matchRegex(docContRegex, docContentInputs), matchDocContentFast(docContentInputs))
check("^[A-Z].*[a-z]", matchRegex(mixedRegex, mixedInputs), matchMixedFast(mixedInputs))
fflush(stdout)

// MARK: - Benchmark

let iterations = 500_000

func bench(_ label: String, _ fn: () -> Int) {
  for _ in 0..<500 { _ = fn() }
  let start = DispatchTime.now()
  var sink = 0
  for _ in 0..<iterations { sink &+= fn() }
  let end = DispatchTime.now()
  _ = sink
  let ns = Double(end.uptimeNanoseconds - start.uptimeNanoseconds)
  let nsPerOp = ns / Double(iterations)
  let pad = label.padding(toLength: 38, withPad: " ", startingAt: 0)
  print("\(pad)  \(String(format: "%7.1f", nsPerOp)) ns/call")
  fflush(stdout)
}

print("\n=== Benchmark (\(iterations) iters) ===")

print("\n-- ^-- (Lua comment, \(luaInputs.count) inputs)")
bench("  regex  NSRegularExpression", { matchRegex(luaRegex, luaInputs) })
bench("  fast   2-byte check       ", { matchLuaFast(luaInputs) })

print("\n-- ^__builtin_ (C builtin, \(builtinInputs.count) inputs)")
bench("  regex  NSRegularExpression", { matchRegex(builtinRegex, builtinInputs) })
bench("  fast   prefix bytes       ", { matchBuiltinFast(builtinInputs) })

print("\n-- ^///$ (Swift doc exact, \(docExactInputs.count) inputs)")
bench("  regex  NSRegularExpression", { matchRegex(docExactRegex, docExactInputs) })
bench("  fast   3-byte + length    ", { matchDocExactFast(docExactInputs) })

print("\n-- ^///[^/] (Swift doc content, \(docContentInputs.count) inputs)")
bench("  regex  NSRegularExpression", { matchRegex(docContRegex, docContentInputs) })
bench("  fast   4-byte check       ", { matchDocContentFast(docContentInputs) })

print("\n-- ^[A-Z].*[a-z] (mixed case, \(mixedInputs.count) inputs)")
bench("  regex  NSRegularExpression", { matchRegex(mixedRegex, mixedInputs) })
bench("  fast   scan for lowercase  ", { matchMixedFast(mixedInputs) })
