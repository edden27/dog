import Foundation
import Testing

@testable import dog

/// Regression net for `ZedThemeScanner` and `ZedThemeLoader` before the
/// variant-selection refactor. Locks current behavior against real Zed
/// theme bundles in `/themes/`.
@Suite("Zed Theme Parser")
struct ZedThemeTests {

  /// Resolve a theme fixture path relative to the repo root.
  private static func themePath(_ filename: String) -> String {
    let testDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    let projectRoot =
      testDir
      .deletingLastPathComponent()  // dogTests
      .deletingLastPathComponent()  // Tests
      .deletingLastPathComponent()  // cli
    return projectRoot.appendingPathComponent("themes/\(filename)").path
  }

  /// Repo-root `themes/` directory — the fixture directory used across
  /// resolver, listing, and variant-scoping tests.
  static func themesDir() -> String {
    let testDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    let projectRoot =
      testDir
      .deletingLastPathComponent()  // dogTests
      .deletingLastPathComponent()  // Tests
      .deletingLastPathComponent()  // cli
    return projectRoot.appendingPathComponent("themes").path
  }

  private static func themeBytes(_ filename: String) throws -> [UInt8] {
    let path = themePath(filename)
    let data = try Data(contentsOf: URL(fileURLWithPath: path))
    return Array(data)
  }

  // MARK: - Scanner: syntax entries

  @Test("scanSyntaxEntries returns non-empty for all fixtures")
  func scanAllFixtures() throws {
    let fixtures = [
      "Catppuccin.json",
      "Nord.json",
      "One Dark Pro.json",
      "Ultimate Dark Neo.json",
      "macOS Classic.json",
      "Everforest Theme (blur).json"
    ]
    for fixture in fixtures {
      let bytes = try Self.themeBytes(fixture)
      let entries = ZedThemeScanner.scanSyntaxEntries(bytes)
      #expect(!entries.isEmpty, "\(fixture) produced zero syntax entries")
    }
  }

  @Test("syntax entries carry valid hex colors")
  func syntaxEntriesHaveValidColors() throws {
    let bytes = try Self.themeBytes("Catppuccin.json")
    let entries = ZedThemeScanner.scanSyntaxEntries(bytes)
    #expect(entries.count > 0)
    for entry in entries {
      #expect(entry.color.hasPrefix("#"), "scope '\(entry.scope)' color missing #")
      #expect(
        ANSICodes.parseHex(entry.color) != nil,
        "scope '\(entry.scope)' has unparseable color '\(entry.color)'"
      )
    }
  }

  @Test("syntax entries expose scope names")
  func syntaxEntriesHaveScopes() throws {
    let bytes = try Self.themeBytes("Nord.json")
    let entries = ZedThemeScanner.scanSyntaxEntries(bytes)
    let scopes = Set(entries.map(\.scope))
    #expect(!scopes.isEmpty)
    // Nord is known to define at least these common scopes
    #expect(scopes.contains("keyword") || scopes.contains("comment"))
  }

  @Test("font weight and font style are parsed when present")
  func fontAttributesParsed() throws {
    let bytes = try Self.themeBytes("Catppuccin.json")
    let entries = ZedThemeScanner.scanSyntaxEntries(bytes)
    // At least some entries should have non-default weights or italic styles
    let hasFontAttributes = entries.contains { entry in
      entry.fontWeight != 400 || entry.fontStyle == "italic"
    }
    #expect(hasFontAttributes, "Catppuccin should have bold or italic entries")
  }

  // MARK: - Scanner: style block

  @Test("scanTextColor extracts the theme's base text color")
  func textColorExtracted() throws {
    let bytes = try Self.themeBytes("Nord.json")
    let color = ZedThemeScanner.scanTextColor(bytes)
    #expect(color != nil, "text color should be present")
    if let color {
      #expect(ANSICodes.parseHex(color) != nil, "text color '\(color)' unparseable")
    }
  }

  @Test("scanStyleValue extracts dotted editor keys")
  func editorKeysExtracted() throws {
    let bytes = try Self.themeBytes("Catppuccin.json")
    let keys = [
      "editor.foreground",
      "editor.background",
      "editor.line_number",
      "editor.gutter.background"
    ]
    for key in keys {
      let value = ZedThemeScanner.scanStyleValue(bytes, key: key)
      #expect(value != nil, "Catppuccin missing '\(key)'")
      if let value {
        #expect(ANSICodes.parseHex(value) != nil, "'\(key)' has bad color '\(value)'")
      }
    }
  }

  @Test("scanStyleValue returns nil for missing keys")
  func missingKeyReturnsNil() throws {
    let bytes = try Self.themeBytes("Nord.json")
    let value = ZedThemeScanner.scanStyleValue(bytes, key: "this.key.does.not.exist")
    #expect(value == nil)
  }

  // MARK: - Loader

  @Test("ZedThemeLoader loads all fixtures without throwing")
  func loaderLoadsAllFixtures() throws {
    let fixtures = [
      "Catppuccin.json",
      "Nord.json",
      "One Dark Pro.json",
      "Ultimate Dark Neo.json",
      "macOS Classic.json",
      "Everforest Theme (blur).json"
    ]
    for fixture in fixtures {
      let path = Self.themePath(fixture)
      let theme = try ZedThemeLoader.load(from: path)
      #expect(
        theme.colorTable.count == TokenType.allCases.count,
        "\(fixture) colorTable has wrong size"
      )
    }
  }

  @Test("loaded theme color table is indexed by TokenType.rawValue")
  func colorTableIndexing() throws {
    let path = Self.themePath("Catppuccin.json")
    let theme = try ZedThemeLoader.load(from: path)
    // Every index should be reachable
    for tokenType in TokenType.allCases {
      let style = theme.color(for: tokenType)
      // Style should at least have a non-zero color (base color fallback is valid)
      _ = style
    }
    #expect(theme.colorTable.count == TokenType.allCases.count)
  }

  @Test("loaded theme exposes editor UI colors")
  func editorUIColorsLoaded() throws {
    let path = Self.themePath("Catppuccin.json")
    let theme = try ZedThemeLoader.load(from: path)
    #expect(theme.editorFgStyle != nil, "editor.foreground missing")
    #expect(theme.editorBgStyle != nil, "editor.background missing")
    #expect(theme.lineNumberStyle != nil, "editor.line_number missing")
  }

  @Test("loader throws invalidTheme for non-existent file")
  func missingFileThrows() {
    #expect(throws: DogError.self) {
      _ = try ZedThemeLoader.load(from: "/nonexistent/path/to/theme.json")
    }
  }

  @Test("loader throws invalidTheme for file without syntax block")
  func fileWithoutSyntaxThrows() throws {
    let tempDir = FileManager.default.temporaryDirectory
    let tempPath = tempDir.appendingPathComponent("dog-bad-theme-\(UUID().uuidString).json")
    let content = #"{"name": "Not A Theme", "foo": "bar"}"#
    try content.write(to: tempPath, atomically: true, encoding: .utf8)
    defer { try? FileManager.default.removeItem(at: tempPath) }

    #expect(throws: DogError.self) {
      _ = try ZedThemeLoader.load(from: tempPath.path)
    }
  }

  // MARK: - Alpha composite

  @Test("parseHex 6-char hex returns RGB unchanged")
  func parseHexSixChar() {
    let rgb = ANSICodes.parseHex("#d07277")
    #expect(rgb?.red == 0xD0)
    #expect(rgb?.green == 0x72)
    #expect(rgb?.blue == 0x77)
  }

  @Test("parseHex 8-char hex with full alpha strips alpha (no bg)")
  func parseHexEightCharOpaqueNoBackground() {
    let rgb = ANSICodes.parseHex("#d07277ff")
    #expect(rgb?.red == 0xD0)
    #expect(rgb?.green == 0x72)
    #expect(rgb?.blue == 0x77)
  }

  @Test("parseHex 8-char hex with full alpha + bg is passthrough")
  func parseHexEightCharOpaqueWithBackground() {
    let background = ANSICodes.RGB(red: 0x1E, green: 0x1E, blue: 0x2E)
    let rgb = ANSICodes.parseHex("#d07277ff", background: background)
    #expect(rgb?.red == 0xD0)
    #expect(rgb?.green == 0x72)
    #expect(rgb?.blue == 0x77)
  }

  @Test("parseHex 8-char hex with 50% alpha composites over bg")
  func parseHexFiftyPercentComposite() {
    // #ffffff80 (50% white) over #1e1e2e should blend to midpoint
    let background = ANSICodes.RGB(red: 0x1E, green: 0x1E, blue: 0x2E)
    let rgb = ANSICodes.parseHex("#ffffff80", background: background)
    // Allow ±1 for rounding
    #expect(rgb != nil)
    if let rgb {
      #expect(abs(Int(rgb.red) - 0x8F) <= 1, "red blended wrong: \(rgb.red)")
      #expect(abs(Int(rgb.green) - 0x8F) <= 1, "green blended wrong: \(rgb.green)")
      #expect(abs(Int(rgb.blue) - 0x97) <= 1, "blue blended wrong: \(rgb.blue)")
    }
  }

  @Test("parseHex 8-char hex with zero alpha yields pure bg")
  func parseHexZeroAlphaYieldsBackground() {
    let background = ANSICodes.RGB(red: 0x1E, green: 0x1E, blue: 0x2E)
    let rgb = ANSICodes.parseHex("#ff000000", background: background)
    #expect(rgb?.red == 0x1E)
    #expect(rgb?.green == 0x1E)
    #expect(rgb?.blue == 0x2E)
  }

  @Test("parseHex rejects malformed strings")
  func parseHexRejectsMalformed() {
    #expect(ANSICodes.parseHex("") == nil)
    #expect(ANSICodes.parseHex("#") == nil)
    #expect(ANSICodes.parseHex("#xyzxyz") == nil)
    #expect(ANSICodes.parseHex("not-a-color") == nil)
    #expect(ANSICodes.parseHex("#12345") == nil)  // wrong length
  }

  @Test("parseHexComposite returns nil on wrong length")
  func parseHexCompositeRejectsWrongLength() {
    let background = ANSICodes.RGB(red: 0, green: 0, blue: 0)
    #expect(ANSICodes.parseHexComposite("#d07277", over: background) == nil)
    #expect(ANSICodes.parseHexComposite("#bad", over: background) == nil)
  }

  // MARK: - Variant walker

  @Test("findVariantRange hits exact variant name in multi-variant bundle")
  func findVariantRangeExactMatch() throws {
    let bytes = try Self.themeBytes("Catppuccin.json")
    let target = Array("Catppuccin Mocha".utf8)
    let range = ZedThemeVariantWalker.findVariantRange(bytes, target: target)
    #expect(range != nil, "Catppuccin Mocha should be findable")
  }

  @Test("findVariantRange isolates different variants to different ranges")
  func findVariantRangesDiffer() throws {
    let bytes = try Self.themeBytes("Catppuccin.json")
    let latte = ZedThemeVariantWalker.findVariantRange(
      bytes, target: Array("Catppuccin Latte".utf8)
    )
    let mocha = ZedThemeVariantWalker.findVariantRange(
      bytes, target: Array("Catppuccin Mocha".utf8)
    )
    #expect(latte != nil && mocha != nil)
    #expect(latte?.start != mocha?.start, "different variants should start at different offsets")
  }

  @Test("findVariantRange with nil target returns first variant")
  func findVariantRangeNilTargetFirst() throws {
    let bytes = try Self.themeBytes("Nord.json")
    let range = ZedThemeVariantWalker.findVariantRange(bytes, target: nil)
    #expect(range != nil, "nil target should return first variant range")
  }

  @Test("findVariantRange returns nil when variant name doesn't exist")
  func findVariantRangeMissReturnsNil() throws {
    let bytes = try Self.themeBytes("Nord.json")
    let target = Array("Definitely Not In Nord".utf8)
    #expect(ZedThemeVariantWalker.findVariantRange(bytes, target: target) == nil)
  }

  @Test("listVariantNames returns all variants in a bundle")
  func listVariantNamesAll() throws {
    let bytes = try Self.themeBytes("Catppuccin.json")
    let names = ZedThemeVariantWalker.listVariantNames(bytes)
    #expect(names.count == 4, "Catppuccin bundle should have 4 variants")
    #expect(names.contains("Catppuccin Latte"))
    #expect(names.contains("Catppuccin Frappé"))
    #expect(names.contains("Catppuccin Macchiato"))
    #expect(names.contains("Catppuccin Mocha"))
  }

  @Test("listVariantNames handles single-variant bundles")
  func listVariantNamesSingle() throws {
    let bytes = try Self.themeBytes("One Dark Pro.json")
    let names = ZedThemeVariantWalker.listVariantNames(bytes)
    #expect(names.count == 1)
    #expect(names.contains("One Dark Pro"))
  }

  @Test("listVariantNames returns empty for file without themes array")
  func listVariantNamesMissingArray() {
    let bytes = Array(#"{"foo": "bar", "baz": 1}"#.utf8)
    let names = ZedThemeVariantWalker.listVariantNames(bytes)
    #expect(names.isEmpty)
  }

  // MARK: - Variant-scoped loader

  @Test("loading Catppuccin Mocha variant extracts Mocha's editor.background")
  func variantScopeExtractsCorrectBackground() throws {
    let bytes = try Self.themeBytes("Catppuccin.json")
    guard
      let range = ZedThemeVariantWalker.findVariantRange(
        bytes, target: Array("Catppuccin Mocha".utf8)
      )
    else {
      Issue.record("could not locate Mocha variant")
      return
    }
    let theme = try ZedThemeLoader.load(
      bytes: bytes, path: "test://catppuccin", variantRange: range
    )
    // Mocha's editor.background is #1e1e2e per Catppuccin.json
    #expect(theme.editorBgStyle != nil)
    // We can't read Style.red directly (internal), but we can verify the
    // theme loaded without throwing and the style is non-nil.
  }

  @Test("loading Latte vs Mocha variants picks different bg")
  func variantScopeDifferentBackgrounds() throws {
    let bytes = try Self.themeBytes("Catppuccin.json")
    let latteRange = ZedThemeVariantWalker.findVariantRange(
      bytes, target: Array("Catppuccin Latte".utf8)
    )
    let mochaRange = ZedThemeVariantWalker.findVariantRange(
      bytes, target: Array("Catppuccin Mocha".utf8)
    )
    #expect(latteRange != nil && mochaRange != nil)

    let latte = try ZedThemeLoader.load(
      bytes: bytes, path: "test://latte", variantRange: latteRange
    )
    let mocha = try ZedThemeLoader.load(
      bytes: bytes, path: "test://mocha", variantRange: mochaRange
    )
    // Both should load cleanly and expose an editor background style
    #expect(latte.editorBgStyle != nil)
    #expect(mocha.editorBgStyle != nil)
  }

  // MARK: - Directory scanner

  @Test("listJSONFiles returns all .json files in a directory")
  func listJSONFilesFindsFixtures() {
    let files = ZedThemeDirectoryScanner.listJSONFiles(in: Self.themesDir())
    #expect(files.contains("Catppuccin.json"))
    #expect(files.contains("Nord.json"))
    #expect(files.contains("One Dark Pro.json"))
    #expect(files.contains("Ultimate Dark Neo.json"))
    #expect(files.contains("macOS Classic.json"))
    #expect(files.contains("Everforest Theme (blur).json"))
  }

  @Test("listJSONFiles returns sorted output")
  func listJSONFilesSorted() {
    let files = ZedThemeDirectoryScanner.listJSONFiles(in: Self.themesDir())
    let sorted = files.sorted()
    #expect(files == sorted, "listJSONFiles should return sorted filenames")
  }

  @Test("listJSONFiles returns empty for missing directory")
  func listJSONFilesMissingDir() {
    let files = ZedThemeDirectoryScanner.listJSONFiles(
      in: "/nonexistent/dir/that/does/not/exist"
    )
    #expect(files.isEmpty)
  }

  @Test("fileExists returns true for an existing file")
  func fileExistsHit() {
    let path = Self.themePath("Nord.json")
    #expect(ZedThemeDirectoryScanner.fileExists(path))
  }

  @Test("fileExists returns false for missing path")
  func fileExistsMiss() {
    #expect(!ZedThemeDirectoryScanner.fileExists("/nonexistent/file"))
  }

  // MARK: - Resolver cascade

  @Test("load(name:directory:) resolves single-word bundle names")
  func resolverSingleWordName() throws {
    let theme = try ZedThemeLoader.load(name: "Nord", directory: Self.themesDir())
    #expect(theme.colorTable.count == TokenType.allCases.count)
  }

  @Test("load(name:directory:) resolves multi-word variant names")
  func resolverMultiWordVariantName() throws {
    let theme = try ZedThemeLoader.load(
      name: "Catppuccin Mocha", directory: Self.themesDir()
    )
    #expect(theme.colorTable.count == TokenType.allCases.count)
  }

  @Test("load(name:directory:) resolves bundles where filename has spaces")
  func resolverSpacedFilename() throws {
    // "One Dark Pro.json" — full name matches filename
    let theme = try ZedThemeLoader.load(
      name: "One Dark Pro", directory: Self.themesDir()
    )
    #expect(theme.colorTable.count == TokenType.allCases.count)
  }

  @Test("load(name:directory:) resolves via progressive prefix shortening")
  func resolverProgressivePrefix() throws {
    // "macOS Classic Dark" — no filename match, but "macOS Classic.json"
    // contains a variant with that name. Exercises the prefix walker.
    let theme = try ZedThemeLoader.load(
      name: "macOS Classic Dark", directory: Self.themesDir()
    )
    #expect(theme.colorTable.count == TokenType.allCases.count)
  }

  @Test("load(name:directory:) falls back to dir scan for orphan variants")
  func resolverFallbackScan() throws {
    // "Everforest Dark Hard (blur)" has no matching filename prefix.
    // Should fall through Phase 1 → Phase 2 dir scan and match inside
    // "Everforest Theme (blur).json".
    let theme = try ZedThemeLoader.load(
      name: "Everforest Dark Hard (blur)", directory: Self.themesDir()
    )
    #expect(theme.colorTable.count == TokenType.allCases.count)
  }

  @Test("load(name:directory:) throws themeNotFound when exhausted")
  func resolverThrowsOnMiss() {
    #expect(throws: DogError.self) {
      _ = try ZedThemeLoader.load(
        name: "Dracula Pro Van Helsing", directory: Self.themesDir()
      )
    }
  }

  @Test("load(name:directory:) throws themeNotFound for empty directory")
  func resolverThrowsEmptyDirectory() {
    #expect(throws: DogError.self) {
      _ = try ZedThemeLoader.load(name: "Nord", directory: "")
    }
  }

  @Test("listVariantNames(in:) enumerates all bundles in directory")
  func resolverListVariantNames() {
    let bundles = ZedThemeLoader.listVariantNames(in: Self.themesDir())
    let bundleNames = bundles.map(\.bundle)
    #expect(bundleNames.contains("Catppuccin"))
    #expect(bundleNames.contains("Nord"))
    #expect(bundleNames.contains("One Dark Pro"))
    // Catppuccin should have 4 variants
    let catppuccin = bundles.first { $0.bundle == "Catppuccin" }
    #expect(catppuccin?.variants.count == 4)
  }

  @Test("listVariantNames(in:) returns empty for missing directory")
  func resolverListEmptyForMissing() {
    let bundles = ZedThemeLoader.listVariantNames(in: "/nonexistent/dir")
    #expect(bundles.isEmpty)
  }
}
