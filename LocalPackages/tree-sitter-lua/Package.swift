// swift-tools-version:5.3

import PackageDescription

let sources = ["src/parser.c", "src/scanner.c"]

let package = Package(
    name: "TreeSitterLua",
    products: [
        .library(name: "TreeSitterLua", targets: ["TreeSitterLua"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "TreeSitterLua",
            dependencies: [],
            path: ".",
            sources: sources,
            resources: [
                .copy("queries")
            ],
            publicHeadersPath: "bindings/swift",
            cSettings: [.headerSearchPath("src")]
        )
    ],
    cLanguageStandard: .c11
)
