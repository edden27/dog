/// All error cases dog can encounter, with enough context to debug.
enum DogError: Error, CustomStringConvertible {
  case fileNotFound(path: String)
  case readError(path: String, detail: String)
  case writeError(path: String, detail: String)
  case binaryFile(path: String)
  case unknownLanguage(name: String, suggestion: String?)
  case parseError(language: String, detail: String)
  case invalidConfig(path: String, detail: String)
  case invalidTheme(path: String, detail: String)
  case themeNotFound(name: String, searchedDir: String, available: [String])

  var description: String {
    switch self {
    case .fileNotFound(let path):
      return "'\(path)' not found - check path and try again"
    case .readError(let path, let detail):
      if path == "<stdin>" { return "stdin \(detail)" }
      return "cannot read '\(path)' - \(detail)"
    case .writeError(let path, let detail):
      return "cannot write '\(path)' - \(detail)"
    case .binaryFile(let path):
      return "\(path): is a binary file"
    case .unknownLanguage(let name, let suggestion):
      if let suggestion {
        return "unknown language '\(name)'\nDid you mean '\(suggestion)'?"
      }
      return "unknown language '\(name)'\nRun 'dog --list-languages' for supported languages."
    case .parseError(let language, let detail):
      return "parse error (\(language)): \(detail)"
    case .invalidConfig(let path, let detail):
      return "invalid config at \(path): \(detail)"
    case .invalidTheme(let path, let detail):
      return "invalid theme at \(path): \(detail)"
    case .themeNotFound(let name, let searchedDir, let available):
      var message = "theme '\(name)' not found in \(searchedDir)"
      if let suggestion = closestMatch(for: name, in: available) {
        message += "\nDid you mean '\(suggestion)'?"
      } else if !available.isEmpty {
        let preview = available.prefix(10).joined(separator: ", ")
        message += "\nAvailable: \(preview)"
        if available.count > 10 { message += " …" }
      } else {
        message += "\nUse --list-themes to see available themes."
      }
      return message
    }
  }

  /// POSIX exit code for this error.
  var exitCode: Int32 {
    switch self {
    case .fileNotFound, .readError, .writeError, .binaryFile,
      .parseError, .invalidConfig, .invalidTheme, .themeNotFound:
      return 1
    case .unknownLanguage:
      return 2  // bad usage
    }
  }
}

/// Find the closest available string within edit distance 2. Returns nil if
/// nothing is close enough. O(N * |name| * |candidate|).
/// Shared by theme and language "Did you mean" suggestions.
func closestMatch(for name: String, in candidates: [String]) -> String? {
  var best: (name: String, distance: Int)?
  for candidate in candidates {
    let distance = editDistance(name.lowercased(), candidate.lowercased())
    if distance <= 2, best == nil || distance < best!.distance {
      best = (candidate, distance)
    }
  }
  return best?.name
}

/// Levenshtein distance between two strings. Caps at `max` for early exit.
private func editDistance(_ lhs: String, _ rhs: String) -> Int {
  let leftBytes = Array(lhs.utf8)
  let rightBytes = Array(rhs.utf8)
  let leftCount = leftBytes.count
  let rightCount = rightBytes.count
  if leftCount == 0 { return rightCount }
  if rightCount == 0 { return leftCount }

  var previous = [Int](0...rightCount)
  var current = [Int](repeating: 0, count: rightCount + 1)

  for leftIndex in 1...leftCount {
    current[0] = leftIndex
    for rightIndex in 1...rightCount {
      let cost = leftBytes[leftIndex - 1] == rightBytes[rightIndex - 1] ? 0 : 1
      current[rightIndex] = min(
        previous[rightIndex] + 1,
        current[rightIndex - 1] + 1,
        previous[rightIndex - 1] + cost
      )
    }
    swap(&previous, &current)
  }
  return previous[rightCount]
}
