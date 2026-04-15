#if canImport(Darwin)
  import Darwin
#elseif canImport(Glibc)
  import Glibc
#endif

/// Debug-only logger with ANSI-colored output by level.
///
/// All logging compiles out in release builds via `#if DEBUG`.
/// Set `DOG_LOG_LEVEL=debug` environment variable for verbose output.
enum Bark {
  enum Level: Int, Comparable {
    case debug = 0
    case info = 1
    case warning = 2
    case error = 3

    static func < (lhs: Level, rhs: Level) -> Bool {
      lhs.rawValue < rhs.rawValue
    }
  }

  #if DEBUG
    private static let currentLevel: Level = {
      guard let raw = getenv("DOG_LOG_LEVEL") else { return .info }
      let env = String(cString: raw).lowercased()
      switch env {
      case "debug": return .debug
      case "info": return .info
      case "warning", "warn": return .warning
      case "error": return .error
      default: return .info
      }
    }()

    private static let isTerminal = isatty(STDERR_FILENO) != 0

    private static func prefix(for level: Level) -> String {
      guard isTerminal else {
        switch level {
        case .debug: return "[debug]"
        case .info: return "[info]"
        case .warning: return "[warn]"
        case .error: return "[error]"
        }
      }

      switch level {
      case .debug: return "\u{1B}[2m[debug]\u{1B}[0m"  // dim grey
      case .info: return "\u{1B}[34m[info]\u{1B}[0m"  // blue
      case .warning: return "\u{1B}[1;33m[warn]\u{1B}[0m"  // bold yellow
      case .error: return "\u{1B}[1;31m[error]\u{1B}[0m"  // bold red
      }
    }

    private static func log(_ level: Level, _ message: @autoclosure () -> String) {
      guard level >= currentLevel else { return }
      let line = "\(prefix(for: level)) \(message())\n"
      let utf8 = Array(line.utf8)
      utf8.withUnsafeBufferPointer { buf in
        var offset = 0
        while offset < buf.count {
          let written = write(STDERR_FILENO, buf.baseAddress! + offset, buf.count - offset)
          if written <= 0 { break }
          offset += written
        }
      }
    }
  #endif

  /// Log a debug message (dim grey). Only in DEBUG builds.
  static func debug(_ message: @autoclosure () -> String) {
    #if DEBUG
      log(.debug, message())
    #endif
  }

  /// Log an info message (blue). Only in DEBUG builds.
  static func info(_ message: @autoclosure () -> String) {
    #if DEBUG
      log(.info, message())
    #endif
  }

  /// Log a warning (bold yellow). Only in DEBUG builds.
  static func warning(_ message: @autoclosure () -> String) {
    #if DEBUG
      log(.warning, message())
    #endif
  }

  /// Log an error (bold red). Only in DEBUG builds.
  static func error(_ message: @autoclosure () -> String) {
    #if DEBUG
      log(.error, message())
    #endif
  }
}
