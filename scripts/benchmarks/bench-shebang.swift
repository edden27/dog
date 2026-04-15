#!/usr/bin/env swift
// Benchmark: shebang parsing — extract interpreter from first line
// Tests: String split vs UTF8View scan vs raw pointer scan

import Foundation

let iterations = 250_000

// Test inputs — parsing patterns + every interpreter from LanguageMap
let lines: [(input: String, expected: String?)] = [
  // Parsing patterns
  ("#!/usr/bin/python3", "python3"),
  ("#!/usr/bin/env python3", "python3"),
  ("#!/usr/bin/env -S python3", "python3"),
  ("#!/usr/bin/env VAR=val node", "node"),
  ("#!/usr/bin/env -u FOO -S ruby", "ruby"),
  ("#!/bin/bash", "bash"),
  ("#!/usr/bin/env python3.11", "python3"),
  ("// swift code, no shebang", nil),
  ("", nil),
  ("#!/usr/bin/env -S VAR=x OTHER=y ts-node", "ts-node"),
  ("#!  /usr/local/bin/lua", "lua"),
  ("{ \"json\": true }", nil),

  // Every interpreter — JavaScript
  ("#!/usr/bin/env node", "node"),
  ("#!/usr/bin/env nodejs", "nodejs"),
  ("#!/usr/bin/env js", "js"),
  ("#!/usr/bin/env chakra", "chakra"),
  ("#!/usr/bin/env d8", "d8"),
  ("#!/usr/bin/env gjs", "gjs"),
  ("#!/usr/bin/env qjs", "qjs"),
  ("#!/usr/bin/env rhino", "rhino"),
  ("#!/usr/bin/env v8", "v8"),
  ("#!/usr/bin/env v8-shell", "v8-shell"),

  // TypeScript
  ("#!/usr/bin/env bun", "bun"),
  ("#!/usr/bin/env deno", "deno"),
  ("#!/usr/bin/env ts-node", "ts-node"),
  ("#!/usr/bin/env tsx", "tsx"),

  // Python
  ("#!/usr/bin/env python", "python"),
  ("#!/usr/bin/env python2", "python2"),
  ("#!/usr/bin/env py", "py"),
  ("#!/usr/bin/env pypy", "pypy"),
  ("#!/usr/bin/env pypy3", "pypy3"),
  ("#!/usr/bin/env uv", "uv"),

  // Ruby
  ("#!/usr/bin/env ruby", "ruby"),
  ("#!/usr/bin/env macruby", "macruby"),
  ("#!/usr/bin/env jruby", "jruby"),
  ("#!/usr/bin/env rake", "rake"),
  ("#!/usr/bin/env rbx", "rbx"),

  // Rust
  ("#!/usr/bin/env rust-script", "rust-script"),

  // Bash / Shell
  ("#!/usr/bin/env sh", "sh"),
  ("#!/usr/bin/env zsh", "zsh"),
  ("#!/usr/bin/env ash", "ash"),
  ("#!/usr/bin/env dash", "dash"),
  ("#!/usr/bin/env ksh", "ksh"),
  ("#!/usr/bin/env mksh", "mksh"),
  ("#!/usr/bin/env pdksh", "pdksh"),
  ("#!/usr/bin/env rc", "rc"),

  // C
  ("#!/usr/bin/env tcc", "tcc"),

  // Lua
  ("#!/usr/bin/env luajit", "luajit"),

  // Swift
  ("#!/usr/bin/env swift", "swift"),

  // Version stripping variants
  ("#!/usr/bin/env python2.7", "python2"),
  ("#!/usr/bin/env ruby2.7", "ruby2"),
  ("#!/usr/bin/env node18.4", "node18"),

  // Direct path variants (no env)
  ("#!/usr/local/bin/node", "node"),
  ("#!/usr/bin/ruby", "ruby"),
  ("/usr/bin/python3", nil),  // no #!
]

// MARK: - Approach 1: String split + components

func shebangStringSplit(_ line: String) -> String? {
  guard line.hasPrefix("#!") else { return nil }
  let stripped = line.dropFirst(2).trimmingCharacters(in: .whitespaces)
  var parts = stripped.split(separator: " ", omittingEmptySubsequences: true)
  guard !parts.isEmpty else { return nil }

  // Get binary name (last path component)
  let binary = String(parts[0].split(separator: "/").last ?? parts[0])
  parts.removeFirst()

  if binary == "env" {
    // Skip flags, var assignments, and flag arguments
    // -u consumes the next token (the var name to unset)
    while let next = parts.first {
      if next == "-u" {
        parts.removeFirst()  // skip -u
        if !parts.isEmpty { parts.removeFirst() }  // skip its argument
      } else if next.hasPrefix("-") || next.contains("=") {
        parts.removeFirst()
      } else {
        break
      }
    }
    guard let interp = parts.first else { return nil }
    return stripVersion(String(interp))
  }

  return stripVersion(binary)
}

private func stripVersion(_ name: String) -> String {
  // Strip trailing .N version: python3.11 -> python3
  guard let dotIdx = name.lastIndex(of: ".") else { return name }
  let after = name[name.index(after: dotIdx)...]
  if after.allSatisfy(\.isNumber) {
    return String(name[..<dotIdx])
  }
  return name
}

// MARK: - Approach 2: UTF8View scan

func shebangUTF8View(_ line: String) -> String? {
  let utf8 = line.utf8
  guard utf8.count >= 2 else { return nil }
  var i = utf8.startIndex
  guard utf8[i] == 0x23, utf8[utf8.index(after: i)] == 0x21 else { return nil }  // #!
  utf8.formIndex(&i, offsetBy: 2)

  // Skip whitespace
  while i < utf8.endIndex && utf8[i] == 0x20 { utf8.formIndex(after: &i) }
  guard i < utf8.endIndex else { return nil }

  // Find end of first token (path)
  var pathEnd = i
  while pathEnd < utf8.endIndex && utf8[pathEnd] != 0x20 { utf8.formIndex(after: &pathEnd) }

  // Get last path component: scan backward for /
  var binStart = pathEnd
  var tmp = pathEnd
  while tmp > i {
    utf8.formIndex(before: &tmp)
    if utf8[tmp] == 0x2F {  // '/'
      binStart = utf8.index(after: tmp)
      break
    }
  }
  if binStart == pathEnd { binStart = i }  // no slash found

  let binary = String(line[binStart..<pathEnd])

  if binary == "env" {
    // Skip flags, their arguments, and var assignments
    // -u and -S consume the next token as their argument
    var pos = pathEnd
    while pos < utf8.endIndex {
      // Skip spaces
      while pos < utf8.endIndex && utf8[pos] == 0x20 { utf8.formIndex(after: &pos) }
      guard pos < utf8.endIndex else { return nil }
      // Read token
      var tokEnd = pos
      var hasEquals = false
      let isFlag = utf8[pos] == 0x2D  // '-'
      while tokEnd < utf8.endIndex && utf8[tokEnd] != 0x20 {
        if utf8[tokEnd] == 0x3D { hasEquals = true }  // '='
        utf8.formIndex(after: &tokEnd)
      }
      if hasEquals {
        pos = tokEnd
        continue
      }
      if isFlag {
        // Check if this flag consumes the next token (-u, -S)
        let flagStr = String(line[pos..<tokEnd])
        let consumesArg = (flagStr == "-u")
        pos = tokEnd
        if consumesArg {
          // Skip whitespace + next token (the flag's argument)
          while pos < utf8.endIndex && utf8[pos] == 0x20 { utf8.formIndex(after: &pos) }
          while pos < utf8.endIndex && utf8[pos] != 0x20 { utf8.formIndex(after: &pos) }
        }
        continue
      }
      // This is the interpreter
      let name = String(line[pos..<tokEnd])
      return stripVersionUTF8(name)
    }
    return nil
  }

  return stripVersionUTF8(binary)
}

private func stripVersionUTF8(_ name: String) -> String {
  let utf8 = name.utf8
  var lastDot: String.Index?
  var i = utf8.startIndex
  while i < utf8.endIndex {
    if utf8[i] == 0x2E { lastDot = i }
    utf8.formIndex(after: &i)
  }
  guard let dot = lastDot else { return name }
  let after = utf8[utf8.index(after: dot)...]
  if after.allSatisfy({ $0 >= 0x30 && $0 <= 0x39 }) {
    return String(name[..<dot])
  }
  return name
}

// MARK: - Approach 3: withCString raw pointer

func shebangRawPointer(_ line: String) -> String? {
  var result: String?
  line.withCString { cstr in
    let len = strlen(cstr)
    guard len >= 2, cstr[0] == 0x23, cstr[1] == 0x21 else { return }  // #!
    var pos = 2

    // Skip whitespace
    while pos < len && cstr[pos] == 0x20 { pos += 1 }
    guard pos < len else { return }

    // Find end of path token
    let pathStart = pos
    while pos < len && cstr[pos] != 0x20 { pos += 1 }
    let pathEnd = pos

    // Find last / in path
    var binStart = pathEnd
    var j = pathEnd - 1
    while j >= pathStart {
      if cstr[j] == 0x2F {
        binStart = j + 1
        break
      }
      j -= 1
    }
    if binStart == pathEnd { binStart = pathStart }

    let binLen = pathEnd - binStart
    let binary = String(cString: UnsafeRawPointer(cstr + binStart).assumingMemoryBound(to: CChar.self))
    let binaryTrimmed = String(binary.prefix(binLen))

    if binaryTrimmed == "env" {
      while pos < len {
        while pos < len && cstr[pos] == 0x20 { pos += 1 }
        guard pos < len else { return }
        let tokStart = pos
        var hasEquals = false
        let isFlag = cstr[pos] == 0x2D
        while pos < len && cstr[pos] != 0x20 {
          if cstr[pos] == 0x3D { hasEquals = true }
          pos += 1
        }
        if hasEquals { continue }
        if isFlag {
          // Check if -u or -S (consume next token)
          let fLen = pos - tokStart
          let isArgFlag = (fLen == 2 && cstr[tokStart + 1] == 0x75)  // -u consumes next token
          if isArgFlag {
            // Skip whitespace + next token
            while pos < len && cstr[pos] == 0x20 { pos += 1 }
            while pos < len && cstr[pos] != 0x20 { pos += 1 }
          }
          continue
        }
        let tokLen = pos - tokStart
        var buf = [CChar](repeating: 0, count: tokLen + 1)
        memcpy(&buf, cstr + tokStart, tokLen)
        result = stripVersionRaw(String(cString: buf))
        return
      }
      return
    }

    result = stripVersionRaw(binaryTrimmed)
  }
  return result
}

private func stripVersionRaw(_ name: String) -> String {
  guard let dotIdx = name.lastIndex(of: ".") else { return name }
  let after = name[name.index(after: dotIdx)...]
  if after.allSatisfy(\.isNumber) {
    return String(name[..<dotIdx])
  }
  return name
}

// MARK: - Correctness

print("=== Correctness ===")
var failures = 0
for (input, expected) in lines {
  let a = shebangStringSplit(input)
  let b = shebangUTF8View(input)
  let c = shebangRawPointer(input)
  let allMatch = (a == b && b == c)
  let correct = (a == expected)
  let display = input.isEmpty ? "(empty)" : (input.count > 45 ? String(input.prefix(45)) + "..." : input)
  if allMatch && correct {
    print("OK  \(display) -> \(a ?? "nil")")
  } else {
    failures += 1
    if !correct {
      print("WRONG  \(display) -> \(a ?? "nil") (expected \(expected ?? "nil"))")
    }
    if !allMatch {
      print("MISMATCH  \(display)")
      print("  Split=\(a ?? "nil") UTF8=\(b ?? "nil") Raw=\(c ?? "nil")")
    }
  }
}
print("\(lines.count - failures)/\(lines.count) passed")
fflush(stdout)

// MARK: - Benchmark

func bench(_ label: String, _ fn: (String) -> String?) {
  for (input, _) in lines { _ = fn(input) }

  let start = DispatchTime.now()
  for _ in 0..<iterations {
    for (input, _) in lines {
      _ = fn(input)
    }
  }
  let end = DispatchTime.now()
  let ns = Double(end.uptimeNanoseconds - start.uptimeNanoseconds)
  let totalOps = iterations * lines.count
  let nsPerOp = ns / Double(totalOps)
  let opsPerSec = Double(totalOps) / (ns / 1_000_000_000)
  let pad = label.padding(toLength: 28, withPad: " ", startingAt: 0)
  print("\(pad)  \(String(format: "%8.1f", nsPerOp)) ns/op  \(String(format: "%12.0f", opsPerSec)) ops/sec")
  fflush(stdout)
}

print("\n=== Benchmark: shebang parsing (\(iterations)x iters x \(lines.count) lines) ===")
fflush(stdout)
bench("1. String split", shebangStringSplit)
bench("2. UTF8View scan", shebangUTF8View)
bench("3. Raw pointer", shebangRawPointer)
