// swift-tools-version:5.3

import PackageDescription

let sources = ["src/parser.c", "src/scanner.c"]

let package = Package(
    name: "TreeSitterPython",
    products: [
        .library(name: "TreeSitterPython", targets: ["TreeSitterPython"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "TreeSitterPython",
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
