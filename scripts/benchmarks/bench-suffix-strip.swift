#!/usr/bin/env swift
// Benchmark: stripping ignored suffixes (.bak, .old, .orig, ~, etc.)
// before retrying extension lookup
// Tests: hasSuffix loop vs UTF8View vs raw pointer vs reversed-prefix-check

import Foundation

let iterations = 1_000_000

let ignoredSuffixes = [
  "~", ".bak", ".old", ".orig", ".in",
  ".dpkg-dist", ".dpkg-new", ".dpkg-old", ".dpkg-tmp",
  ".ucf-dist", ".ucf-new", ".ucf-old",
  ".rpmnew", ".rpmorig", ".rpmsave",
]

// Test filenames — mix of match, no-match, short, long
let filenames = [
  "config.yaml.bak",        // match .bak
  "script.sh~",             // match ~
  "settings.json.orig",     // match .orig
  "Makefile.in",            // match .in
  "app.conf.dpkg-dist",     // match .dpkg-dist
  "Button.swift",           // no match
  "index.js",               // no match
  ".bashrc",                // no match
  "BUILD",                  // no match
  "very-long-filename-with-lots-of-parts.test.spec.tsx",  // no match
  "config.yaml.rpmsave",    // match .rpmsave
  "noext",                  // no match
]

// MARK: - Approach 1: Swift hasSuffix loop (returns stripped name or nil)

func stripHasSuffix(_ name: String) -> String? {
  for suffix in ignoredSuffixes {
    if name.hasSuffix(suffix) {
      return String(name.dropLast(suffix.count))
    }
  }
  return nil
}

// MARK: - Approach 2: UTF8View suffix check

func stripUTF8View(_ name: String) -> String? {
  let utf8 = name.utf8
  let count = utf8.count
  for suffix in ignoredSuffixes {
    let suffixUTF8 = suffix.utf8
    let sLen = suffixUTF8.count
    guard sLen <= count else { continue }
    // Compare suffix bytes from the end
    var match = true
    var ni = utf8.index(utf8.endIndex, offsetBy: -sLen)
    var si = suffixUTF8.startIndex
    while si < suffixUTF8.endIndex {
      if utf8[ni] != suffixUTF8[si] {
        match = false
        break
      }
      utf8.formIndex(after: &ni)
      suffixUTF8.formIndex(after: &si)
    }
    if match {
      let end = utf8.index(utf8.endIndex, offsetBy: -sLen)
      return String(name[name.startIndex..<end])
    }
  }
  return nil
}

// MARK: - Approach 3: withCString raw pointer

func stripRawPointer(_ name: String) -> String? {
  var result: String?
  name.withCString { cstr in
    let len = strlen(cstr)
    for suffix in ignoredSuffixes {
      suffix.withCString { sstr in
        guard result == nil else { return }
        let sLen = strlen(sstr)
        guard sLen <= len else { return }
        if memcmp(cstr + len - sLen, sstr, sLen) == 0 {
          // Match — create stripped string
          let buf = UnsafeMutablePointer<CChar>.allocate(capacity: len - sLen + 1)
          memcpy(buf, cstr, len - sLen)
          buf[len - sLen] = 0
          result = String(cString: buf)
          buf.deallocate()
        }
      }
    }
  }
  return result
}

// MARK: - Approach 4: pre-convert suffixes to [UInt8] arrays, compare with withContiguousStorageIfAvailable

let suffixBytes: [[UInt8]] = ignoredSuffixes.map { Array($0.utf8) }

func stripPrecomputed(_ name: String) -> String? {
  var found: Int?
  name.utf8.withContiguousStorageIfAvailable { buf in
    let len = buf.count
    for (idx, sb) in suffixBytes.enumerated() {
      let sLen = sb.count
      guard sLen <= len else { continue }
      if memcmp(buf.baseAddress! + len - sLen, sb, sLen) == 0 {
        found = idx
        return
      }
    }
  }
  guard let idx = found else { return nil }
  let sLen = suffixBytes[idx].count
  return String(name.dropLast(sLen))
}

// MARK: - Correctness

print("=== Correctness ===")
for name in filenames {
  let a = stripHasSuffix(name)
  let b = stripUTF8View(name)
  let c = stripRawPointer(name)
  let d = stripPrecomputed(name)
  let match = (a == b && b == c && c == d)
  print("\(match ? "OK" : "MISMATCH")  \(name) -> \(a ?? "nil")")
  if !match {
    print("  hasSuffix=\(a ?? "nil") UTF8View=\(b ?? "nil") Raw=\(c ?? "nil") Precomp=\(d ?? "nil")")
  }
}
fflush(stdout)

// MARK: - Benchmark

func bench(_ label: String, _ fn: (String) -> String?) {
  for name in filenames { _ = fn(name) }

  let start = DispatchTime.now()
  for _ in 0..<iterations {
    for name in filenames {
      _ = fn(name)
    }
  }
  let end = DispatchTime.now()
  let ns = Double(end.uptimeNanoseconds - start.uptimeNanoseconds)
  let totalOps = iterations * filenames.count
  let nsPerOp = ns / Double(totalOps)
  let opsPerSec = Double(totalOps) / (ns / 1_000_000_000)
  let pad = label.padding(toLength: 28, withPad: " ", startingAt: 0)
  print("\(pad)  \(String(format: "%8.1f", nsPerOp)) ns/op  \(String(format: "%12.0f", opsPerSec)) ops/sec")
  fflush(stdout)
}

print("\n=== Benchmark: suffix stripping (\(iterations)x iters x \(filenames.count) names) ===")
fflush(stdout)
bench("1. Swift hasSuffix", stripHasSuffix)
bench("2. UTF8View manual", stripUTF8View)
bench("3. Raw pointer + memcmp", stripRawPointer)
bench("4. Precomputed + memcmp", stripPrecomputed)
