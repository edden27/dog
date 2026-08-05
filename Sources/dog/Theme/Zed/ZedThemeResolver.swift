#if canImport(Darwin)
  import Darwin
#elseif canImport(Glibc)
  import Glibc
#endif

/// Name-based theme resolution for `ZedThemeLoader`.
///
/// Separate from the loader proper because the resolution strategy
/// (progressive prefix + dir scan fallback) is independent from the
/// JSON → `LoadedTheme` transformation. See `tests/themes/bench_resolve.swift`
/// for the empirical design and performance numbers behind this cascade.
extension ZedThemeLoader {

  /// Resolve a theme by name from a directory and load it.
  ///
  /// Resolution strategy:
  ///
  ///   Phase 1 — Progressive prefix stats, longest → shortest on space
  ///             boundaries. For `"macOS Classic Dark"`:
  ///                1. stat `macOS Classic Dark.json` (miss)
  ///                2. stat `macOS Classic.json`       (hit — contains variant)
  ///                3. stat `macOS.json`               (not reached)
  ///             Single-word names try one stat of `<name>.json`.
  ///             N-word names try at most N stats.
  ///
  ///   Phase 2 — Fallback directory scan with short-circuit on first
  ///             variant `name` match. Used only when Phase 1 exhausts.
  ///
  /// Happy path is constant-time in directory size. Fallback is O(N) but
  /// rare for well-named themes. Bench numbers (6 themes, M-series):
  ///   - Phase 1 hit:    20–95µs
  ///   - Phase 2 scan:   100–250µs
  static func load(
    name: String,
    directory: String
  ) throws -> LoadedTheme {
    guard !directory.isEmpty else {
      throw DogError.themeNotFound(
        name: name, searchedDir: "<no config dir>", available: []
      )
    }

    let nameBytes = Array(name.utf8)

    // Phase 1: progressive prefix stats
    if let hit = try tryProgressivePrefix(
      name: name, nameBytes: nameBytes, directory: directory
    ) {
      return hit
    }

    // Phase 1.5 + 2: directory scan, short-circuit on first variant match.
    // Files whose lowercased filename contains the name's lowercased first
    // word are read FIRST ("Vim Dark" → vim-light.json before the blind
    // alphabetical walk) — keeps resolution in the tens-of-µs class in big
    // theme dirs where the variant name doesn't predict the filename.
    let files = orderedByFirstWordMatch(
      ZedThemeDirectoryScanner.listJSONFiles(in: directory), name: name
    )
    for filename in files {
      let path = "\(directory)/\(filename)"
      guard let bytes = try? readFileBytes(path: path) else { continue }
      guard let range = ZedThemeScanner.findVariantRange(bytes, target: nameBytes)
      else { continue }
      return try buildTheme(from: bytes, path: path, variantRange: range)
    }

    // Not found — build suggestion list from all variant names in dir
    let available = collectAllVariantNames(files: files, directory: directory)
    throw DogError.themeNotFound(
      name: name, searchedDir: directory, available: available
    )
  }

  /// Enumerate every `themes[].name` across every `.json` file in a directory.
  /// Used by `--list-themes` and the `themeNotFound` suggestion path.
  static func listVariantNames(
    in directory: String
  ) -> [(bundle: String, variants: [String])] {
    guard !directory.isEmpty else { return [] }
    let files = ZedThemeDirectoryScanner.listJSONFiles(in: directory)
    var results = [(String, [String])]()
    results.reserveCapacity(files.count)
    for filename in files {
      let path = "\(directory)/\(filename)"
      guard let bytes = try? readFileBytes(path: path) else { continue }
      let variants = ZedThemeScanner.listVariantNames(bytes)
      let bundle = String(filename.dropLast(5))  // strip ".json"
      results.append((bundle, variants))
    }
    return results
  }

  // MARK: - Resolution helpers

  /// Order Phase 2's file list so filenames containing the requested name's
  /// first word (case-insensitive) come first, original order otherwise.
  /// With unique variant names the pick is identical either way — order only
  /// decides how soon the scan hits the right file.
  private static func orderedByFirstWordMatch(
    _ files: [String], name: String
  ) -> [String] {
    guard let firstWord = name.split(separator: " ").first?.lowercased() else {
      return files
    }
    var matched = [String]()
    var rest = [String]()
    for filename in files {
      if filename.lowercased().contains(firstWord) {
        matched.append(filename)
      } else {
        rest.append(filename)
      }
    }
    return matched + rest
  }

  /// Phase 1: walk space-separated prefixes longest → shortest, statting each.
  /// On hit, try to find the exact variant; if absent and the user typed the
  /// full filename, accept the first variant.
  private static func tryProgressivePrefix(
    name: String,
    nameBytes: [UInt8],
    directory: String
  ) throws -> LoadedTheme? {
    var endIndex = nameBytes.count
    while endIndex > 0 {
      let prefix = String(decoding: nameBytes[0..<endIndex], as: UTF8.self)
      let path = "\(directory)/\(prefix).json"
      if ZedThemeDirectoryScanner.fileExists(path),
        let bytes = try? readFileBytes(path: path)
      {
        if let hit = try resolveVariantFromBytes(
          bytes: bytes, path: path,
          nameBytes: nameBytes,
          isFullName: endIndex == nameBytes.count
        ) {
          return hit
        }
      }
      // Shorten to previous space
      var previousSpace = endIndex - 1
      while previousSpace > 0, nameBytes[previousSpace] != 0x20 {
        previousSpace -= 1
      }
      if previousSpace == 0 { break }
      endIndex = previousSpace
    }
    return nil
  }

  /// Look up a variant inside already-read bytes. Prefer exact name match;
  /// fall back to first variant only if `isFullName` (user typed the bundle
  /// filename exactly, e.g. `"Nord"` or `"One Dark Pro"`).
  private static func resolveVariantFromBytes(
    bytes: [UInt8],
    path: String,
    nameBytes: [UInt8],
    isFullName: Bool
  ) throws -> LoadedTheme? {
    if let range = ZedThemeScanner.findVariantRange(bytes, target: nameBytes) {
      return try buildTheme(from: bytes, path: path, variantRange: range)
    }
    if isFullName,
      let range = ZedThemeScanner.findVariantRange(bytes, target: nil)
    {
      return try buildTheme(from: bytes, path: path, variantRange: range)
    }
    return nil
  }

  /// Collect every variant name across every `.json` file in `files`.
  /// Used for `themeNotFound` error suggestions.
  private static func collectAllVariantNames(
    files: [String], directory: String
  ) -> [String] {
    var all = [String]()
    for filename in files {
      let path = "\(directory)/\(filename)"
      guard let bytes = try? readFileBytes(path: path) else { continue }
      all.append(contentsOf: ZedThemeScanner.listVariantNames(bytes))
    }
    return all
  }
}
