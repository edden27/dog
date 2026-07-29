import Foundation
import Testing

@testable import dog

/// Round-trip and corruption coverage for the `--set-default-theme`
/// artifact. Every test writes to its own temp path — the real
/// `~/.config/dog/default-theme` is never touched.
@Suite("Default Theme Artifact")
struct DefaultThemeArtifactTests {

  /// A fresh temp path for one test's artifact.
  private static func temporaryArtifactPath() -> String {
    FileManager.default.temporaryDirectory
      .appendingPathComponent("dog-artifact-\(UUID().uuidString)").path
  }

  /// A full-size style table with variety: backgrounds, bold, italic,
  /// plain — one entry per real `TokenType`.
  private static func referenceStyles(
    withOptionals: Bool = true
  ) -> Dog.ResolvedThemeStyles {
    let colorTable = TokenType.allCases.indices.map { index -> Style in
      let red = UInt8(truncatingIfNeeded: 40 &+ index &* 37)
      let green = UInt8(truncatingIfNeeded: 90 &+ index &* 53)
      let blue = UInt8(truncatingIfNeeded: 140 &+ index &* 29)
      if index % 6 == 0 {
        return Style(
          r: red, g: green, b: blue, bgR: 29, bgG: 29, bgB: 29,
          bold: index % 5 == 0, italic: index % 7 == 0
        )
      }
      return Style(
        r: red, g: green, b: blue, bold: index % 5 == 0, italic: index % 7 == 0
      )
    }
    return Dog.ResolvedThemeStyles(
      colorTable: colorTable,
      baseColor: Style(r: 205, g: 190, b: 171),
      lineNumberStyle: withOptionals ? Style(r: 129, g: 116, b: 100) : nil,
      gutterBgStyle: withOptionals ? Style(r: 29, g: 29, b: 29) : nil,
      editorBgStyle: withOptionals ? Style(r: 43, g: 43, b: 43) : nil
    )
  }

  /// Styles match when both the packed value AND the derived ANSI bytes
  /// agree — the bytes prove the load-time rebuild is faithful.
  private static func fullyEqual(_ first: Style?, _ second: Style?) -> Bool {
    switch (first, second) {
    case (nil, nil): return true
    case (let one?, let two?): return one.packed == two.packed && one.bytes == two.bytes
    default: return false
    }
  }

  // MARK: - Round trip

  @Test("save then load reproduces every style and the theme name")
  func roundTripPreservesEverything() throws {
    let path = Self.temporaryArtifactPath()
    defer { try? FileManager.default.removeItem(atPath: path) }
    let original = Self.referenceStyles()

    try DefaultThemeArtifact.save(
      styles: original, themeName: "Nord Dark", path: path
    )
    guard case .loaded(let name, let loaded) = DefaultThemeArtifact.load(path: path)
    else {
      Issue.record("expected .loaded")
      return
    }

    #expect(name == "Nord Dark")
    #expect(loaded.colorTable.count == original.colorTable.count)
    for index in original.colorTable.indices {
      #expect(Self.fullyEqual(loaded.colorTable[index], original.colorTable[index]))
    }
    #expect(Self.fullyEqual(loaded.baseColor, original.baseColor))
    #expect(Self.fullyEqual(loaded.lineNumberStyle, original.lineNumberStyle))
    #expect(Self.fullyEqual(loaded.gutterBgStyle, original.gutterBgStyle))
    #expect(Self.fullyEqual(loaded.editorBgStyle, original.editorBgStyle))
  }

  @Test("absent optional styles stay nil through a round trip")
  func roundTripPreservesNilOptionals() throws {
    let path = Self.temporaryArtifactPath()
    defer { try? FileManager.default.removeItem(atPath: path) }

    try DefaultThemeArtifact.save(
      styles: Self.referenceStyles(withOptionals: false),
      themeName: "Bare Theme", path: path
    )
    guard case .loaded(_, let loaded) = DefaultThemeArtifact.load(path: path)
    else {
      Issue.record("expected .loaded")
      return
    }

    #expect(loaded.lineNumberStyle == nil)
    #expect(loaded.gutterBgStyle == nil)
    #expect(loaded.editorBgStyle == nil)
  }

  @Test("theme names with colons and paths survive the round trip")
  func roundTripPreservesColonName() throws {
    let path = Self.temporaryArtifactPath()
    defer { try? FileManager.default.removeItem(atPath: path) }

    try DefaultThemeArtifact.save(
      styles: Self.referenceStyles(), themeName: "vim-light:Vim Dark", path: path
    )
    guard case .loaded(let name, _) = DefaultThemeArtifact.load(path: path)
    else {
      Issue.record("expected .loaded")
      return
    }
    #expect(name == "vim-light:Vim Dark")
  }

  // MARK: - Absent and corrupt files

  @Test("missing file loads as none")
  func missingFileIsNone() {
    guard case .none = DefaultThemeArtifact.load(path: Self.temporaryArtifactPath())
    else {
      Issue.record("expected .none")
      return
    }
  }

  @Test("truncated file loads as unreadable")
  func truncatedFileIsUnreadable() throws {
    let path = Self.temporaryArtifactPath()
    defer { try? FileManager.default.removeItem(atPath: path) }
    try DefaultThemeArtifact.save(
      styles: Self.referenceStyles(), themeName: "Nord Dark", path: path
    )
    let contents = try Data(contentsOf: URL(fileURLWithPath: path))
    try contents.prefix(20).write(to: URL(fileURLWithPath: path))

    guard case .unreadable = DefaultThemeArtifact.load(path: path) else {
      Issue.record("expected .unreadable")
      return
    }
  }

  @Test("wrong magic loads as unreadable")
  func wrongMagicIsUnreadable() throws {
    let path = Self.temporaryArtifactPath()
    defer { try? FileManager.default.removeItem(atPath: path) }
    try DefaultThemeArtifact.save(
      styles: Self.referenceStyles(), themeName: "Nord Dark", path: path
    )
    var contents = try Data(contentsOf: URL(fileURLWithPath: path))
    contents[0] = UInt8(ascii: "X")
    try contents.write(to: URL(fileURLWithPath: path))

    guard case .unreadable = DefaultThemeArtifact.load(path: path) else {
      Issue.record("expected .unreadable")
      return
    }
  }

  @Test("token count from a different build loads as unreadable")
  func staleTokenCountIsUnreadable() throws {
    let path = Self.temporaryArtifactPath()
    defer { try? FileManager.default.removeItem(atPath: path) }
    try DefaultThemeArtifact.save(
      styles: Self.referenceStyles(), themeName: "Nord Dark", path: path
    )
    var contents = try Data(contentsOf: URL(fileURLWithPath: path))
    contents[6] &-= 1  // count low byte: pretend one fewer TokenType
    try contents.write(to: URL(fileURLWithPath: path))

    guard case .unreadable = DefaultThemeArtifact.load(path: path) else {
      Issue.record("expected .unreadable")
      return
    }
  }

  @Test("random junk at the path loads as unreadable")
  func junkFileIsUnreadable() throws {
    let path = Self.temporaryArtifactPath()
    defer { try? FileManager.default.removeItem(atPath: path) }
    let junk = Data((0..<2000).map { _ in UInt8.random(in: 0...255) })
    try junk.write(to: URL(fileURLWithPath: path))

    let outcome = DefaultThemeArtifact.load(path: path)
    if case .loaded = outcome {
      // 1-in-2^48 magic+version+format+count collision — not a real risk.
      Issue.record("junk decoded as a valid artifact")
    }
  }

  // MARK: - Remove

  @Test("remove deletes the artifact and is friendly when nothing is set")
  func removeDeletesAndIsIdempotent() throws {
    let path = Self.temporaryArtifactPath()
    try DefaultThemeArtifact.save(
      styles: Self.referenceStyles(), themeName: "Nord Dark", path: path
    )

    try DefaultThemeArtifact.remove(path: path)
    guard case .none = DefaultThemeArtifact.load(path: path) else {
      Issue.record("expected .none after remove")
      return
    }
    // Removing again with nothing there must not throw.
    try DefaultThemeArtifact.remove(path: path)
  }
}
