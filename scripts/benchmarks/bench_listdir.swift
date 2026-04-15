// Time how long it takes to list all .json files in a directory.
// Uses POSIX opendir/readdir with byte-level suffix filter.
//
// Run: swift -O tests/themes/bench_listdir.swift themes
//
// Results (release, 1000 iters, macOS M-series):
//   themes/ (6 .json files)                              median=0.014ms
//   ~/.config/nvim/lua/custom/plugins/ (37 .lua files)   median=0.026ms  (0 matches)
//
// Linear cost ~0.3µs per dirent scanned. 100-theme dir projects to ~0.044ms.
// Sub-millisecond and invisible to users regardless of dir size.

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

func listJSON(_ path: String) -> [String] {
  guard let dir = opendir(path) else { return [] }
  defer { closedir(dir) }
  var results = [String]()
  while let entry = readdir(dir) {
    let nameBytes = withUnsafeBytes(of: &entry.pointee.d_name) { raw -> [UInt8] in
      let pointer = raw.bindMemory(to: UInt8.self).baseAddress!
      var length = 0
      while pointer[length] != 0 { length += 1 }
      return Array(UnsafeBufferPointer(start: pointer, count: length))
    }
    guard nameBytes.count > 5 else { continue }
    let count = nameBytes.count
    if nameBytes[count - 5] == 0x2E,
      nameBytes[count - 4] == 0x6A,
      nameBytes[count - 3] == 0x73,
      nameBytes[count - 2] == 0x6F,
      nameBytes[count - 1] == 0x6E
    {
      results.append(String(decoding: nameBytes, as: UTF8.self))
    }
  }
  return results
}

let path = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "themes"

// Warmup
for _ in 0..<100 { _ = listJSON(path) }

let iters = 1_000
var samples = [UInt64]()
samples.reserveCapacity(iters)
var lastCount = 0
for _ in 0..<iters {
  let start = nowNanos()
  let files = listJSON(path)
  let end = nowNanos()
  samples.append(end - start)
  lastCount = files.count
}

samples.sort()
let minimum = samples.first!
let median = samples[samples.count / 2]
let mean = samples.reduce(0, +) / UInt64(iters)
let maximum = samples.last!

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

print("Dir: \(path)")
print("Files found: \(lastCount)")
print("Iters: \(iters) (warmup: 100)")
print("min=\(nsToString(minimum))  median=\(nsToString(median))  mean=\(nsToString(mean))  max=\(nsToString(maximum))")

// Show the files
let files = listJSON(path)
for file in files.sorted() {
  print("  \(file)")
}
