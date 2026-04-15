// Alpha composite compute benchmark.
//
// Measures the pure compute cost of blending N foreground colors with alpha
// over a known background. No IO, no JSON — just the math that would run once
// per theme load when we need to resolve #rrggbbaa colors to terminal RGB.
//
// Blend formula (integer, no FP):
//   out = (fg * a + bg * (255 - a) + 127) / 255
//
// Run: swift -O tests/themes/bench_composite.swift
//
// Results (release, macOS M-series):
//   95 colors mixed α     median=~0ns     (below timer resolution)
//   95 colors all α=255   median=~0ns     (fast path)
//   1,000 colors mixed    median=1.00µs   ~1ns/color
//   10,000 colors mixed   median=11.00µs  ~1.1ns/color
//   1,000,000 colors      median=1.108ms  ~1.1ns/color
//
// Takeaway: ~1ns per color. Realistic theme load (95 TokenTypes) = unmeasurable.
// Adding alpha compositing to theme load is free. Ship it.
//
// Correctness:
//   #d07277ff over #1e1e2e → #d07277  (opaque passthrough)
//   #ffffff80 over #1e1e2e → #8f8f97  (50% white blended)
//   #ff000000 over #1e1e2e → #1e1e2e  (0% alpha, pure bg)

#if canImport(Darwin)
  import Darwin
#elseif canImport(Glibc)
  import Glibc
#endif

@inline(__always)
func nowNanos() -> UInt64 {
  var timespec = timespec()
  clock_gettime(CLOCK_MONOTONIC, &timespec)
  return UInt64(timespec.tv_sec) * 1_000_000_000 + UInt64(timespec.tv_nsec)
}

func nsToString(_ nanos: UInt64) -> String {
  if nanos < 1_000 { return "\(nanos)ns" }
  if nanos < 1_000_000 {
    let hundredths = (nanos + 5) / 10
    let whole = hundredths / 100
    let frac = hundredths % 100
    return "\(whole).\(frac < 10 ? "0" : "")\(frac)µs"
  }
  let micros = (nanos + 500) / 1_000
  let whole = micros / 1_000
  let frac = micros % 1_000
  var fracStr = "\(frac)"
  while fracStr.count < 3 { fracStr = "0" + fracStr }
  return "\(whole).\(fracStr)ms"
}

struct RGBA {
  let red: UInt8
  let green: UInt8
  let blue: UInt8
  let alpha: UInt8
}

struct RGB {
  let red: UInt8
  let green: UInt8
  let blue: UInt8
}

@inline(__always)
func composite(fg: RGBA, bg: RGB) -> RGB {
  if fg.alpha == 255 {
    return RGB(red: fg.red, green: fg.green, blue: fg.blue)
  }
  let alpha = UInt32(fg.alpha)
  let inverseAlpha = 255 &- alpha
  let red = (UInt32(fg.red) &* alpha &+ UInt32(bg.red) &* inverseAlpha &+ 127) / 255
  let green = (UInt32(fg.green) &* alpha &+ UInt32(bg.green) &* inverseAlpha &+ 127) / 255
  let blue = (UInt32(fg.blue) &* alpha &+ UInt32(bg.blue) &* inverseAlpha &+ 127) / 255
  return RGB(red: UInt8(red), green: UInt8(green), blue: UInt8(blue))
}

/// Generate N pseudo-random RGBA colors (deterministic, no Foundation).
func makeColors(count: Int, mixedAlpha: Bool) -> [RGBA] {
  var colors = [RGBA]()
  colors.reserveCapacity(count)
  var state: UInt64 = 0x1234_5678_9ABC_DEF0
  for index in 0..<count {
    // xorshift64
    state ^= state << 13
    state ^= state >> 7
    state ^= state << 17
    let byte1 = UInt8(truncatingIfNeeded: state)
    let byte2 = UInt8(truncatingIfNeeded: state >> 8)
    let byte3 = UInt8(truncatingIfNeeded: state >> 16)
    let alpha: UInt8
    if mixedAlpha {
      // Mix: half have alpha=255 (fast path), half have variable alpha
      alpha = (index % 2 == 0) ? 255 : UInt8(truncatingIfNeeded: state >> 24)
    } else {
      // All opaque — tests the alpha==255 fast path
      alpha = 255
    }
    colors.append(RGBA(red: byte1, green: byte2, blue: byte3, alpha: alpha))
  }
  return colors
}

func benchmark(
  label: String, iterations: Int, warmup: Int, _ body: () -> Int
) {
  for _ in 0..<warmup { _ = body() }
  var samples = [UInt64]()
  samples.reserveCapacity(iterations)
  var last = 0
  for _ in 0..<iterations {
    let start = nowNanos()
    last = body()
    let end = nowNanos()
    samples.append(end - start)
  }
  samples.sort()
  let minimum = samples.first!
  let median = samples[samples.count / 2]
  let mean = samples.reduce(0, +) / UInt64(samples.count)
  let maximum = samples.last!
  var padded = label
  while padded.count < 40 { padded += " " }
  let minStr = nsToString(minimum)
  let medStr = nsToString(median)
  let meanStr = nsToString(mean)
  let maxStr = nsToString(maximum)
  print("\(padded)  min=\(minStr)  median=\(medStr)  mean=\(meanStr)  max=\(maxStr)  [\(last)]")
}

// MARK: - Main

let background = RGB(red: 0x1E, green: 0x1E, blue: 0x2E)  // typical dark bg

print("Alpha composite benchmark — integer blend over known bg")
print("Background: #1E1E2E")
print("")

// Realistic theme load: 95 TokenTypes → worst case every one has alpha
let realistic = makeColors(count: 95, mixedAlpha: true)
benchmark(label: "95 colors (realistic theme, mixed α)", iterations: 10_000, warmup: 1_000) {
  var accumulator: UInt32 = 0
  for color in realistic {
    let composited = composite(fg: color, bg: background)
    accumulator &+= UInt32(composited.red) &+ UInt32(composited.green) &+ UInt32(composited.blue)
  }
  return Int(accumulator)
}

// All opaque — measures fast-path cost (branch + return)
let opaque = makeColors(count: 95, mixedAlpha: false)
benchmark(label: "95 colors (all α=255, fast path)", iterations: 10_000, warmup: 1_000) {
  var accumulator: UInt32 = 0
  for color in opaque {
    let composited = composite(fg: color, bg: background)
    accumulator &+= UInt32(composited.red) &+ UInt32(composited.green) &+ UInt32(composited.blue)
  }
  return Int(accumulator)
}

// Stress tests at scale
let thousand = makeColors(count: 1_000, mixedAlpha: true)
benchmark(label: "1,000 colors (mixed α)", iterations: 1_000, warmup: 100) {
  var accumulator: UInt32 = 0
  for color in thousand {
    let composited = composite(fg: color, bg: background)
    accumulator &+= UInt32(composited.red) &+ UInt32(composited.green) &+ UInt32(composited.blue)
  }
  return Int(accumulator)
}

let tenThousand = makeColors(count: 10_000, mixedAlpha: true)
benchmark(label: "10,000 colors (mixed α)", iterations: 100, warmup: 10) {
  var accumulator: UInt32 = 0
  for color in tenThousand {
    let composited = composite(fg: color, bg: background)
    accumulator &+= UInt32(composited.red) &+ UInt32(composited.green) &+ UInt32(composited.blue)
  }
  return Int(accumulator)
}

let million = makeColors(count: 1_000_000, mixedAlpha: true)
benchmark(label: "1,000,000 colors (mixed α)", iterations: 10, warmup: 2) {
  var accumulator: UInt32 = 0
  for color in million {
    let composited = composite(fg: color, bg: background)
    accumulator &+= UInt32(composited.red) &+ UInt32(composited.green) &+ UInt32(composited.blue)
  }
  return Int(accumulator)
}

print("")
print("Correctness check:")
let test1 = composite(
  fg: RGBA(red: 0xD0, green: 0x72, blue: 0x77, alpha: 0xFF),
  bg: background
)
print("  #d07277ff over #1e1e2e → #\(hex(test1.red))\(hex(test1.green))\(hex(test1.blue))")
let test2 = composite(
  fg: RGBA(red: 0xFF, green: 0xFF, blue: 0xFF, alpha: 0x80),
  bg: background
)
print("  #ffffff80 over #1e1e2e → #\(hex(test2.red))\(hex(test2.green))\(hex(test2.blue))")
let test3 = composite(
  fg: RGBA(red: 0xFF, green: 0x00, blue: 0x00, alpha: 0x00),
  bg: background
)
print("  #ff000000 over #1e1e2e → #\(hex(test3.red))\(hex(test3.green))\(hex(test3.blue))")

func hex(_ byte: UInt8) -> String {
  let high = Int(byte >> 4)
  let low = Int(byte & 0x0F)
  let chars: [Character] = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "a", "b", "c", "d", "e", "f"]
  return "\(chars[high])\(chars[low])"
}
