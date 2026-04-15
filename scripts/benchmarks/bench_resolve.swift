// End-to-end --theme "<name>" resolve benchmark.
//
// Simulates real flag resolution:
//   Phase 1 — progressive prefix stats (longest → shortest on space boundaries)
//     "macOS Classic Dark" → stat "macOS Classic Dark.json"
//                          → stat "macOS Classic.json"   (HIT, variant inside)
//                          → stat "macOS.json"
//     For single-word names this is one stat of "<name>.json".
//     For N-word names, at most N stats.
//   Phase 2 — full dir scan with short-circuit on first variant name match.
//
// Directory listing is HARDCODED — already benched separately in bench_listdir.swift.
//
// Run: swift -O tests/themes/bench_resolve.swift
//
// Results (release, 6 themes, 1000 iters, macOS M-series):
//   "Nord Dark"                      median=0.021ms   (Phase 1 hit, 1st variant)
//   "Nord Light"                     median=0.027ms   (Phase 1 hit, 2nd variant)
//   "Catppuccin Latte"               median=0.035ms   (Phase 1 hit, 1st of 4)
//   "Catppuccin Mocha"               median=0.088ms   (Phase 1 hit, 4th of 4)
//   "One Dark Pro"                   median=0.021ms   (Phase 1 hit, first stat)
//   "macOS Classic Dark"             median=0.025ms   (Phase 1 hit, 2 stats)
//   "Everforest Dark Medium (blur)"  median=0.120ms   (Phase 2 fallback scan)
//   "Everforest Dark Hard (blur)"    median=0.116ms   (Phase 2 fallback scan)
//   "Dracula Pro Van Helsing"  miss  median=0.244ms   (all phases exhausted)
//
// Happy path: 20-90µs. Worst case (6 files): ~0.25ms. All well under 1ms.
// Phase 1 is O(1) in dir size. Phase 2 is O(N) but rare for well-named themes.

#if canImport(Darwin)
  import Darwin
#elseif canImport(Glibc)
  import Glibc
#endif

// MARK: - Hardcoded dir listing

let themesDir = "themes"
let knownFiles = [
  "Catppuccin.json",
  "Everforest Theme (blur).json",
  "Nord.json",
  "One Dark Pro.json",
  "Ultimate Dark Neo.json",
  "macOS Classic.json",
]

// MARK: - Timing

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

// MARK: - File reading

func readBytes(_ path: String) -> [UInt8]? {
  let fileDescriptor = open(path, O_RDONLY)
  guard fileDescriptor >= 0 else { return nil }
  defer { close(fileDescriptor) }
  var fileStat = stat()
  fstat(fileDescriptor, &fileStat)
  let fileSize = Int(fileStat.st_size)
  var buffer = [UInt8](repeating: 0, count: fileSize)
  let bytesRead = buffer.withUnsafeMutableBytes {
    read(fileDescriptor, $0.baseAddress, fileSize)
  }
  guard bytesRead == fileSize else { return nil }
  return buffer
}

@inline(__always)
func fileExists(_ path: String) -> Bool {
  var fileStat = stat()
  return stat(path, &fileStat) == 0
}

// MARK: - Variant matching

/// Scan file bytes for a variant whose "name" field matches target.
/// Returns the byte range (startObject, endObject) of the matching themes[] entry,
/// so the caller can extract that variant's syntax/style blocks.
/// If target is nil, returns the first variant found.
func findVariant(
  _ bytes: [UInt8], target: [UInt8]?
) -> (start: Int, end: Int)? {
  let count = bytes.count
  var position = 0

  // Find "themes" : [
  let themesKey: [UInt8] = [0x74, 0x68, 0x65, 0x6D, 0x65, 0x73]
  var found = false
  while position < count - 10 {
    if bytes[position] == 0x22 {
      var matched = true
      for index in 0..<themesKey.count
      where bytes[position + 1 + index] != themesKey[index] {
        matched = false
        break
      }
      if matched, bytes[position + 1 + themesKey.count] == 0x22 {
        position += themesKey.count + 2
        while position < count, bytes[position] != 0x5B { position += 1 }
        position += 1
        found = true
        break
      }
    }
    position += 1
  }
  guard found else { return nil }

  // Walk themes[] — find objects at depth 0, check each one's top-level "name"
  var depth = 0
  var objectStart = -1
  let nameKey: [UInt8] = [0x6E, 0x61, 0x6D, 0x65]

  while position < count {
    let byte = bytes[position]
    if byte == 0x5D, depth == 0 { break }
    if byte == 0x7B {
      if depth == 0 { objectStart = position }
      depth += 1
      position += 1
      continue
    }
    if byte == 0x7D {
      depth -= 1
      if depth == 0 {
        if matchVariantName(
          bytes, start: objectStart, end: position,
          nameKey: nameKey, target: target
        ) {
          return (objectStart, position)
        }
      }
      position += 1
      continue
    }
    position += 1
  }
  return nil
}

/// Check if the object at [start, end] has a top-level "name" matching target.
/// If target is nil, always returns true (first-variant fallback).
private func matchVariantName(
  _ bytes: [UInt8], start: Int, end: Int,
  nameKey: [UInt8], target: [UInt8]?
) -> Bool {
  var position = start + 1
  var depth = 1

  while position < end, depth > 0 {
    while position < end, bytes[position] <= 0x20 { position += 1 }
    if position >= end { break }
    let byte = bytes[position]
    if byte == 0x7D {
      depth -= 1
      position += 1
      continue
    }
    if byte == 0x7B {
      depth += 1
      position += 1
      continue
    }
    if byte == 0x2C {
      position += 1
      continue
    }
    if byte == 0x22, depth == 1 {
      position += 1
      let keyStart = position
      while position < end, bytes[position] != 0x22 { position += 1 }
      let keyEnd = position
      position += 1
      while position < end,
        bytes[position] == 0x20 || bytes[position] == 0x3A
          || bytes[position] <= 0x0D
      {
        position += 1
      }

      let keyLen = keyEnd - keyStart
      var isNameKey = keyLen == nameKey.count
      if isNameKey {
        for index in 0..<keyLen
        where bytes[keyStart + index] != nameKey[index] {
          isNameKey = false
          break
        }
      }

      if isNameKey, position < end, bytes[position] == 0x22 {
        position += 1
        let valStart = position
        while position < end, bytes[position] != 0x22 { position += 1 }
        let valEnd = position
        position += 1

        guard let target else { return true }

        let valLen = valEnd - valStart
        if valLen != target.count { return false }
        for index in 0..<valLen
        where bytes[valStart + index] != target[index] {
          return false
        }
        return true
      }

      // Skip non-name values
      if position < end, bytes[position] == 0x7B {
        var innerDepth = 1
        position += 1
        while position < end, innerDepth > 0 {
          if bytes[position] == 0x7B { innerDepth += 1 }
          if bytes[position] == 0x7D { innerDepth -= 1 }
          position += 1
        }
      } else if position < end, bytes[position] == 0x22 {
        position += 1
        while position < end, bytes[position] != 0x22 { position += 1 }
        position += 1
      } else {
        while position < end, bytes[position] != 0x2C, bytes[position] != 0x7D {
          position += 1
        }
      }
    } else {
      position += 1
    }
  }
  return false
}

// MARK: - Resolve

struct ResolveResult {
  let path: String
  let variantRange: (Int, Int)
  let bytes: [UInt8]
}

/// Two-phase resolve:
///   Phase 1: progressive prefix shortening, stat each
///     "macOS Classic Dark" → try "macOS Classic Dark.json"
///                         → try "macOS Classic.json"   (HIT — has "macOS Classic Dark" variant)
///                         → try "macOS.json"
///     For single-word names (no spaces), this is just one stat of "<name>.json".
///     For N-word names, at most N stats before fallback.
///   Phase 2: full dir scan with short-circuit
func resolve(_ themeName: String, files: [String], dir: String) -> ResolveResult? {
  let nameBytes = Array(themeName.utf8)

  // Phase 1: progressive prefix stats, longest to shortest
  var endIndex = nameBytes.count
  while endIndex > 0 {
    let prefix = String(decoding: nameBytes[0..<endIndex], as: UTF8.self)
    let path = "\(dir)/\(prefix).json"
    if fileExists(path), let bytes = readBytes(path) {
      if let range = findVariant(bytes, target: nameBytes) {
        return ResolveResult(path: path, variantRange: range, bytes: bytes)
      }
      // Full-prefix file matched but no variant of that name inside — keep trying
      // (could be coincidence: "Catppuccin" file exists but user typed "Catppuccin Foo")
    }
    // Shorten to previous space
    var previousSpace = endIndex - 1
    while previousSpace > 0, nameBytes[previousSpace] != 0x20 {
      previousSpace -= 1
    }
    if previousSpace == 0 { break }
    endIndex = previousSpace
  }

  // Phase 2: dir scan, short-circuit on match
  for file in files {
    let path = "\(dir)/\(file)"
    guard let bytes = readBytes(path) else { continue }
    if let range = findVariant(bytes, target: nameBytes) {
      return ResolveResult(path: path, variantRange: range, bytes: bytes)
    }
  }
  return nil
}

// MARK: - Benchmark

struct Stats {
  let min: UInt64
  let median: UInt64
  let mean: UInt64
  let max: UInt64
  init(_ samples: [UInt64]) {
    let sorted = samples.sorted()
    self.min = sorted.first!
    self.max = sorted.last!
    self.median = sorted[sorted.count / 2]
    self.mean = samples.reduce(0, +) / UInt64(samples.count)
  }
}

func benchmark(_ label: String, _ body: () -> Bool) {
  let iters = 1_000
  let warmups = 100
  for _ in 0..<warmups { _ = body() }
  var samples = [UInt64]()
  samples.reserveCapacity(iters)
  var ok = false
  for _ in 0..<iters {
    let start = nowNanos()
    ok = body()
    let end = nowNanos()
    samples.append(end - start)
  }
  let stats = Stats(samples)
  let hit = ok ? "✓" : "✗"
  var padded = label
  while padded.count < 32 { padded += " " }
  let minStr = nsToString(stats.min)
  let medStr = nsToString(stats.median)
  let meanStr = nsToString(stats.mean)
  let maxStr = nsToString(stats.max)
  print("\(hit) \(padded)  min=\(minStr)  median=\(medStr)  mean=\(meanStr)  max=\(maxStr)")
}

// MARK: - Main

print("Dir: \(themesDir) (\(knownFiles.count) files, hardcoded)")
print("")
print("Two-level resolve: stat shortcut → dir scan fallback")
print("")

// Cases covering: L1 full-name hit, L2 first-word hit, L3 fallback scan
let cases: [(String, String)] = [
  ("L2 Nord Dark", "Nord Dark"),
  ("L2 Nord Light", "Nord Light"),
  ("L2 Catppuccin Latte", "Catppuccin Latte"),
  ("L2 Catppuccin Mocha (last variant)", "Catppuccin Mocha"),
  ("L1 One Dark Pro", "One Dark Pro"),
  ("Everforest Dark Medium (blur)", "Everforest Dark Medium (blur)"),
  ("L2 Everforest variant", "Everforest Dark Hard (blur)"),
  ("L1 macOS Classic Dark", "macOS Classic Dark"),
  ("L3 full scan miss", "Dracula Pro Van Helsing"),
]

for (label, target) in cases {
  benchmark(label) {
    resolve(target, files: knownFiles, dir: themesDir) != nil
  }
}

print("")
print(
  "Note: stat-miss cases (Everforest, macOS Classic) hit the fallback dir scan "
    + "because the first word differs from the filename."
)
