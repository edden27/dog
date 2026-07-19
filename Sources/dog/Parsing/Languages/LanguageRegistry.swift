// MARK: - Conditional grammar imports (SE-0450 package traits)

#if BashLib
  import TreeSitterBash
#endif
#if CLib
  import TreeSitterC
#endif
#if CppLib
  import TreeSitterCPP
#endif
#if CSSLib
  import TreeSitterCSS
#endif
#if GoLib
  import TreeSitterGo
#endif
#if HTMLLib
  import TreeSitterHTML
#endif
#if JavaScriptLib
  import TreeSitterJavaScript
#endif
#if JSONLib
  import TreeSitterJSON
#endif
#if LuaLib
  import TreeSitterLua
#endif
#if MarkdownLib
  import TreeSitterMarkdown
  import TreeSitterMarkdownInline
#endif
#if PythonLib
  import TreeSitterPython
#endif
#if RubyLib
  import TreeSitterRuby
#endif
#if RustLib
  import TreeSitterRust
#endif
#if SwiftLib
  import TreeSitterSwift
#endif
#if TSXLib
  import TreeSitterTSX
#endif
#if TypeScriptLib
  import TreeSitterTypeScript
#endif
#if YAMLLib
  import TreeSitterYAML
#endif

// TODO: core expansion imports
// #if TOMLLib
//   import TreeSitterTOML
// #endif
// #if DockerfileLib
//   import TreeSitterDockerfile
// #endif
// #if JavaLib
//   import TreeSitterJava
// #endif
// #if PHPLib
//   import TreeSitterPHP
// #endif
// #if RLib
//   import TreeSitterR
// #endif
// #if SQLLib
//   import TreeSitterSQL
// #endif
// #if ZigLib
//   import TreeSitterZig
// #endif

// TODO: heavy grammar imports
// #if CSharpLib
//   import TreeSitterCSharp
// #endif
// #if KotlinLib
//   import TreeSitterKotlin
// #endif
// #if ScalaLib
//   import TreeSitterScala
// #endif
// #if HaskellLib
//   import TreeSitterHaskell
// #endif
// #if ElixirLib
//   import TreeSitterElixir
// #endif
// #if PerlLib
//   import TreeSitterPerl
// #endif

/// Central registry of all supported languages and their tree-sitter grammars.
///
/// Grammars come from individual tree-sitter grammar repos (local packages).
/// Highlight queries from nvim-treesitter (Apache 2.0) — bundled in
/// Resources/queries/ with inheritance chains pre-resolved.
final class LanguageRegistry: Sendable {
  static let shared = LanguageRegistry()

  private let languages: [String: LanguageEntry]

  /// All canonical language names (not aliases).
  var languageNames: [String] {
    Array(canonicalNames).sorted()
  }

  private let canonicalNames: Set<String>

  // Complexity/length warnings are inflated by #if trait guards — not real complexity.
  // If warnings fire for reasons other than #if guards, investigate.
  private init() {
    var entries: [String: LanguageEntry] = [:]
    var names: Set<String> = []

    func register(
      _ name: String, _ pointer: OpaquePointer,
      queryBytes: [UInt8]?, compiledQueryBlob: [UInt8]? = nil
    ) {
      let sendable = SendablePointer(raw: pointer)
      entries[name] = LanguageEntry(
        tsLanguage: sendable,
        queryBytes: queryBytes,
        compiledQueryBlob: compiledQueryBlob,
        languageName: name
      )
      names.insert(name)
    }

    // MARK: - v1 languages (conditional on package traits)
    // Query files are from nvim-treesitter with inheritance resolved:
    // cpp.scm = c.scm + cpp additions
    // javascript.scm = ecma + jsx + javascript additions
    // typescript.scm = ecma + typescript additions
    // tsx.scm = ecma + typescript + jsx + tsx additions
    // html.scm = html_tags + html additions

    #if BashLib
      register(
        "bash", tree_sitter_bash()!,
        queryBytes: EmbeddedQueries.bash,
        compiledQueryBlob: EmbeddedCompiledQueries.bash)
    #endif
    #if CLib
      register(
        "c", tree_sitter_c()!,
        queryBytes: EmbeddedQueries.c,
        compiledQueryBlob: EmbeddedCompiledQueries.c)
    #endif
    #if CppLib
      register(
        "cpp", tree_sitter_cpp()!,
        queryBytes: EmbeddedQueries.cpp,
        compiledQueryBlob: EmbeddedCompiledQueries.cpp)
    #endif
    #if CSSLib
      register(
        "css", tree_sitter_css()!,
        queryBytes: EmbeddedQueries.css,
        compiledQueryBlob: EmbeddedCompiledQueries.css)
    #endif
    #if GoLib
      register(
        "go", tree_sitter_go()!,
        queryBytes: EmbeddedQueries.go,
        compiledQueryBlob: EmbeddedCompiledQueries.go)
    #endif
    #if HTMLLib
      register(
        "html", tree_sitter_html()!,
        queryBytes: EmbeddedQueries.html,
        compiledQueryBlob: EmbeddedCompiledQueries.html)
    #endif
    #if JavaScriptLib
      register(
        "javascript", tree_sitter_javascript()!,
        queryBytes: EmbeddedQueries.javascript,
        compiledQueryBlob: EmbeddedCompiledQueries.javascript)
    #endif
    #if JSONLib
      register(
        "json", tree_sitter_json()!,
        queryBytes: EmbeddedQueries.json,
        compiledQueryBlob: EmbeddedCompiledQueries.json)
    #endif
    #if LuaLib
      register(
        "lua", tree_sitter_lua()!,
        queryBytes: EmbeddedQueries.lua,
        compiledQueryBlob: EmbeddedCompiledQueries.lua)
    #endif
    #if MarkdownLib
      register(
        "markdown", tree_sitter_markdown()!,
        queryBytes: EmbeddedQueries.markdown,
        compiledQueryBlob: EmbeddedCompiledQueries.markdown)
    #endif
    #if PythonLib
      register(
        "python", tree_sitter_python()!,
        queryBytes: EmbeddedQueries.python,
        compiledQueryBlob: EmbeddedCompiledQueries.python)
    #endif
    #if RubyLib
      register(
        "ruby", tree_sitter_ruby()!,
        queryBytes: EmbeddedQueries.ruby,
        compiledQueryBlob: EmbeddedCompiledQueries.ruby)
    #endif
    #if RustLib
      register(
        "rust", tree_sitter_rust()!,
        queryBytes: EmbeddedQueries.rust,
        compiledQueryBlob: EmbeddedCompiledQueries.rust)
    #endif
    #if SwiftLib
      register(
        "swift", tree_sitter_swift()!,
        queryBytes: EmbeddedQueries.swift,
        compiledQueryBlob: EmbeddedCompiledQueries.swift)
    #endif
    #if TSXLib
      register(
        "tsx", tree_sitter_tsx()!,
        queryBytes: EmbeddedQueries.tsx,
        compiledQueryBlob: EmbeddedCompiledQueries.tsx)
    #endif
    #if TypeScriptLib
      register(
        "typescript", tree_sitter_typescript()!,
        queryBytes: EmbeddedQueries.typescript,
        compiledQueryBlob: EmbeddedCompiledQueries.typescript)
    #endif
    #if YAMLLib
      register(
        "yaml", tree_sitter_yaml()!,
        queryBytes: EmbeddedQueries.yaml,
        compiledQueryBlob: EmbeddedCompiledQueries.yaml)
    #endif

    // TODO: core expansion registrations
    // #if TOMLLib
    //   register("toml", tree_sitter_toml()!, queryFile: "toml")
    // #endif
    // #if DockerfileLib
    //   register("dockerfile", tree_sitter_dockerfile()!, queryFile: "dockerfile")
    // #endif
    // #if JavaLib
    //   register("java", tree_sitter_java()!, queryFile: "java")
    // #endif
    // #if PHPLib
    //   register("php", tree_sitter_php()!, queryFile: "php")
    // #endif
    // #if RLib
    //   register("r", tree_sitter_r()!, queryFile: "r")
    // #endif
    // #if SQLLib
    //   register("sql", tree_sitter_sql()!, queryFile: "sql")
    // #endif
    // #if ZigLib
    //   register("zig", tree_sitter_zig()!, queryFile: "zig")
    // #endif

    // TODO: heavy grammar registrations
    // #if CSharpLib
    //   register("c_sharp", tree_sitter_c_sharp()!, queryFile: "c_sharp")
    // #endif
    // #if KotlinLib
    //   register("kotlin", tree_sitter_kotlin()!, queryFile: "kotlin")
    // #endif
    // #if ScalaLib
    //   register("scala", tree_sitter_scala()!, queryFile: "scala")
    // #endif
    // #if HaskellLib
    //   register("haskell", tree_sitter_haskell()!, queryFile: "haskell")
    // #endif
    // #if ElixirLib
    //   register("elixir", tree_sitter_elixir()!, queryFile: "elixir")
    // #endif
    // #if PerlLib
    //   register("perl", tree_sitter_perl()!, queryFile: "perl")
    // #endif

    // MARK: - Aliases (from linguist languages.yml)
    //
    // These are names users can pass to `-l`. NOT file extensions —
    // extensions belong in LanguageDetector (Step 3).
    // Aliases safely no-op when the parent language trait is disabled.

    if let javascript = entries["javascript"] {
      for alias in ["js", "node"] {
        entries[alias] = javascript
      }
    }

    if let typescript = entries["typescript"] {
      for alias in ["ts", "bun", "deno", "ts-node"] {
        entries[alias] = typescript
      }
    }

    if let tsxEntry = entries["tsx"] {
      entries["typescriptreact"] = tsxEntry
    }

    if let python = entries["python"] {
      for alias in ["py", "py3", "python3"] {
        entries[alias] = python
      }
    }

    if let ruby = entries["ruby"] {
      for alias in ["rb", "jruby", "macruby", "rake"] {
        entries[alias] = ruby
      }
    }

    if let rust = entries["rust"] { entries["rs"] = rust }

    // Linguist canonical is "Shell" with aliases sh, bash, zsh, etc.
    // We use "bash" as canonical since that's the tree-sitter grammar name.
    if let bash = entries["bash"] {
      for alias in ["sh", "shell", "shell-script", "zsh"] {
        entries[alias] = bash
      }
    }

    if let cpp = entries["cpp"] {
      entries["c++"] = cpp
    }

    if let goLang = entries["go"] { entries["golang"] = goLang }

    if let html = entries["html"] {
      entries["xhtml"] = html
    }

    if let json = entries["json"] {
      for alias in ["geojson", "jsonl", "sarif", "topojson"] {
        entries[alias] = json
      }
    }

    if let markdown = entries["markdown"] {
      for alias in ["md", "pandoc"] {
        entries[alias] = markdown
      }
    }

    if let yaml = entries["yaml"] { entries["yml"] = yaml }

    // TODO: core expansion aliases
    // if let java = entries["java"] { entries["jav"] = java }
    // if let php = entries["php"] { entries["php3"] = php; entries["php4"] = php }
    // if let r = entries["r"] { entries["rscript"] = r }

    // TODO: heavy grammar aliases
    // if let cs = entries["c_sharp"] { entries["csharp"] = cs; entries["cs"] = cs }
    // if let kt = entries["kotlin"] { entries["kt"] = kt; entries["kts"] = kt }
    // if let scala = entries["scala"] { entries["sc"] = scala }
    // if let hs = entries["haskell"] { entries["hs"] = hs }
    // if let ex = entries["elixir"] { entries["exs"] = ex }
    // if let pl = entries["perl"] { entries["pl"] = pl; entries["pm"] = pl }

    self.languages = entries
    self.canonicalNames = names
  }

  /// Look up a language entry by name or alias. Returns nil for unknown languages.
  func lookup(_ name: String) -> LanguageEntry? {
    languages[name.lowercased()]
  }

  /// Check if a language name or alias is supported.
  func isSupported(_ name: String) -> Bool {
    languages[name.lowercased()] != nil
  }
}
