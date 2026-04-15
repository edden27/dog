#!/usr/bin/env swift
// Benchmark: byteRange lookup strategy
// Current: linear scan through captures per predicate
// Proposed: build dict once per match, O(1) lookup per predicate

import Foundation

// MARK: - Simulated types (mirrors TSQueryCapture layout)

struct MockCapture {
  var index: UInt32
  var startByte: Int
  var endByte: Int
}

// MARK: - Test data generation

// 86k tokens ~ large file. Tree-sitter typically produces 1-3 captures per match.
// We simulate: many matches, each with a few captures, many predicates per pattern.

let predicateCount = 29        // tsx/js/rust worst case
let capturesPerMatch = 3       // typical
let iterations = 100_000       // number of matches to simulate

// Fixed capture set for a match — indices 0,1,2
let captures: [MockCapture] = (0..<capturesPerMatch).map { i in
  MockCapture(index: UInt32(i), startByte: i * 10, endByte: i * 10 + 8)
}

// Predicate target indices — simulate predicates targeting capture 0,1,2 in rotation
let predicateTargets: [UInt32] = (0..<predicateCount).map { UInt32($0 % capturesPerMatch) }

// MARK: - Approach 1: Current — linear scan per predicate

@inline(never)
func linearScan(captures: [MockCapture], predicateTargets: [UInt32]) -> Int {
  var found = 0
  for targetIndex in predicateTargets {
    for cap in captures {
      if cap.index == targetIndex {
        found &+= cap.endByte - cap.startByte
        break
      }
    }
  }
  return found
}

// MARK: - Approach 2: Proposed — build dict once, O(1) per predicate

@inline(never)
func dictLookup(captures: [MockCapture], predicateTargets: [UInt32]) -> Int {
  var rangeMap = [UInt32: (Int, Int)](minimumCapacity: captures.count)
  for cap in captures {
    rangeMap[cap.index] = (cap.startByte, cap.endByte)
  }
  var found = 0
  for targetIndex in predicateTargets {
    if let (start, end) = rangeMap[targetIndex] {
      found &+= end - start
    }
  }
  return found
}

// MARK: - Correctness

let r1 = linearScan(captures: captures, predicateTargets: predicateTargets)
let r2 = dictLookup(captures: captures, predicateTargets: predicateTargets)
print("=== Correctness ===")
print(r1 == r2 ? "OK  both=\(r1)" : "MISMATCH linear=\(r1) dict=\(r2)")
fflush(stdout)

// MARK: - Benchmark

func bench(_ label: String, _ fn: () -> Int) {
  // warmup
  for _ in 0..<1000 { _ = fn() }

  let start = DispatchTime.now()
  var sink = 0
  for _ in 0..<iterations { sink &+= fn() }
  let end = DispatchTime.now()
  _ = sink

  let ns = Double(end.uptimeNanoseconds - start.uptimeNanoseconds)
  let nsPerOp = ns / Double(iterations)
  let opsPerSec = Double(iterations) / (ns / 1_000_000_000)
  let pad = label.padding(toLength: 28, withPad: " ", startingAt: 0)
  print("\(pad)  \(String(format: "%8.1f", nsPerOp)) ns/match  \(String(format: "%10.0f", opsPerSec)) matches/sec")
  fflush(stdout)
}

print("\n=== Benchmark: byteRange lookup (\(iterations) matches × \(predicateCount) predicates × \(capturesPerMatch) captures) ===")
bench("1. linear scan (current)", { linearScan(captures: captures, predicateTargets: predicateTargets) })
bench("2. dict lookup (proposed)", { dictLookup(captures: captures, predicateTargets: predicateTargets) })

// MARK: - Scale: smaller files

print("\n=== Scale: small file (1k matches) ===")
let smallIter = 1_000
func benchSmall(_ label: String, _ fn: () -> Int) {
  for _ in 0..<100 { _ = fn() }
  let start = DispatchTime.now()
  var sink = 0
  for _ in 0..<smallIter { sink &+= fn() }
  let end = DispatchTime.now()
  _ = sink
  let ns = Double(end.uptimeNanoseconds - start.uptimeNanoseconds)
  let nsPerOp = ns / Double(smallIter)
  let pad = label.padding(toLength: 28, withPad: " ", startingAt: 0)
  print("\(pad)  \(String(format: "%8.1f", nsPerOp)) ns/match")
  fflush(stdout)
}
benchSmall("1. linear scan (current)", { linearScan(captures: captures, predicateTargets: predicateTargets) })
benchSmall("2. dict lookup (proposed)", { dictLookup(captures: captures, predicateTargets: predicateTargets) })
