// swift-tools-version:5.3

import PackageDescription

let sources = ["src/parser.c", "src/scanner.c"]

let package = Package(
    name: "TreeSitterYAML",
    products: [
        .library(name: "TreeSitterYAML", targets: ["TreeSitterYAML"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "TreeSitterYAML",
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
