// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "dog",
    platforms: [.macOS(.v14)],

    // MARK: - Package Traits (SE-0450)

    //
    // Each language is a trait so builds can include only what they need.
    // Default build: swift build            → core (17 v1 langs)
    // Full build:    swift build --traits Full → core + heavy grammars
    // Custom:        swift build --disable-default-traits --traits SwiftLib,JSONLib
    traits: [
        // v1 core — enabled by default
        .default(enabledTraits: [
            "BashLib",
            "CLib",
            "CppLib",
            "CSSLib",
            "GoLib",
            "HTMLLib",
            "JavaScriptLib",
            "JSONLib",
            "LuaLib",
            "MarkdownLib",
            "PythonLib",
            "RubyLib",
            "RustLib",
            "SwiftLib",
            "TSXLib",
            "TypeScriptLib",
            "YAMLLib"
            // TODO: core expansion — add to defaults when grammars land
            // "TOMLLib",
            // "DockerfileLib",
            // "JavaLib",
            // "PHPLib",
            // "RLib",
            // "SQLLib",
            // "ZigLib",
        ]),

        // v1 core languages
        "BashLib",
        "CLib",
        "CppLib",
        "CSSLib",
        "GoLib",
        "HTMLLib",
        "JavaScriptLib",
        "JSONLib",
        "LuaLib",
        "MarkdownLib",
        "PythonLib",
        "RubyLib",
        "RustLib",
        "SwiftLib",
        "TSXLib",
        "TypeScriptLib",
        "YAMLLib"

        // TODO: core expansion (~+5MB, add to defaults when ready)
        // "TOMLLib",        // ~30KB  — dog's own config format
        // "DockerfileLib",  // ~60KB  — ubiquitous dev workflow
        // "JavaLib",        // ~600KB — TIOBE #4
        // "PHPLib",         // ~1.5MB — TIOBE #18, php/php_only split
        // "RLib",           // ~900KB — TIOBE #9, data science
        // "SQLLib",         // ~small — TIOBE #8, needs tree-sitter generate
        // "ZigLib",         // ~1.2MB — rising systems language

        // TODO: heavy grammars — opt-in only (~+25MB)
        // "CSharpLib",      // ~6MB+  — TIOBE #5, 29MB parser.c
        // "KotlinLib",      // ~6MB+  — Android primary, 29MB parser.c
        // "ScalaLib",       // ~6MB+  — JVM ecosystem, 28MB parser.c
        // "HaskellLib",     // ~4.5MB — 114KB scanner, complex layout rules
        // "ElixirLib",      // ~2.8MB — official elixir-lang grammar
        // "PerlLib",        // ~unknown — notoriously hard to parse

        // Meta-trait: enables all heavy grammars on top of defaults
        // TODO: uncomment when heavy grammars land
        // .trait(name: "Full", enabledTraits: [
        //     "CSharpLib", "KotlinLib", "ScalaLib",
        //     "HaskellLib", "ElixirLib", "PerlLib",
        // ]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/apple/swift-argument-parser",
            from: "1.7.0"
        ),
        // Vendored 0.25.10 + local patch: ts_query_serialize/ts_query_deserialize
        // for build-time precompiled highlight queries (perf Item 4 / experiment
        // 003). Was: url tree-sitter/tree-sitter, .upToNextMinor(from: "0.25.0").
        .package(name: "tree-sitter", path: "LocalPackages/tree-sitter"),

        // MARK: - Grammar repos (conditional on traits)

        .package(url: "https://github.com/tree-sitter/tree-sitter-bash", from: "0.23.0"),
        .package(name: "tree-sitter-c", path: "LocalPackages/tree-sitter-c"),
        .package(name: "tree-sitter-cpp", path: "LocalPackages/tree-sitter-cpp"),
        .package(name: "tree-sitter-css", path: "LocalPackages/tree-sitter-css"),
        .package(url: "https://github.com/tree-sitter/tree-sitter-go", from: "0.23.0"),
        .package(name: "tree-sitter-html", path: "LocalPackages/tree-sitter-html"),
        .package(name: "tree-sitter-javascript", path: "LocalPackages/tree-sitter-javascript"),
        .package(name: "tree-sitter-json", path: "LocalPackages/tree-sitter-json"),
        .package(name: "tree-sitter-lua", path: "LocalPackages/tree-sitter-lua"),
        .package(url: "https://github.com/MDeiml/tree-sitter-markdown", branch: "split_parser"),
        .package(name: "tree-sitter-python", path: "LocalPackages/tree-sitter-python"),
        .package(name: "tree-sitter-ruby", path: "LocalPackages/tree-sitter-ruby"),
        .package(name: "tree-sitter-rust", path: "LocalPackages/tree-sitter-rust"),
        .package(
            url: "https://github.com/alex-pinkus/tree-sitter-swift",
            revision: "277b583bbb024f20ba88b95c48bf5a6a0b4f2287"
        ),
        .package(name: "tree-sitter-typescript", path: "LocalPackages/tree-sitter-typescript"),
        .package(name: "tree-sitter-yaml", path: "LocalPackages/tree-sitter-yaml")

        // TODO: core expansion grammar repos
        // .package(url: "https://github.com/ikatyang/tree-sitter-toml", from: "..."),
        // .package(url: "https://github.com/camdencheek/tree-sitter-dockerfile", from: "..."),
        // .package(url: "https://github.com/tree-sitter/tree-sitter-java", from: "..."),
        // .package(url: "https://github.com/tree-sitter/tree-sitter-php", from: "..."),
        // .package(url: "https://github.com/r-lib/tree-sitter-r", from: "..."),
        // .package(url: "https://github.com/DerekStride/tree-sitter-sql", from: "..."),
        // .package(url: "https://github.com/tree-sitter-grammars/tree-sitter-zig", from: "..."),

        // TODO: heavy grammar repos
        // .package(url: "https://github.com/tree-sitter/tree-sitter-c-sharp", from: "..."),
        // .package(url: "https://github.com/fwcd/tree-sitter-kotlin", from: "..."),
        // .package(url: "https://github.com/tree-sitter/tree-sitter-scala", from: "..."),
        // .package(url: "https://github.com/tree-sitter/tree-sitter-haskell", from: "..."),
        // .package(url: "https://github.com/elixir-lang/tree-sitter-elixir", from: "..."),
        // .package(url: "https://github.com/tree-sitter-perl/tree-sitter-perl", from: "..."),
    ],
    targets: [
        .executableTarget(
            name: "dog",
            dependencies: [
                .target(name: "CWcwidth", condition: .when(platforms: [.linux])),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "TreeSitter", package: "tree-sitter"),

                // MARK: - v1 core grammars (conditional on traits)

                .product(name: "TreeSitterBash", package: "tree-sitter-bash",
                         condition: .when(traits: ["BashLib"])),
                .product(name: "TreeSitterC", package: "tree-sitter-c",
                         condition: .when(traits: ["CLib"])),
                .product(name: "TreeSitterCPP", package: "tree-sitter-cpp",
                         condition: .when(traits: ["CppLib"])),
                .product(name: "TreeSitterCSS", package: "tree-sitter-css",
                         condition: .when(traits: ["CSSLib"])),
                .product(name: "TreeSitterGo", package: "tree-sitter-go",
                         condition: .when(traits: ["GoLib"])),
                .product(name: "TreeSitterHTML", package: "tree-sitter-html",
                         condition: .when(traits: ["HTMLLib"])),
                .product(name: "TreeSitterJavaScript", package: "tree-sitter-javascript",
                         condition: .when(traits: ["JavaScriptLib"])),
                .product(name: "TreeSitterJSON", package: "tree-sitter-json",
                         condition: .when(traits: ["JSONLib"])),
                .product(name: "TreeSitterLua", package: "tree-sitter-lua",
                         condition: .when(traits: ["LuaLib"])),
                .product(name: "TreeSitterMarkdown", package: "tree-sitter-markdown",
                         condition: .when(traits: ["MarkdownLib"])),
                .product(name: "TreeSitterPython", package: "tree-sitter-python",
                         condition: .when(traits: ["PythonLib"])),
                .product(name: "TreeSitterRuby", package: "tree-sitter-ruby",
                         condition: .when(traits: ["RubyLib"])),
                .product(name: "TreeSitterRust", package: "tree-sitter-rust",
                         condition: .when(traits: ["RustLib"])),
                .product(name: "TreeSitterSwift", package: "tree-sitter-swift",
                         condition: .when(traits: ["SwiftLib"])),
                .product(name: "TreeSitterTypeScript", package: "tree-sitter-typescript",
                         condition: .when(traits: ["TypeScriptLib", "TSXLib"])),
                .product(name: "TreeSitterYAML", package: "tree-sitter-yaml",
                         condition: .when(traits: ["YAMLLib"]))

                // TODO: core expansion grammars
                // .product(name: "TreeSitterTOML", package: "tree-sitter-toml",
                //          condition: .when(traits: ["TOMLLib"])),
                // .product(name: "TreeSitterDockerfile", package: "tree-sitter-dockerfile",
                //          condition: .when(traits: ["DockerfileLib"])),
                // .product(name: "TreeSitterJava", package: "tree-sitter-java",
                //          condition: .when(traits: ["JavaLib"])),
                // .product(name: "TreeSitterPHP", package: "tree-sitter-php",
                //          condition: .when(traits: ["PHPLib"])),
                // .product(name: "TreeSitterR", package: "tree-sitter-r",
                //          condition: .when(traits: ["RLib"])),
                // .product(name: "TreeSitterSQL", package: "tree-sitter-sql",
                //          condition: .when(traits: ["SQLLib"])),
                // .product(name: "TreeSitterZig", package: "tree-sitter-zig",
                //          condition: .when(traits: ["ZigLib"])),

                // TODO: heavy grammars
                // .product(name: "TreeSitterCSharp", package: "tree-sitter-c-sharp",
                //          condition: .when(traits: ["CSharpLib"])),
                // .product(name: "TreeSitterKotlin", package: "tree-sitter-kotlin",
                //          condition: .when(traits: ["KotlinLib"])),
                // .product(name: "TreeSitterScala", package: "tree-sitter-scala",
                //          condition: .when(traits: ["ScalaLib"])),
                // .product(name: "TreeSitterHaskell", package: "tree-sitter-haskell",
                //          condition: .when(traits: ["HaskellLib"])),
                // .product(name: "TreeSitterElixir", package: "tree-sitter-elixir",
                //          condition: .when(traits: ["ElixirLib"])),
                // .product(name: "TreeSitterPerl", package: "tree-sitter-perl",
                //          condition: .when(traits: ["PerlLib"])),
            ],
            path: "Sources/dog",
            exclude: ["Resources"]
        ),
        .target(
            name: "CWcwidth",
            path: "Sources/CWcwidth"
        ),
        .testTarget(
            name: "dogTests",
            dependencies: [
                "dog",
                // Direct grammar access for tests that construct LanguageEntry
                // with deliberately broken query bytes (QueryFailureTests).
                .product(name: "TreeSitterJSON", package: "tree-sitter-json",
                         condition: .when(traits: ["JSONLib"])),
            ],
            path: "Tests/dogTests"
        )
    ]
)
