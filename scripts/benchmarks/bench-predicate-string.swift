#!/usr/bin/env swift
// Benchmark: predicate string comparison strategy
// Current: String(bytes:encoding:) allocation then Set<String>.contains
// Proposed: direct byte slice comparison, no allocation

import Foundation

// MARK: - Test data

// Simulated source file as bytes
let sourceText = """
arguments module console window document NaN Infinity strong em code href src
function myFunc() { arguments.length; console.log(module.exports); }
let x = window.document.getElementById('foo');
"""
let source: [UInt8] = Array(sourceText.utf8)

// Simulated captures — byte ranges of tokens in the source
struct MockCapture {
  let start: Int
  let end: Int
  var bytes: ArraySlice<UInt8> { source[start..<end] }
}

// Build captures from known words in source
func findCaptures(_ words: [String]) -> [MockCapture] {
  var result: [MockCapture] = []
  for word in words {
    let wordBytes = Array(word.utf8)
    for i in 0...(source.count - wordBytes.count) {
      if Array(source[i..<(i + wordBytes.count)]) == wordBytes {
        result.append(MockCapture(start: i, end: i + wordBytes.count))
        break
      }
    }
  }
  return result
}

// JS variable.builtin anyOf set
let anyOfStrings: Set<String> = ["arguments", "module", "console", "window", "document"]
let anyOfBytes: Set<[UInt8]> = Set(anyOfStrings.map { Array($0.utf8) })

let testWords = ["arguments", "module", "console", "window", "document",
                 "function", "myFunc", "length", "log", "exports",
                 "getElementById", "foo", "NaN", "Infinity", "x"]
let captures = findCaptures(testWords)

let iterations = 1_000_000

// MARK: - Approach 1: Current — String allocation + Set<String>.contains

@inline(never)
func currentApproach(captures: [MockCapture], set: Set<String>) -> Int {
  var hits = 0
  for cap in captures {
    if let text = String(bytes: source[cap.start..<cap.end], encoding: .utf8) {
      if set.contains(text) { hits += 1 }
    }
  }
  return hits
}

// MARK: - Approach 2: Proposed — byte slice + Set<[UInt8]>.contains, no allocation

@inline(never)
func proposedApproach(captures: [MockCapture], set: Set<[UInt8]>) -> Int {
  var hits = 0
  for cap in captures {
    let slice = Array(source[cap.start..<cap.end])
    if set.contains(slice) { hits += 1 }
  }
  return hits
}

// MARK: - Approach 3: withUnsafeBytes hash — avoid Array copy too

// Pre-hash the set values for direct comparison
@inline(never)
func withUnsafeBytesApproach(captures: [MockCapture], set: Set<[UInt8]>) -> Int {
  var hits = 0
  for cap in captures {
    // Compare each set member's bytes directly against source slice
    var matched = false
    let len = cap.end - cap.start
    for member in set {
      guard member.count == len else { continue }
      if source[cap.start..<cap.end].elementsEqual(member) {
        matched = true
        break
      }
    }
    if matched { hits += 1 }
  }
  return hits
}

// MARK: - Correctness

let r1 = currentApproach(captures: captures, set: anyOfStrings)
let r2 = proposedApproach(captures: captures, set: anyOfBytes)
let r3 = withUnsafeBytesApproach(captures: captures, set: anyOfBytes)
print("=== Correctness ===")
print(r1 == r2 && r2 == r3 ? "OK  hits=\(r1)" : "MISMATCH current=\(r1) proposed=\(r2) unsafe=\(r3)")
fflush(stdout)

// MARK: - Benchmark

func bench(_ label: String, _ fn: () -> Int) {
  for _ in 0..<1000 { _ = fn() }
  let start = DispatchTime.now()
  var sink = 0
  for _ in 0..<iterations { sink &+= fn() }
  let end = DispatchTime.now()
  _ = sink
  let ns = Double(end.uptimeNanoseconds - start.uptimeNanoseconds)
  let nsPerOp = ns / Double(iterations * captures.count)
  let pad = label.padding(toLength: 36, withPad: " ", startingAt: 0)
  print("\(pad)  \(String(format: "%7.1f", nsPerOp)) ns/capture")
  fflush(stdout)
}

print("\n=== Benchmark: anyOf predicate (\(iterations)x iters × \(captures.count) captures) ===")
bench("1. String alloc + Set<String>  (current)", { currentApproach(captures: captures, set: anyOfStrings) })
bench("2. Array([UInt8]) + Set<[UInt8]>        ", { proposedApproach(captures: captures, set: anyOfBytes) })
bench("3. elementsEqual no Array copy          ", { withUnsafeBytesApproach(captures: captures, set: anyOfBytes) })
