#!/usr/bin/env swift
// Benchmark: extracting file extension from a path/filename
// Tests NSString vs pure Swift vs UTF8View approaches

import Foundation

let iterations = 1_000_000

// Test inputs — filenames (already extracted from path)
let filenames = [
  "Button.swift",
  "index.js",
  "config.yaml.bak",
  "Makefile",
  ".bashrc",
  "deep.test.spec.tsx",
  "BUILD",
  "jquery.min.js",
  "parser.c",
  "README.md",
  "Package.resolved",
  "noext",
]

// MARK: - Approach 1: NSString pathExtension

func extNSString(_ name: String) -> String? {
  let ext = (name as NSString).pathExtension
  return ext.isEmpty ? nil : ".\(ext)"
}

// MARK: - Approach 2: Swift lastIndex(of:) on String

func extSwiftString(_ name: String) -> String? {
  guard let dotIdx = name.lastIndex(of: ".") else { return nil }
  // Dot at position 0 means dotfile (.bashrc), not an extension
  if dotIdx == name.startIndex { return nil }
  return String(name[dotIdx...])
}

// MARK: - Approach 3: UTF8View scan backward

func extUTF8View(_ name: String) -> String? {
  let utf8 = name.utf8
  var i = utf8.endIndex
  while i > utf8.startIndex {
    utf8.formIndex(before: &i)
    if utf8[i] == 0x2E {  // '.'
      // Dot at start = dotfile, not extension
      if i == utf8.startIndex { return nil }
      return String(name[i...])
    }
  }
  return nil
}

// MARK: - Approach 4: withCString raw pointer scan backward

func extRawPointer(_ name: String) -> String? {
  var result: String?
  name.withCString { cstr in
    let len = strlen(cstr)
    guard len > 1 else { return }
    var i = len - 1
    while i > 0 {
      if cstr[i] == 0x2E {  // '.'
        result = String(cString: cstr + i)
        return
      }
      i -= 1
    }
    // i == 0: dot at start = dotfile
  }
  return result
}

// MARK: - Correctness check

print("=== Correctness ===")
for name in filenames {
  let a = extNSString(name)
  let b = extSwiftString(name)
  let c = extUTF8View(name)
  let d = extRawPointer(name)
  let match = (a == b && b == c && c == d)
  print("\(match ? "OK" : "MISMATCH")  \(name) -> \(a ?? "nil")")
  if !match {
    print("  NSString=\(a ?? "nil") Swift=\(b ?? "nil") UTF8=\(c ?? "nil") Raw=\(d ?? "nil")")
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
  let pad = label.padding(toLength: 24, withPad: " ", startingAt: 0)
  print("\(pad)  \(String(format: "%8.1f", nsPerOp)) ns/op  \(String(format: "%12.0f", opsPerSec)) ops/sec")
  fflush(stdout)
}

print("\n=== Benchmark: extension from filename (\(iterations)x iters x \(filenames.count) names) ===")
fflush(stdout)
bench("1. NSString", extNSString)
bench("2. Swift lastIndex", extSwiftString)
bench("3. UTF8View", extUTF8View)
bench("4. Raw pointer", extRawPointer)
