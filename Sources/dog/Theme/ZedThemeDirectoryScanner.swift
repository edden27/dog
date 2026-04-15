#if canImport(Darwin)
  import Darwin
#elseif canImport(Glibc)
  import Glibc
#endif

/// Filesystem helpers for walking a themes directory.
///
/// Isolates POSIX `opendir`/`readdir` + `stat` calls from `ZedThemeLoader`
/// so the loader stays focused on JSON → `LoadedTheme` transformation.
/// Used by `ZedThemeLoader.load(name:directory:)` during the progressive-
/// prefix cascade and dir-scan fallback, and by `--list-themes`.
///
/// Bench references: `tests/themes/bench_listdir.swift` for listing cost
/// and `tests/themes/bench_resolve.swift` for the full resolve path.
enum ZedThemeDirectoryScanner {

  /// Single-syscall existence check. No Foundation.
  @inline(__always)
  static func fileExists(_ path: String) -> Bool {
    var fileStat = stat()
    return stat(path, &fileStat) == 0
  }

  /// List `.json` filenames in a directory via POSIX `opendir`/`readdir`.
  /// Returns an empty array if the directory doesn't exist.
  ///
  /// Bench: ~14µs for 6 files, ~0.3µs/entry scaling.
  static func listJSONFiles(in directory: String) -> [String] {
    guard let dirHandle = opendir(directory) else { return [] }
    defer { closedir(dirHandle) }
    var results = [String]()
    while let entry = readdir(dirHandle) {
      let nameBytes = withUnsafeBytes(of: &entry.pointee.d_name) { raw -> [UInt8] in
        let pointer = raw.bindMemory(to: UInt8.self).baseAddress!
        var length = 0
        while pointer[length] != 0 { length += 1 }
        return Array(UnsafeBufferPointer(start: pointer, count: length))
      }
      // Filter ".json" suffix — byte match, no String alloc for skipped files.
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
    results.sort()
    return results
  }
}
