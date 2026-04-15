/// Maps file extensions, filenames, and interpreters to language names.
///
/// All data sourced from GitHub Linguist's `languages.yml`.
/// Only includes extensions/filenames/interpreters for our 17 v1 languages.
enum LanguageMap {

  // MARK: - Extension → Language (Stage 3)

  /// Common file extensions mapped to language names.
  /// Trimmed to recognizable extensions — linguist has many obscure ones.
  /// `.h` maps to cpp (bat's override — most .h files are C++ headers).
  static let extensions: [String: String] = [
    // Swift
    ".swift": "swift",

    // JavaScript
    ".js": "javascript",
    ".mjs": "javascript",
    ".cjs": "javascript",
    ".jsx": "javascript",

    // TypeScript
    ".ts": "typescript",
    ".mts": "typescript",
    ".cts": "typescript",

    // TSX
    ".tsx": "tsx",

    // Python
    ".py": "python",
    ".pyw": "python",
    ".pyi": "python",
    ".py3": "python",

    // Rust
    ".rs": "rust",

    // Go
    ".go": "go",

    // JSON
    ".json": "json",
    ".jsonl": "json",
    ".jsonc": "json",
    ".geojson": "json",
    ".sarif": "json",
    ".topojson": "json",
    ".webmanifest": "json",
    ".avsc": "json",

    // YAML
    ".yaml": "yaml",
    ".yml": "yaml",

    // Bash / Shell
    ".sh": "bash",
    ".bash": "bash",
    ".zsh": "bash",
    ".ksh": "bash",
    ".bats": "bash",
    ".command": "bash",
    ".tmux": "bash",
    ".zsh-theme": "bash",

    // HTML
    ".html": "html",
    ".htm": "html",
    ".xhtml": "html",
    ".xht": "html",

    // CSS
    ".css": "css",

    // Ruby
    ".rb": "ruby",
    ".rbx": "ruby",
    ".rbw": "ruby",
    ".gemspec": "ruby",
    ".rake": "ruby",
    ".ru": "ruby",
    ".podspec": "ruby",

    // C
    ".c": "c",
    ".idc": "c",

    // C++ (.h overrides linguist's C mapping — follows bat)
    ".cpp": "cpp",
    ".cc": "cpp",
    ".cxx": "cpp",
    ".c++": "cpp",
    ".cppm": "cpp",
    ".h": "cpp",
    ".hh": "cpp",
    ".hpp": "cpp",
    ".hxx": "cpp",
    ".h++": "cpp",
    ".ipp": "cpp",
    ".ixx": "cpp",
    ".tpp": "cpp",
    ".txx": "cpp",
    ".inl": "cpp",
    ".ino": "cpp",

    // Lua
    ".lua": "lua",
    ".nse": "lua",
    ".p8": "lua",
    ".rockspec": "lua",
    ".wlua": "lua",

    // Markdown
    ".md": "markdown",
    ".markdown": "markdown",
    ".mdown": "markdown",
    ".mdwn": "markdown",
    ".mkd": "markdown",
    ".mkdn": "markdown",
    ".mkdown": "markdown",
    ".ronn": "markdown",
    ".livemd": "markdown",
    ".workbook": "markdown",
  ]

  // MARK: - Filename → Language (Stage 2)

  /// Exact filename matches. Case-sensitive.
  /// `BUILD` is case-sensitive (Bazel). Lowercase `build` is NOT mapped.
  static let filenames: [String: String] = [
    // JavaScript
    "Jakefile": "javascript",

    // Python
    "SConstruct": "python",
    "SConscript": "python",
    "wscript": "python",
    "DEPS": "python",
    "BUILD": "python",

    // Ruby
    "Gemfile": "ruby",
    "Rakefile": "ruby",
    "Capfile": "ruby",
    "Podfile": "ruby",
    "Brewfile": "ruby",
    "Vagrantfile": "ruby",
    "Guardfile": "ruby",
    "Fastfile": "ruby",
    "Deliverfile": "ruby",
    "Snapfile": "ruby",
    "Dangerfile": "ruby",
    "Appraisals": "ruby",
    "Steepfile": "ruby",
    "Thorfile": "ruby",
    ".irbrc": "ruby",
    ".pryrc": "ruby",
    ".simplecov": "ruby",

    // Bash / Shell
    ".bashrc": "bash",
    ".bash_aliases": "bash",
    ".bash_functions": "bash",
    ".bash_history": "bash",
    ".bash_logout": "bash",
    ".bash_profile": "bash",
    ".zshrc": "bash",
    ".zprofile": "bash",
    ".zlogin": "bash",
    ".zlogout": "bash",
    ".zshenv": "bash",
    ".profile": "bash",
    ".login": "bash",
    ".cshrc": "bash",
    ".kshrc": "bash",
    ".xinitrc": "bash",
    ".xsession": "bash",
    ".envrc": "bash",
    ".flaskenv": "bash",
    ".tmux.conf": "bash",
    "gradlew": "bash",
    "mvnw": "bash",
    "PKGBUILD": "bash",

    // Rust
    "Cargo.lock": "rust",

    // Swift
    "Package.swift": "swift",

    // JSON
    "composer.lock": "json",
    "deno.lock": "json",
    "bun.lock": "json",
    "flake.lock": "json",
    "Pipfile.lock": "json",
    "Package.resolved": "json",
    "MODULE.bazel.lock": "json",

    // YAML
    ".clang-format": "yaml",
    ".clang-tidy": "yaml",
    ".clangd": "yaml",
    ".gemrc": "yaml",
    "glide.lock": "yaml",
    "yarn.lock": "yaml",
    "CITATION.cff": "yaml",

    // Lua
    ".luacheckrc": "lua",

    // Markdown
    "contents.lr": "markdown",
  ]

  // MARK: - Interpreter → Language (Stage 4)

  /// Shebang interpreter names mapped to languages.
  /// Used after stripping path and version suffix.
  static let interpreters: [String: String] = [
    // JavaScript
    "node": "javascript",
    "nodejs": "javascript",
    "js": "javascript",
    "chakra": "javascript",
    "d8": "javascript",
    "gjs": "javascript",
    "qjs": "javascript",
    "rhino": "javascript",
    "v8": "javascript",
    "v8-shell": "javascript",

    // TypeScript
    "bun": "typescript",
    "deno": "typescript",
    "ts-node": "typescript",
    "tsx": "typescript",

    // Python
    "python": "python",
    "python2": "python",
    "python3": "python",
    "py": "python",
    "pypy": "python",
    "pypy3": "python",
    "uv": "python",

    // Ruby
    "ruby": "ruby",
    "macruby": "ruby",
    "jruby": "ruby",
    "rake": "ruby",
    "rbx": "ruby",

    // Rust
    "rust-script": "rust",

    // Bash / Shell
    "bash": "bash",
    "sh": "bash",
    "zsh": "bash",
    "ash": "bash",
    "dash": "bash",
    "ksh": "bash",
    "mksh": "bash",
    "pdksh": "bash",
    "rc": "bash",

    // C
    "tcc": "c",

    // Lua
    "lua": "lua",
    "luajit": "lua",

    // Swift
    "swift": "swift",
  ]

  // MARK: - Ignored Suffixes (from bat)

  /// Backup/temp suffixes to strip before retrying extension lookup.
  /// Try extension first. If no match, strip one suffix and retry once.
  static let ignoredSuffixes: [String] = [
    "~",
    ".bak",
    ".backup",
    ".old",
    ".orig",
    ".save",
    ".in",
    ".dpkg-dist",
    ".dpkg-new",
    ".dpkg-old",
    ".dpkg-tmp",
    ".ucf-dist",
    ".ucf-new",
    ".ucf-old",
    ".rpmnew",
    ".rpmorig",
    ".rpmsave",
  ]
}
