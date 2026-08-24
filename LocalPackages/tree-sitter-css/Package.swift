// swift-tools-version:5.3

import PackageDescription

let sources = ["src/parser.c", "src/scanner.c"]

let package = Package(
    name: "TreeSitterCSS",
    products: [
        .library(name: "TreeSitterCSS", targets: ["TreeSitterCSS"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "TreeSitterCSS",
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
