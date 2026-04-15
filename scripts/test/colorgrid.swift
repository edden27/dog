#!/usr/bin/env swift
/// TrueColor grid using dog's exact hex→RGB→ANSI pipeline.
import Foundation
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

// — Copied exactly from ANSIOutput.swift —

struct RGB {
  let red: UInt8
  let green: UInt8
  let blue: UInt8
}

func parseHex(_ hex: String) -> RGB? {
  var cleaned = hex
  if cleaned.hasPrefix("#") {
    cleaned = String(cleaned.dropFirst())
  }
  guard cleaned.count == 6, let value = UInt32(cleaned, radix: 16) else {
    return nil
  }
  return RGB(
    red: UInt8((value >> 16) & 0xFF),
    green: UInt8((value >> 8) & 0xFF),
    blue: UInt8(value & 0xFF)
  )
}

func bgFromHex(_ hex: String) -> [UInt8] {
  guard let rgb = parseHex(hex) else { return [] }
  return Array("\u{1B}[48;2;\(rgb.red);\(rgb.green);\(rgb.blue)m".utf8)
}

// — Output buffer (same as ANSIOutput) —

var buffer: [UInt8] = []
buffer.reserveCapacity(512 * 1024)

func append(_ bytes: [UInt8]) { buffer.append(contentsOf: bytes) }
func append(_ s: String) { buffer.append(contentsOf: s.utf8) }

let resetBytes: [UInt8] = Array("\u{1B}[0m".utf8)
let eraseLineBytes: [UInt8] = Array("\u{1B}[K".utf8)

// — HSV → hex string —

func hsvToHex(_ h: Double, _ s: Double, _ v: Double) -> String {
  let i = Int(h * 6.0) % 6
  let f = h * 6.0 - Double(Int(h * 6.0))
  let p = v * (1.0 - s)
  let q = v * (1.0 - f * s)
  let t = v * (1.0 - (1.0 - f) * s)
  let r, g, b: Double
  switch i {
  case 0: (r, g, b) = (v, t, p)
  case 1: (r, g, b) = (q, v, p)
  case 2: (r, g, b) = (p, v, t)
  case 3: (r, g, b) = (p, q, v)
  case 4: (r, g, b) = (t, p, v)
  default: (r, g, b) = (v, p, q)
  }
  return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
}

// — Get terminal size —

var ws = winsize()
_ = ioctl(STDOUT_FILENO, UInt(TIOCGWINSZ), &ws)
let cols = Int(ws.ws_col)
let rows = Int(ws.ws_row) - 2

// — Render grid: generate hex string → parseHex → ANSI bytes —

for y in 0..<rows {
  let yf = Double(y) / Double(rows)
  let s: Double
  let v: Double
  if yf < 0.5 {
    s = 1.0
    v = 1.0 - yf * 2.0
  } else {
    s = 1.0 - (yf - 0.5) * 2.0
    v = (yf - 0.5) * 2.0
  }
  for x in 0..<cols {
    let h = Double(x) / Double(cols)
    let hex = hsvToHex(h, s, v)
    append(bgFromHex(hex))
    append(" ")
  }
  append(eraseLineBytes)
  buffer.append(0x0A)
}
append(resetBytes)

buffer.withUnsafeBufferPointer { ptr in
  guard let base = ptr.baseAddress else { return }
  var remaining = ptr.count
  var offset = 0
  while remaining > 0 {
    let written = write(STDOUT_FILENO, base + offset, remaining)
    if written <= 0 { break }
    offset += written
    remaining -= written
  }
}
