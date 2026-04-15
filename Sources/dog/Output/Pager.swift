#if canImport(Darwin)
  import Darwin
#elseif canImport(Glibc)
  import Glibc
#endif

/// Spawns `less -R` and writes data to its stdin. Waits for it to exit.
/// Returns false if less isn't available or fails to spawn.
enum Pager {
  static func run(buffer: inout ANSIOutput) -> Bool {
    // Create a pipe: pipefd[0] = read end (less reads from), pipefd[1] = write end (we write to)
    var pipefd: [Int32] = [0, 0]
    guard pipe(&pipefd) == 0 else { return false }

    #if canImport(Darwin)
      var fileActions: posix_spawn_file_actions_t?
    #else
      var fileActions = posix_spawn_file_actions_t()
    #endif
    posix_spawn_file_actions_init(&fileActions)
    // less reads from the pipe's read end as its stdin
    posix_spawn_file_actions_adddup2(&fileActions, pipefd[0], STDIN_FILENO)
    posix_spawn_file_actions_addclose(&fileActions, pipefd[1])

    let argv: [UnsafeMutablePointer<CChar>?] = [
      strdup("less"),
      strdup("-R"),  // pass through ANSI color codes
      nil,
    ]
    defer { for arg in argv { free(arg) } }

    var pid: pid_t = 0
    let status = posix_spawnp(&pid, "less", &fileActions, nil, argv, environ)
    posix_spawn_file_actions_destroy(&fileActions)

    guard status == 0 else {
      close(pipefd[0])
      close(pipefd[1])
      return false
    }

    // Close read end in parent — only less uses it
    close(pipefd[0])

    // Write our buffer to the pipe
    buffer.flushTo(pipefd[1])

    // Close write end — signals EOF to less
    close(pipefd[1])

    // Wait for less to exit
    var exitStatus: Int32 = 0
    waitpid(pid, &exitStatus, 0)

    return true
  }
}
