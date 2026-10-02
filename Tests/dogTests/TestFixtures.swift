import Foundation

/// Paths into the fixtures checked into the repo under `scripts/fixtures/`.
enum TestFixtures {
  private static let repoRoot = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()  // TestFixtures.swift → dogTests/
    .deletingLastPathComponent()  // dogTests → Tests/
    .deletingLastPathComponent()  // Tests → repo root

  /// Absolute path of a file or folder inside `scripts/fixtures/`.
  static func path(_ relativePath: String) -> String {
    repoRoot.appendingPathComponent("scripts/fixtures/\(relativePath)").path
  }
}
