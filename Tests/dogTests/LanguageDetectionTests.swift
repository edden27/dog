import Testing

@testable import dog

// MARK: - Test Data

/// Each case becomes its own test in the runner with a readable label.
struct DetectionCase: Sendable, CustomTestStringConvertible {
  let input: String
  let expected: String?
  let label: String
  var testDescription: String { label }

  init(_ input: String, _ expected: String?, label: String? = nil) {
    self.input = input
    self.expected = expected
    self.label = label ?? "\(input) → \(expected ?? "nil")"
  }
}

struct ShebangCase: Sendable, CustomTestStringConvertible {
  let source: String
  let expected: String?
  let label: String
  var testDescription: String { label }

  init(_ source: String, _ expected: String?, label: String? = nil) {
    self.source = source
    self.expected = expected
    self.label = label ?? "\(expected ?? "nil")"
  }
}

// MARK: - Tests

@Suite("Language Detection")
struct LanguageDetectionTests {

  // MARK: - Stage 1: Explicit Flag

  @Test("Explicit flag returns as-is")
  func explicitFlag() {
    #expect(LanguageDetector.detect(filename: "foo.py", sourceBytes: [], explicit: "swift") == "swift")
  }

  @Test("Explicit wins over filename")
  func explicitWinsOverFilename() {
    #expect(LanguageDetector.detect(filename: "Makefile", sourceBytes: [], explicit: "rust") == "rust")
  }

  @Test("Explicit wins over extension")
  func explicitWinsOverExtension() {
    #expect(LanguageDetector.detect(filename: "file.js", sourceBytes: [], explicit: "python") == "python")
  }

  @Test("Explicit wins over shebang")
  func explicitWinsOverShebang() {
    #expect(
      LanguageDetector.detect(filename: nil, sourceBytes: Array("#!/usr/bin/env python3\n".utf8), explicit: "ruby")
        == "ruby")
  }

  // MARK: - Stage 2: Filename

  private static let filenamesCases: [DetectionCase] = [
    // JavaScript
    .init("Jakefile", "javascript"),
    // Python
    .init("SConstruct", "python"),
    .init("SConscript", "python"),
    .init("wscript", "python"),
    .init("DEPS", "python"),
    .init("BUILD", "python"),
    // Ruby
    .init("Gemfile", "ruby"),
    .init("Rakefile", "ruby"),
    .init("Capfile", "ruby"),
    .init("Podfile", "ruby"),
    .init("Brewfile", "ruby"),
    .init("Vagrantfile", "ruby"),
    .init("Guardfile", "ruby"),
    .init("Fastfile", "ruby"),
    .init("Deliverfile", "ruby"),
    .init("Snapfile", "ruby"),
    .init("Dangerfile", "ruby"),
    .init("Appraisals", "ruby"),
    .init("Steepfile", "ruby"),
    .init("Thorfile", "ruby"),
    .init(".irbrc", "ruby"),
    .init(".pryrc", "ruby"),
    .init(".simplecov", "ruby"),
    // Bash
    .init(".bashrc", "bash"),
    .init(".bash_aliases", "bash"),
    .init(".bash_functions", "bash"),
    .init(".bash_history", "bash"),
    .init(".bash_logout", "bash"),
    .init(".bash_profile", "bash"),
    .init(".zshrc", "bash"),
    .init(".zprofile", "bash"),
    .init(".zlogin", "bash"),
    .init(".zlogout", "bash"),
    .init(".zshenv", "bash"),
    .init(".profile", "bash"),
    .init(".login", "bash"),
    .init(".cshrc", "bash"),
    .init(".kshrc", "bash"),
    .init(".xinitrc", "bash"),
    .init(".xsession", "bash"),
    .init(".envrc", "bash"),
    .init(".flaskenv", "bash"),
    .init(".tmux.conf", "bash"),
    .init("gradlew", "bash"),
    .init("mvnw", "bash"),
    .init("PKGBUILD", "bash"),
    // Rust
    .init("Cargo.lock", "rust"),
    // Swift
    .init("Package.swift", "swift"),
    // JSON
    .init("composer.lock", "json"),
    .init("deno.lock", "json"),
    .init("bun.lock", "json"),
    .init("flake.lock", "json"),
    .init("Pipfile.lock", "json"),
    .init("Package.resolved", "json"),
    .init("MODULE.bazel.lock", "json"),
    // YAML
    .init(".clang-format", "yaml"),
    .init(".clang-tidy", "yaml"),
    .init(".clangd", "yaml"),
    .init(".gemrc", "yaml"),
    .init("glide.lock", "yaml"),
    .init("yarn.lock", "yaml"),
    .init("CITATION.cff", "yaml"),
    // Lua
    .init(".luacheckrc", "lua"),
    // Markdown
    .init("contents.lr", "markdown")
  ]

  @Test("Filename detection", arguments: filenamesCases)
  func filenameDetection(_ testCase: DetectionCase) {
    let result = LanguageDetector.detect(filename: testCase.input, sourceBytes: [], explicit: nil)
    #expect(result == testCase.expected)
  }

  @Test("BUILD is case-sensitive: build → nil")
  func buildLowercase() {
    #expect(LanguageDetector.detect(filename: "build", sourceBytes: [], explicit: nil) == nil)
  }

  @Test("Filename extracted from full path")
  func filenameFromPath() {
    #expect(
      LanguageDetector.detect(filename: "/home/user/project/.bashrc", sourceBytes: [], explicit: nil)
        == "bash")
  }

  // MARK: - Stage 3: Extension

  private static let extensionCases: [DetectionCase] = [
    // Swift
    .init(".swift", "swift"),
    // JavaScript
    .init(".js", "javascript"), .init(".mjs", "javascript"),
    .init(".cjs", "javascript"), .init(".jsx", "javascript"),
    // TypeScript
    .init(".ts", "typescript"), .init(".mts", "typescript"), .init(".cts", "typescript"),
    // TSX
    .init(".tsx", "tsx"),
    // Python
    .init(".py", "python"), .init(".pyw", "python"),
    .init(".pyi", "python"), .init(".py3", "python"),
    // Rust
    .init(".rs", "rust"),
    // Go
    .init(".go", "go"),
    // JSON
    .init(".json", "json"), .init(".jsonl", "json"), .init(".jsonc", "json"),
    .init(".geojson", "json"), .init(".sarif", "json"),
    .init(".topojson", "json"), .init(".webmanifest", "json"), .init(".avsc", "json"),
    // YAML
    .init(".yaml", "yaml"), .init(".yml", "yaml"),
    // Bash
    .init(".sh", "bash"), .init(".bash", "bash"), .init(".zsh", "bash"),
    .init(".ksh", "bash"), .init(".bats", "bash"), .init(".command", "bash"),
    .init(".tmux", "bash"), .init(".zsh-theme", "bash"),
    // HTML
    .init(".html", "html"), .init(".htm", "html"),
    .init(".xhtml", "html"), .init(".xht", "html"),
    // CSS
    .init(".css", "css"),
    // Ruby
    .init(".rb", "ruby"), .init(".rbx", "ruby"), .init(".rbw", "ruby"),
    .init(".gemspec", "ruby"), .init(".rake", "ruby"),
    .init(".ru", "ruby"), .init(".podspec", "ruby"),
    // C
    .init(".c", "c"), .init(".idc", "c"),
    // C++ (.h follows bat override)
    .init(".cpp", "cpp"), .init(".cc", "cpp"), .init(".cxx", "cpp"),
    .init(".c++", "cpp"), .init(".cppm", "cpp"), .init(".h", "cpp"),
    .init(".hh", "cpp"), .init(".hpp", "cpp"), .init(".hxx", "cpp"),
    .init(".h++", "cpp"), .init(".ipp", "cpp"), .init(".ixx", "cpp"),
    .init(".tpp", "cpp"), .init(".txx", "cpp"), .init(".inl", "cpp"),
    .init(".ino", "cpp"),
    // Lua
    .init(".lua", "lua"), .init(".nse", "lua"), .init(".p8", "lua"),
    .init(".rockspec", "lua"), .init(".wlua", "lua"),
    // Markdown
    .init(".md", "markdown"), .init(".markdown", "markdown"),
    .init(".mdown", "markdown"), .init(".mdwn", "markdown"),
    .init(".mkd", "markdown"), .init(".mkdn", "markdown"),
    .init(".mkdown", "markdown"), .init(".ronn", "markdown"),
    .init(".livemd", "markdown"), .init(".workbook", "markdown")
  ]

  @Test("Extension detection", arguments: extensionCases)
  func extensionDetection(_ testCase: DetectionCase) {
    let result = LanguageDetector.detect(filename: "testfile\(testCase.input)", sourceBytes: [], explicit: nil)
    #expect(result == testCase.expected)
  }

  @Test(".conf is not mapped")
  func confUnmapped() {
    #expect(LanguageDetector.detect(filename: "nginx.conf", sourceBytes: [], explicit: nil) == nil)
  }

  @Test("Dotfile without known filename → nil")
  func unknownDotfile() {
    #expect(LanguageDetector.detect(filename: ".unknowndotfile", sourceBytes: [], explicit: nil) == nil)
  }

  @Test("No extension → nil")
  func noExtension() {
    #expect(LanguageDetector.detect(filename: "noext", sourceBytes: [], explicit: nil) == nil)
  }

  @Test("Multi-part: .d.ts → typescript")
  func multiPartDts() {
    #expect(LanguageDetector.detect(filename: "types.d.ts", sourceBytes: [], explicit: nil) == "typescript")
  }

  @Test("Multi-part: .test.js → javascript")
  func multiPartTestJs() {
    #expect(LanguageDetector.detect(filename: "app.test.js", sourceBytes: [], explicit: nil) == "javascript")
  }

  // MARK: - Stage 3: Suffix Stripping

  private static let suffixCases: [DetectionCase] = [
    .init("config.yaml.bak", "yaml", label: ".bak → yaml"),
    .init("script.sh~", "bash", label: "~ → bash"),
    .init("settings.json.orig", "json", label: ".orig → json"),
    .init("config.yaml.rpmsave", "yaml", label: ".rpmsave → yaml"),
    .init("style.css.old", "css", label: ".old → css"),
    .init("index.html.dpkg-new", "html", label: ".dpkg-new → html"),
    .init("app.py.ucf-old", "python", label: ".ucf-old → python"),
    .init("main.rs.rpmorig", "rust", label: ".rpmorig → rust")
  ]

  @Test("Suffix stripping", arguments: suffixCases)
  func suffixStripping(_ testCase: DetectionCase) {
    let result = LanguageDetector.detect(filename: testCase.input, sourceBytes: [], explicit: nil)
    #expect(result == testCase.expected)
  }

  @Test("Makefile.in → nil (no extension after stripping)")
  func makefileIn() {
    #expect(LanguageDetector.detect(filename: "Makefile.in", sourceBytes: [], explicit: nil) == nil)
  }

  @Test("Only strip once: file.yaml.bak.old → nil")
  func stripOnce() {
    #expect(LanguageDetector.detect(filename: "file.yaml.bak.old", sourceBytes: [], explicit: nil) == nil)
  }

  // MARK: - Stage 4: Shebang

  private static let interpreterCases: [ShebangCase] = [
    // JavaScript
    .init("#!/usr/bin/env node\n", "javascript", label: "node"),
    .init("#!/usr/bin/env nodejs\n", "javascript", label: "nodejs"),
    .init("#!/usr/bin/env js\n", "javascript", label: "js"),
    .init("#!/usr/bin/env chakra\n", "javascript", label: "chakra"),
    .init("#!/usr/bin/env d8\n", "javascript", label: "d8"),
    .init("#!/usr/bin/env gjs\n", "javascript", label: "gjs"),
    .init("#!/usr/bin/env qjs\n", "javascript", label: "qjs"),
    .init("#!/usr/bin/env rhino\n", "javascript", label: "rhino"),
    .init("#!/usr/bin/env v8\n", "javascript", label: "v8"),
    .init("#!/usr/bin/env v8-shell\n", "javascript", label: "v8-shell"),
    // TypeScript
    .init("#!/usr/bin/env bun\n", "typescript", label: "bun"),
    .init("#!/usr/bin/env deno\n", "typescript", label: "deno"),
    .init("#!/usr/bin/env ts-node\n", "typescript", label: "ts-node"),
    .init("#!/usr/bin/env tsx\n", "typescript", label: "tsx"),
    // Python
    .init("#!/usr/bin/env python\n", "python", label: "python"),
    .init("#!/usr/bin/env python2\n", "python", label: "python2"),
    .init("#!/usr/bin/env python3\n", "python", label: "python3"),
    .init("#!/usr/bin/env py\n", "python", label: "py"),
    .init("#!/usr/bin/env pypy\n", "python", label: "pypy"),
    .init("#!/usr/bin/env pypy3\n", "python", label: "pypy3"),
    .init("#!/usr/bin/env uv\n", "python", label: "uv"),
    // Ruby
    .init("#!/usr/bin/env ruby\n", "ruby", label: "ruby"),
    .init("#!/usr/bin/env macruby\n", "ruby", label: "macruby"),
    .init("#!/usr/bin/env jruby\n", "ruby", label: "jruby"),
    .init("#!/usr/bin/env rake\n", "ruby", label: "rake"),
    .init("#!/usr/bin/env rbx\n", "ruby", label: "rbx"),
    // Rust
    .init("#!/usr/bin/env rust-script\n", "rust", label: "rust-script"),
    // Bash
    .init("#!/usr/bin/env bash\n", "bash", label: "bash"),
    .init("#!/usr/bin/env sh\n", "bash", label: "sh"),
    .init("#!/usr/bin/env zsh\n", "bash", label: "zsh"),
    .init("#!/usr/bin/env ash\n", "bash", label: "ash"),
    .init("#!/usr/bin/env dash\n", "bash", label: "dash"),
    .init("#!/usr/bin/env ksh\n", "bash", label: "ksh"),
    .init("#!/usr/bin/env mksh\n", "bash", label: "mksh"),
    .init("#!/usr/bin/env pdksh\n", "bash", label: "pdksh"),
    .init("#!/usr/bin/env rc\n", "bash", label: "rc"),
    // C
    .init("#!/usr/bin/env tcc\n", "c", label: "tcc"),
    // Lua
    .init("#!/usr/bin/env lua\n", "lua", label: "lua"),
    .init("#!/usr/bin/env luajit\n", "lua", label: "luajit"),
    // Swift
    .init("#!/usr/bin/env swift\n", "swift", label: "swift")
  ]

  @Test("Interpreter detection", arguments: interpreterCases)
  func interpreterDetection(_ testCase: ShebangCase) {
    let result = LanguageDetector.detect(filename: nil, sourceBytes: Array(testCase.source.utf8), explicit: nil)
    #expect(result == testCase.expected)
  }

  private static let shebangPatternCases: [ShebangCase] = [
    .init("#!/usr/bin/python3\n", "python", label: "direct path"),
    .init("#!/usr/bin/env python3\n", "python", label: "env"),
    .init("#!/usr/bin/env -S python3\n", "python", label: "env -S"),
    .init("#!/usr/bin/env VAR=val node\n", "javascript", label: "env VAR=val"),
    .init("#!/usr/bin/env -u FOO -S ruby\n", "ruby", label: "env -u FOO -S (skip -u arg)"),
    .init("#!/usr/bin/env -S VAR=x OTHER=y ts-node\n", "typescript", label: "env -S with vars"),
    .init("#!/usr/bin/env python3.11\n", "python", label: "version strip python3.11"),
    .init("#!/usr/bin/env ruby2.7\n", "ruby", label: "version strip ruby2.7 → ruby2"),
    .init("#!/usr/bin/env python3.11\n", "python", label: "version strip python3.11 → python3"),
    .init("#!/usr/bin/env python2.7\n", "python", label: "version strip python2.7 → python2"),
    .init("#!/usr/bin/env node18.4\n", "javascript", label: "version strip node18.4 → node18"),
    .init("#!/usr/bin/env lua5.4\n", "lua", label: "version strip lua5.4 → lua5"),
    .init("#!/usr/bin/env pypy3.9\n", "python", label: "version strip pypy3.9 → pypy3"),
    .init("#!/usr/bin/env python3.11.2\n", "python", label: "version strip python3.11.2 → python3"),
    .init("#!/usr/bin/env ruby3.2.1\n", "ruby", label: "version strip ruby3.2.1 → ruby3"),
    .init("#!/usr/bin/env lua5.4.6\n", "lua", label: "version strip lua5.4.6 → lua5"),
    .init("#!  /usr/local/bin/lua\n", "lua", label: "extra whitespace after #!"),
    .init("// swift code\n", nil, label: "no shebang → nil"),
    .init("", nil, label: "empty → nil"),
    .init("{ \"json\": true }\n", nil, label: "json content → nil")
  ]

  @Test("Shebang patterns", arguments: shebangPatternCases)
  func shebangPatterns(_ testCase: ShebangCase) {
    let result = LanguageDetector.detect(filename: nil, sourceBytes: Array(testCase.source.utf8), explicit: nil)
    #expect(result == testCase.expected)
  }

  @Test("Stdin with shebang")
  func stdinShebang() {
    let source = "#!/usr/bin/env node\nconsole.log('hi')\n"
    #expect(LanguageDetector.detect(filename: nil, sourceBytes: Array(source.utf8), explicit: nil) == "javascript")
  }

  @Test("Stdin without shebang or -l → nil")
  func stdinNoShebang() {
    #expect(
      LanguageDetector.detect(filename: nil, sourceBytes: Array("console.log('hi')\n".utf8), explicit: nil) == nil)
  }

  // MARK: - Cascade Priority

  @Test("Extension wins over shebang")
  func extensionOverShebang() {
    #expect(
      LanguageDetector.detect(filename: "file.rb", sourceBytes: Array("#!/usr/bin/env python3\n".utf8), explicit: nil)
        == "ruby")
  }

  @Test("Filename wins over extension and shebang")
  func filenameOverAll() {
    #expect(
      LanguageDetector.detect(
        filename: "Cargo.lock", sourceBytes: Array("#!/usr/bin/env python3\n".utf8), explicit: nil) == "rust")
  }

  // MARK: - Edge Cases

  @Test("Unknown extension → nil")
  func unknownExtension() {
    #expect(LanguageDetector.detect(filename: "file.xyz", sourceBytes: [], explicit: nil) == nil)
  }

  @Test("Unknown interpreter → nil")
  func unknownInterpreter() {
    #expect(
      LanguageDetector.detect(filename: nil, sourceBytes: Array("#!/usr/bin/env fakething\n".utf8), explicit: nil)
        == nil)
  }

  @Test("Nil filename, no shebang → nil")
  func nothingToDetect() {
    #expect(LanguageDetector.detect(filename: nil, sourceBytes: Array("hello world".utf8), explicit: nil) == nil)
  }

  // MARK: - CLI Arg Simulation
  // These simulate the exact values Dog.swift passes to PrintCommand → LanguageDetector.
  // Dog passes: file (positional arg, raw path) as filename, language (-l value) as explicit.

  @Test("-l swift on a .py file → explicit wins")
  func explicitOverridesFileExtension() {
    #expect(
      LanguageDetector.detect(filename: "script.py", sourceBytes: [], explicit: "swift") == "swift")
  }

  @Test("-l js alias resolves through detector")
  func explicitAlias() {
    // Detector returns the explicit value as-is — alias resolution happens in SyntaxParser/Registry
    #expect(LanguageDetector.detect(filename: nil, sourceBytes: [], explicit: "js") == "js")
  }

  @Test("No -l, file arg is a path with extension → detects from extension")
  func fileArgWithPath() {
    #expect(
      LanguageDetector.detect(
        filename: "/Users/dev/project/src/index.js", sourceBytes: [], explicit: nil) == "javascript")
  }

  @Test("No -l, file arg is a path to a known filename → detects from filename")
  func fileArgKnownFilename() {
    #expect(
      LanguageDetector.detect(
        filename: "/home/user/project/Gemfile", sourceBytes: [], explicit: nil) == "ruby")
  }

  @Test("No -l, file arg has .bak suffix → strips and detects")
  func fileArgWithBakSuffix() {
    #expect(
      LanguageDetector.detect(
        filename: "/tmp/config.yaml.bak", sourceBytes: [], explicit: nil) == "yaml")
  }

  @Test("No -l, no file (stdin), source has shebang → detects from shebang")
  func stdinWithShebangSimulation() {
    let source = "#!/usr/bin/env python3\nimport sys\nprint('hello')\n"
    #expect(LanguageDetector.detect(filename: nil, sourceBytes: Array(source.utf8), explicit: nil) == "python")
  }

  @Test("No -l, no file (stdin), no shebang → nil")
  func stdinPlainText() {
    #expect(
      LanguageDetector.detect(filename: nil, sourceBytes: Array("just plain text\n".utf8), explicit: nil) == nil)
  }

  @Test("-l on stdin overrides shebang")
  func explicitOnStdinOverridesShebang() {
    let source = "#!/usr/bin/env python3\nimport sys\n"
    #expect(LanguageDetector.detect(filename: nil, sourceBytes: Array(source.utf8), explicit: "ruby") == "ruby")
  }

  @Test("File arg with unknown extension and no -l → nil")
  func fileArgUnknownExtension() {
    #expect(
      LanguageDetector.detect(filename: "/tmp/data.xyz", sourceBytes: [], explicit: nil) == nil)
  }

  @Test("File arg with no extension, source has shebang → detects from shebang")
  func fileArgNoExtensionFallsToShebang() {
    let source = "#!/usr/bin/env node\nconsole.log('hi')\n"
    #expect(
      LanguageDetector.detect(filename: "/usr/local/bin/myscript", sourceBytes: Array(source.utf8), explicit: nil)
        == "javascript")
  }

  // MARK: - Pipe Simulation (cat file | dog)
  // When piping, there's no file arg — filename is nil.
  // Detection relies on -l flag or shebang in the piped content.

  @Test("cat file | dog -l swift → explicit swift")
  func pipeWithExplicitFlag() {
    let source = "let x = 42\nprint(x)\n"
    #expect(LanguageDetector.detect(filename: nil, sourceBytes: Array(source.utf8), explicit: "swift") == "swift")
  }

  @Test("cat file | dog -l js → explicit js alias")
  func pipeWithExplicitAlias() {
    let source = "console.log('hello')\n"
    #expect(LanguageDetector.detect(filename: nil, sourceBytes: Array(source.utf8), explicit: "js") == "js")
  }

  @Test("cat file | dog (no -l, has shebang) → detects from shebang")
  func pipeNoFlagWithShebang() {
    let source = "#!/usr/bin/env ruby\nputs 'hello'\n"
    #expect(LanguageDetector.detect(filename: nil, sourceBytes: Array(source.utf8), explicit: nil) == "ruby")
  }

  @Test("cat file | dog (no -l, no shebang) → nil")
  func pipeNoFlagNoShebang() {
    let source = "just some text content\nwith multiple lines\n"
    #expect(LanguageDetector.detect(filename: nil, sourceBytes: Array(source.utf8), explicit: nil) == nil)
  }

  @Test("cat file | dog -l python overrides shebang in content")
  func pipeExplicitOverridesShebang() {
    let source = "#!/usr/bin/env node\nconsole.log('hi')\n"
    #expect(LanguageDetector.detect(filename: nil, sourceBytes: Array(source.utf8), explicit: "python") == "python")
  }

  @Test("echo with shebang piped | dog → detects interpreter")
  func echoShebangPipe() {
    let source = "#!/bin/bash\necho 'hello world'\n"
    #expect(LanguageDetector.detect(filename: nil, sourceBytes: Array(source.utf8), explicit: nil) == "bash")
  }
}
