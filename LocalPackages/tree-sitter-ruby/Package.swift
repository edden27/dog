// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "TreeSitterRuby",
    products: [
        .library(name: "TreeSitterRuby", targets: ["TreeSitterRuby"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "TreeSitterRuby",
            dependencies: [],
            path: ".",
            sources: [
                "src/parser.c",
                "src/scanner.c"
            ],
            resources: [
                .copy("queries")
            ],
            publicHeadersPath: "bindings/swift",
            cSettings: [.headerSearchPath("src")]
        )
    ],
    cLanguageStandard: .c11
)
