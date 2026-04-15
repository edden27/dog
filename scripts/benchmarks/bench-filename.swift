#!/usr/bin/env swift
// Benchmark: extracting filename from a path
// Tests NSString vs pure Swift vs UInt8 scanning

import Foundation

let iterations = 1_000_000

// Test paths — mix of depths, edge cases
let paths = [
  "/usr/local/bin/Makefile",
  "/home/user/projects/app/src/components/Button.swift",
  "Package.swift",
  "/a/b/c/d/e/f/g/h/deep.rs",
  ".bashrc",
  "/Users/dev/Code/treesitter-cli/cli/Sources/dog/Commands/PrintCommand.swift",
  "BUILD",
  "/tmp/config.yaml.bak",
]

// MARK: - Approach 1: NSString

func filenameNSString(_ path: String) -> String {
  (path as NSString).lastPathComponent
}

// MARK: - Approach 2: Swift lastIndex(of:) + Substring

func filenameSwiftSubstring(_ path: String) -> String {
  if let idx = path.lastIndex(of: "/") {
    return String(path[path.index(after: idx)...])
  }
  return path
}

// MARK: - Approach 3: Swift UTF8View scan backward

func filenameUTF8(_ path: String) -> String {
  let utf8 = path.utf8
  var i = utf8.endIndex
  while i > utf8.startIndex {
    utf8.formIndex(before: &i)
    if utf8[i] == 0x2F {  // '/'
      let start = utf8.index(after: i)
      return String(path[start...])
    }
  }
  return path
}

// MARK: - Approach 4: withCString raw pointer scan backward

func filenameRawUTF8(_ path: String) -> String {
  var result = path
  path.withCString { cstr in
    let len = strlen(cstr)
    guard len > 0 else { return }
    var i = len - 1
    while i > 0 {
      if cstr[i] == 0x2F {  // '/'
        result = String(cString: cstr + i + 1)
        return
      }
      i -= 1
    }
    if cstr[0] == 0x2F {
      result = String(cString: cstr + 1)
    }
  }
  return result
}

// MARK: - Correctness check

print("=== Correctness ===")
fflush(stdout)
for path in paths {
  let a = filenameNSString(path)
  let b = filenameSwiftSubstring(path)
  let c = filenameUTF8(path)
  let d = filenameRawUTF8(path)
  let match = (a == b && b == c && c == d)
  print("\(match ? "OK" : "MISMATCH")  \(path) -> \(a)")
  if !match {
    print("  NSString=\(a) Substring=\(b) UTF8=\(c) Raw=\(d)")
  }
}
fflush(stdout)

// MARK: - Benchmark

func bench(_ label: String, _ fn: (String) -> String) {
  // Warmup
  for path in paths { _ = fn(path) }

  let start = DispatchTime.now()
  for _ in 0..<iterations {
    for path in paths {
      _ = fn(path)
    }
  }
  let end = DispatchTime.now()
  let ns = Double(end.uptimeNanoseconds - start.uptimeNanoseconds)
  let totalOps = iterations * paths.count
  let nsPerOp = ns / Double(totalOps)
  let opsPerSec = Double(totalOps) / (ns / 1_000_000_000)
  let pad = label.padding(toLength: 24, withPad: " ", startingAt: 0)
  print("\(pad)  \(String(format: "%8.1f", nsPerOp)) ns/op  \(String(format: "%12.0f", opsPerSec)) ops/sec")
  fflush(stdout)
}

print("\n=== Benchmark: filename from path (\(iterations)x iters x \(paths.count) paths) ===")
fflush(stdout)
bench("1. NSString", filenameNSString)
bench("2. Swift Substring", filenameSwiftSubstring)
bench("3. Swift UTF8View", filenameUTF8)
bench("4. Raw UInt8 pointer", filenameRawUTF8)
