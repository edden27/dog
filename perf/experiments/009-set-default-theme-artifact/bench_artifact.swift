// Artifact-load benchmark for --set-default-theme.
//
// Question: dog will write a precomputed style table to a small binary file
// once (`--set-default-theme <theme>`), then load it at every startup. What
// is the fastest combination of:
//
//   Format A  = store packed UInt64 per style only; rebuild ANSI bytes at load
//   Format B  = store packed UInt64 + the precomputed ANSI bytes; memcpy at load
//   read      = open + fstat + read() the whole file
//   mmap      = open + fstat + mmap + decode + munmap
//   unaligned = decode u64s with loadUnaligned
//   bytewalk  = decode u64s by assembling 8 bytes with shift-or
//
// Each timed iteration is the FULL startup cost: open -> read/map -> decode
// -> build the [Style] table (96 token styles + base + 3 optionals) -> close.
// Style/buildBytes/appendDecimal are exact replicas of dog's
// Sources/dog/Output/Style.swift and ANSIOutput.appendDecimal, so the
// Format A rebuild cost is dog's real cost.
//
// Also measured: the ENOENT probe (startup cost when NO artifact exists).
//
// Run: swiftc -O bench_artifact.swift -o bench_artifact && ./bench_artifact
//
// ── RESULTS (2026-07-29, M2 Max, 3 runs, 3000 iterations each, stable) ──
//
//   Before: with a file theme set, every dog run pays ~0.5ms (~500µs) to
//   parse the theme JSON and build the style table (bench receipts
//   2026-07-28, 21:37 vs 21:34 medium runs). After: loading a precomputed
//   artifact is the FULL startup path below — ~30x less, and ~1µs when no
//   default theme is set at all.
//
//   A packed-only / read / unaligned    median=17µs   file  809B
//   A packed-only / read / bytewalk     median=17µs   file  809B
//   A packed-only / mmap / unaligned    median=19µs   file  809B
//   B packed+bytes / read / unaligned   median=16µs   file 2934B
//   B packed+bytes / read / bytewalk    median=16µs   file 2934B
//   B packed+bytes / mmap / unaligned   median=18µs   file 2934B
//   no artifact (open -> ENOENT probe)  median= 1µs
//
//   All variants correctness-verified: decoded table identical to the
//   reference (packed AND rebuilt/stored ANSI bytes) in every combination.
//   Both u64 decoders tied within 1µs everywhere — that axis is noise.
//
// ── FINDING 1: plain read beats mmap by ~2µs consistently ──
//   mmap pays its setup cost back on big files; at ~1KB it is pure loss.
//
// ── FINDING 2: storing precomputed ANSI bytes (Format B) buys only 1µs ──
//   Rebuilding the escape bytes from packed values at load is nearly free —
//   it is the same tiny per-style code dog already runs at theme load.
//
// ── DECISION: Format A — packed values only, whole-file read, unaligned ──
//   The 1µs Format B wins is noise, and Format A buys something real: the
//   artifact stores only colors and flags, never derived output. If dog's
//   escape-sequence emission ever changes in a future version, a Format B
//   file would replay stale bytes written by the old dog; Format A cannot
//   go stale by construction — the current binary always rebuilds bytes
//   with its own current code. Smaller file (809B vs 2934B), simpler
//   decoder, one source of truth — same philosophy as Style itself, where
//   `bytes` is always derived from `packed`.

import Darwin

@inline(__always)
func nowNanos() -> UInt64 {
  var ts = timespec()
  clock_gettime(CLOCK_MONOTONIC, &ts)
  return UInt64(ts.tv_sec) * 1_000_000_000 + UInt64(ts.tv_nsec)
}

// MARK: - Style replica (Sources/dog/Output/Style.swift)

struct Style {
  let packed: UInt64
  let bytes: ContiguousArray<UInt8>

  init(r: UInt8, g: UInt8, b: UInt8, bold: Bool = false, italic: Bool = false) {
    packed =
      (UInt64(b) << 32) | (UInt64(g) << 24) | (UInt64(r) << 16) | (bold ? (1 << 6) : 0)
      | (italic ? (1 << 7) : 0)
    bytes = Style.buildBytes(
      r: r, g: g, b: b, bold: bold, italic: italic,
      bgR: 0, bgG: 0, bgB: 0, hasBg: false
    )
  }

  init(
    r: UInt8, g: UInt8, b: UInt8,
    bgR: UInt8, bgG: UInt8, bgB: UInt8,
    bold: Bool = false, italic: Bool = false
  ) {
    packed =
      (UInt64(bgB) << 56) | (UInt64(bgG) << 48) | (UInt64(bgR) << 40) | (UInt64(b) << 32)
      | (UInt64(g) << 24) | (UInt64(r) << 16) | (1 << 5) | (bold ? (1 << 6) : 0)
      | (italic ? (1 << 7) : 0)
    bytes = Style.buildBytes(
      r: r, g: g, b: b, bold: bold, italic: italic,
      bgR: bgR, bgG: bgG, bgB: bgB, hasBg: true
    )
  }

  /// Format B path — adopt stored bytes without rebuilding.
  init(packed: UInt64, bytes: ContiguousArray<UInt8>) {
    self.packed = packed
    self.bytes = bytes
  }

  var r: UInt8 { UInt8((packed >> 16) & 0xFF) }
  var g: UInt8 { UInt8((packed >> 24) & 0xFF) }
  var b: UInt8 { UInt8((packed >> 32) & 0xFF) }
  var bold: Bool { packed & (1 << 6) != 0 }
  var italic: Bool { packed & (1 << 7) != 0 }
  var hasBg: Bool { packed & (1 << 5) != 0 }
  var bgR: UInt8 { UInt8((packed >> 40) & 0xFF) }
  var bgG: UInt8 { UInt8((packed >> 48) & 0xFF) }
  var bgB: UInt8 { UInt8((packed >> 56) & 0xFF) }

  static func appendDecimal(_ value: UInt8, into out: inout ContiguousArray<UInt8>) {
    if value >= 100 { out.append(0x30 &+ value / 100) }
    if value >= 10 { out.append(0x30 &+ (value % 100) / 10) }
    out.append(0x30 &+ value % 10)
  }

  // swiftlint:disable:next function_parameter_count
  static func buildBytes(
    r: UInt8, g: UInt8, b: UInt8, bold: Bool, italic: Bool,
    bgR: UInt8, bgG: UInt8, bgB: UInt8, hasBg: Bool
  ) -> ContiguousArray<UInt8> {
    var out = ContiguousArray<UInt8>()
    out.reserveCapacity(hasBg ? 40 : 20)
    out.append(contentsOf: [0x1B, 0x5B, 0x33, 0x38, 0x3B, 0x32, 0x3B])
    appendDecimal(r, into: &out)
    out.append(0x3B)
    appendDecimal(g, into: &out)
    out.append(0x3B)
    appendDecimal(b, into: &out)
    out.append(0x6D)
    if hasBg {
      out.append(contentsOf: [0x1B, 0x5B, 0x34, 0x38, 0x3B, 0x32, 0x3B])
      appendDecimal(bgR, into: &out)
      out.append(0x3B)
      appendDecimal(bgG, into: &out)
      out.append(0x3B)
      appendDecimal(bgB, into: &out)
      out.append(0x6D)
    }
    return out
  }
}

/// Rebuild a Style from its packed value alone (Format A load path).
@inline(__always)
func styleFromPacked(_ packed: UInt64) -> Style {
  let red = UInt8((packed >> 16) & 0xFF)
  let green = UInt8((packed >> 24) & 0xFF)
  let blue = UInt8((packed >> 32) & 0xFF)
  let bold = packed & (1 << 6) != 0
  let italic = packed & (1 << 7) != 0
  if packed & (1 << 5) != 0 {
    return Style(
      r: red, g: green, b: blue,
      bgR: UInt8((packed >> 40) & 0xFF),
      bgG: UInt8((packed >> 48) & 0xFF),
      bgB: UInt8((packed >> 56) & 0xFF),
      bold: bold, italic: italic
    )
  }
  return Style(r: red, g: green, b: blue, bold: bold, italic: italic)
}

// MARK: - Realistic table (96 token styles + base + 3 optionals)

let tokenCount = 96

struct ThemeTable {
  let colorTable: [Style]
  let baseColor: Style
  let lineNumberStyle: Style?
  let gutterBgStyle: Style?
  let editorBgStyle: Style?
}

func makeReferenceTable() -> ThemeTable {
  var table: [Style] = []
  table.reserveCapacity(tokenCount)
  for index in 0..<tokenCount {
    let red = UInt8(truncatingIfNeeded: 40 &+ index &* 37)
    let green = UInt8(truncatingIfNeeded: 90 &+ index &* 53)
    let blue = UInt8(truncatingIfNeeded: 140 &+ index &* 29)
    let bold = index % 5 == 0
    let italic = index % 7 == 0
    if index % 6 == 0 {
      table.append(Style(
        r: red, g: green, b: blue, bgR: 29, bgG: 29, bgB: 29,
        bold: bold, italic: italic
      ))
    } else {
      table.append(Style(r: red, g: green, b: blue, bold: bold, italic: italic))
    }
  }
  return ThemeTable(
    colorTable: table,
    baseColor: Style(r: 205, g: 190, b: 171),
    lineNumberStyle: Style(r: 129, g: 116, b: 100),
    gutterBgStyle: Style(r: 29, g: 29, b: 29),
    editorBgStyle: Style(r: 43, g: 43, b: 43)
  )
}

// MARK: - Artifact writing

// Shared header: "DOGT" magic, version u8, format u8 (1=A, 2=B),
// entry count u16 LE, optional-presence flags u8.
// Entries in order: base, lineNumber, gutterBg, editorBg, then 96 token styles.
// Absent optionals still occupy a slot (packed=0 / empty bytes) so offsets
// stay uniform; the flags byte says which are real.

func appendLittleEndianU64(_ value: UInt64, into out: inout [UInt8]) {
  var remaining = value
  for _ in 0..<8 {
    out.append(UInt8(truncatingIfNeeded: remaining))
    remaining >>= 8
  }
}

func encodeArtifact(_ theme: ThemeTable, format: UInt8) -> [UInt8] {
  var out: [UInt8] = Array("DOGT".utf8)
  out.append(1)  // version
  out.append(format)
  out.append(UInt8(tokenCount & 0xFF))
  out.append(UInt8(tokenCount >> 8))
  var flags: UInt8 = 0
  if theme.lineNumberStyle != nil { flags |= 1 }
  if theme.gutterBgStyle != nil { flags |= 2 }
  if theme.editorBgStyle != nil { flags |= 4 }
  out.append(flags)

  var entries: [Style?] = [
    theme.baseColor, theme.lineNumberStyle, theme.gutterBgStyle, theme.editorBgStyle,
  ]
  entries.append(contentsOf: theme.colorTable.map { Optional($0) })
  for entry in entries {
    appendLittleEndianU64(entry?.packed ?? 0, into: &out)
    if format == 2 {
      let styleBytes = entry?.bytes ?? []
      out.append(UInt8(styleBytes.count))
      out.append(contentsOf: styleBytes)
    }
  }
  return out
}

func writeFile(_ path: String, _ contents: [UInt8]) {
  let descriptor = open(path, O_WRONLY | O_CREAT | O_TRUNC, 0o644)
  precondition(descriptor >= 0, "cannot write \(path)")
  contents.withUnsafeBytes { raw in
    let written = write(descriptor, raw.baseAddress, raw.count)
    precondition(written == raw.count)
  }
  close(descriptor)
}

// MARK: - Decoders

enum U64Decode { case unaligned, bytewalk }

func decodeArtifact(
  _ raw: UnsafeRawBufferPointer, format: UInt8, u64Decode: U64Decode
) -> ThemeTable {
  precondition(raw.count > 9)
  precondition(raw[0] == 0x44 && raw[1] == 0x4F && raw[2] == 0x47 && raw[3] == 0x54)
  precondition(raw[4] == 1 && raw[5] == format)
  let count = Int(raw[6]) | (Int(raw[7]) << 8)
  let flags = raw[8]
  var offset = 9

  @inline(__always)
  func loadU64() -> UInt64 {
    let value: UInt64
    switch u64Decode {
    case .unaligned:
      value = UInt64(littleEndian: raw.loadUnaligned(fromByteOffset: offset, as: UInt64.self))
    case .bytewalk:
      var assembled: UInt64 = 0
      for byteIndex in 0..<8 {
        assembled |= UInt64(raw[offset + byteIndex]) << (8 * byteIndex)
      }
      value = assembled
    }
    offset += 8
    return value
  }

  @inline(__always)
  func loadStyle() -> Style {
    let packed = loadU64()
    if format == 2 {
      let length = Int(raw[offset])
      offset += 1
      let styleBytes = ContiguousArray<UInt8>(unsafeUninitializedCapacity: length) {
        buffer, initializedCount in
        if length > 0 {
          memcpy(buffer.baseAddress!, raw.baseAddress! + offset, length)
        }
        initializedCount = length
      }
      offset += length
      return Style(packed: packed, bytes: styleBytes)
    }
    return styleFromPacked(packed)
  }

  let base = loadStyle()
  let lineNumber = loadStyle()
  let gutterBg = loadStyle()
  let editorBg = loadStyle()
  var table: [Style] = []
  table.reserveCapacity(count)
  for _ in 0..<count { table.append(loadStyle()) }

  return ThemeTable(
    colorTable: table,
    baseColor: base,
    lineNumberStyle: flags & 1 != 0 ? lineNumber : nil,
    gutterBgStyle: flags & 2 != 0 ? gutterBg : nil,
    editorBgStyle: flags & 4 != 0 ? editorBg : nil
  )
}

// MARK: - Full load paths (what one dog startup would pay)

func loadViaRead(_ path: String, format: UInt8, u64Decode: U64Decode) -> ThemeTable? {
  let descriptor = open(path, O_RDONLY)
  guard descriptor >= 0 else { return nil }
  defer { close(descriptor) }
  var info = stat()
  guard fstat(descriptor, &info) == 0 else { return nil }
  let size = Int(info.st_size)
  let contents = [UInt8](unsafeUninitializedCapacity: size) { buffer, initializedCount in
    var total = 0
    while total < size {
      let readCount = read(descriptor, buffer.baseAddress! + total, size - total)
      if readCount <= 0 { break }
      total += readCount
    }
    initializedCount = total
  }
  guard contents.count == size else { return nil }
  return contents.withUnsafeBytes { raw in
    decodeArtifact(raw, format: format, u64Decode: u64Decode)
  }
}

func loadViaMmap(_ path: String, format: UInt8, u64Decode: U64Decode) -> ThemeTable? {
  let descriptor = open(path, O_RDONLY)
  guard descriptor >= 0 else { return nil }
  defer { close(descriptor) }
  var info = stat()
  guard fstat(descriptor, &info) == 0 else { return nil }
  let size = Int(info.st_size)
  guard let mapped = mmap(nil, size, PROT_READ, MAP_PRIVATE, descriptor, 0),
    mapped != MAP_FAILED
  else { return nil }
  defer { munmap(mapped, size) }
  let raw = UnsafeRawBufferPointer(start: mapped, count: size)
  return decodeArtifact(raw, format: format, u64Decode: u64Decode)
}

// MARK: - Verification

func tablesEqual(_ left: ThemeTable, _ right: ThemeTable) -> Bool {
  func styleEqual(_ first: Style?, _ second: Style?) -> Bool {
    switch (first, second) {
    case (nil, nil): return true
    case let (one?, two?): return one.packed == two.packed && one.bytes == two.bytes
    default: return false
    }
  }
  guard left.colorTable.count == right.colorTable.count else { return false }
  for index in left.colorTable.indices
  where !styleEqual(left.colorTable[index], right.colorTable[index]) {
    return false
  }
  return styleEqual(left.baseColor, right.baseColor)
    && styleEqual(left.lineNumberStyle, right.lineNumberStyle)
    && styleEqual(left.gutterBgStyle, right.gutterBgStyle)
    && styleEqual(left.editorBgStyle, right.editorBgStyle)
}

// MARK: - Bench harness

var sink: UInt64 = 0

func consume(_ theme: ThemeTable) {
  sink &+= theme.baseColor.packed &+ UInt64(theme.colorTable.count)
  sink &+= UInt64(theme.colorTable[50].bytes.count)
}

func bench(_ label: String, iterations: Int, _ body: () -> ThemeTable?) {
  var samples: [UInt64] = []
  samples.reserveCapacity(iterations)
  for _ in 0..<200 {  // warmup
    if let theme = body() { consume(theme) }
  }
  for _ in 0..<iterations {
    let start = nowNanos()
    let theme = body()
    let elapsed = nowNanos() - start
    if let theme { consume(theme) }
    samples.append(elapsed)
  }
  samples.sort()
  let median = samples[samples.count / 2]
  let p10 = samples[samples.count / 10]
  let p90 = samples[samples.count * 9 / 10]
  func micro(_ nanos: UInt64) -> String {
    let whole = nanos / 1_000
    let fraction = (nanos % 1_000) / 10
    let fractionText = fraction < 10 ? "0\(fraction)" : "\(fraction)"
    return "\(whole).\(fractionText)µs"
  }
  var paddedLabel = label
  while paddedLabel.count < 34 { paddedLabel += " " }
  print("  \(paddedLabel)"
    + " median=\(micro(median))  p10=\(micro(p10))  p90=\(micro(p90))")
}

// MARK: - Main

let directory = CommandLine.arguments.count > 1
  ? CommandLine.arguments[1] : "."
let pathA = "\(directory)/artifact-a.dogtheme"
let pathB = "\(directory)/artifact-b.dogtheme"
let pathMissing = "\(directory)/no-such-artifact.dogtheme"

let reference = makeReferenceTable()
let artifactA = encodeArtifact(reference, format: 1)
let artifactB = encodeArtifact(reference, format: 2)
writeFile(pathA, artifactA)
writeFile(pathB, artifactB)
unlink(pathMissing)

print("artifact sizes: A(packed only)=\(artifactA.count)B  B(packed+bytes)=\(artifactB.count)B")

// Correctness first — every variant must reproduce the reference exactly.
var allCorrect = true
for (label, theme) in [
  ("A/read/unaligned", loadViaRead(pathA, format: 1, u64Decode: .unaligned)),
  ("A/read/bytewalk", loadViaRead(pathA, format: 1, u64Decode: .bytewalk)),
  ("A/mmap/unaligned", loadViaMmap(pathA, format: 1, u64Decode: .unaligned)),
  ("B/read/unaligned", loadViaRead(pathB, format: 2, u64Decode: .unaligned)),
  ("B/read/bytewalk", loadViaRead(pathB, format: 2, u64Decode: .bytewalk)),
  ("B/mmap/unaligned", loadViaMmap(pathB, format: 2, u64Decode: .unaligned)),
] {
  let matches = theme.map { tablesEqual($0, reference) } ?? false
  if !matches { allCorrect = false }
  print("  correctness \(label): \(matches ? "identical" : "MISMATCH")")
}
precondition(allCorrect, "correctness failure — numbers below would be meaningless")

let iterations = 3000
print("\nfull startup load (open→decode→[Style] table→close), \(iterations) iterations:")
bench("A packed-only / read / unaligned", iterations: iterations) {
  loadViaRead(pathA, format: 1, u64Decode: .unaligned)
}
bench("A packed-only / read / bytewalk", iterations: iterations) {
  loadViaRead(pathA, format: 1, u64Decode: .bytewalk)
}
bench("A packed-only / mmap / unaligned", iterations: iterations) {
  loadViaMmap(pathA, format: 1, u64Decode: .unaligned)
}
bench("B packed+bytes / read / unaligned", iterations: iterations) {
  loadViaRead(pathB, format: 2, u64Decode: .unaligned)
}
bench("B packed+bytes / read / bytewalk", iterations: iterations) {
  loadViaRead(pathB, format: 2, u64Decode: .bytewalk)
}
bench("B packed+bytes / mmap / unaligned", iterations: iterations) {
  loadViaMmap(pathB, format: 2, u64Decode: .unaligned)
}

print("\nstartup probe when NO artifact exists (open → ENOENT):")
bench("missing file open()", iterations: iterations) {
  let descriptor = open(pathMissing, O_RDONLY)
  if descriptor >= 0 { close(descriptor) }
  return nil
}

print("\nsink=\(sink)")
