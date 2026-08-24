// swift-tools-version:5.3

import PackageDescription

let sources = ["src/parser.c", "src/scanner.c"]

let package = Package(
    name: "TreeSitterJavaScript",
    products: [
        .library(name: "TreeSitterJavaScript", targets: ["TreeSitterJavaScript"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "TreeSitterJavaScript",
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
