#if canImport(Darwin)
  import Darwin
#elseif canImport(Glibc)
  import Glibc
#endif

/// Terminal dimensions in columns and rows.
struct TerminalSize {
  let width: Int
  let height: Int
}

/// Queries the current terminal size.
///
/// Priority: FZF_PREVIEW_COLUMNS/LINES → ioctl(stdout) → ioctl(stderr) → 80x24.
/// FZF sets these env vars for preview panes where ioctl returns the wrong size.
func terminalSize() -> TerminalSize {
  // FZF preview pane — env vars are the only reliable source
  if let colStr = getenv("FZF_PREVIEW_COLUMNS"),
    let rowStr = getenv("FZF_PREVIEW_LINES"),
    let col = Int(String(cString: colStr)),
    let row = Int(String(cString: rowStr)),
    col > 0, row > 0
  {
    return TerminalSize(width: col, height: row)
  }

  var windowSize = winsize()
  if ioctl(STDOUT_FILENO, UInt(TIOCGWINSZ), &windowSize) == 0,
    windowSize.ws_col > 0, windowSize.ws_row > 0
  {
    return TerminalSize(width: Int(windowSize.ws_col), height: Int(windowSize.ws_row))
  }
  if ioctl(STDERR_FILENO, UInt(TIOCGWINSZ), &windowSize) == 0,
    windowSize.ws_col > 0, windowSize.ws_row > 0
  {
    return TerminalSize(width: Int(windowSize.ws_col), height: Int(windowSize.ws_row))
  }
  return TerminalSize(width: 80, height: 24)
}

/// Returns true if stdout is connected to a TTY (not piped).
func stdoutIsTTY() -> Bool {
  isatty(STDOUT_FILENO) != 0
}
