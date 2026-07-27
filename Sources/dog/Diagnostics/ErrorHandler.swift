#if canImport(Darwin)
  import Darwin
#elseif canImport(Glibc)
  import Glibc
#endif

/// Central error router. All errors flow here for formatting and exit.
enum ErrorHandler {
  /// Format and write an error to stderr, then exit with the appropriate code.
  static func handle(_ error: Error) -> Never {
    let message: String
    let code: Int32

    if let dogError = error as? DogError {
      message = dogError.description
      code = dogError.exitCode
    } else {
      message = String(describing: error)
      code = 1
    }

    writeError(message)
    exit(code)
  }

  /// Write an error message to stderr with ANSI color if the terminal supports it.
  static func writeError(_ message: String) {
    let isTerminal = TTY.stderrIsTerminal
    let formatted: String

    if isTerminal {
      // First line red with the [error] tag; continuation lines
      // (e.g. an "Available:" list) dim.
      let lines = message.split(separator: "\n", omittingEmptySubsequences: false)
      var text = "\u{1B}[1;31m[error]\u{1B}[0m \u{1B}[31m\(lines.first ?? "")\u{1B}[0m\n"
      for line in lines.dropFirst() {
        text += "\u{1B}[2m\(line)\u{1B}[0m\n"
      }
      formatted = text
    } else {
      formatted = "[error] \(message)\n"
    }

    let utf8 = Array(formatted.utf8)
    utf8.withUnsafeBufferPointer { buf in
      var offset = 0
      while offset < buf.count {
        let written = write(STDERR_FILENO, buf.baseAddress! + offset, buf.count - offset)
        if written <= 0 { break }
        offset += written
      }
    }
  }

  /// Install SIGPIPE handler so piped output exits cleanly.
  static func installSignalHandlers() {
    signal(SIGPIPE, SIG_IGN)
  }
}
