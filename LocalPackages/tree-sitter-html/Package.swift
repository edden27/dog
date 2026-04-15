// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "TreeSitterHTML",
    products: [
        .library(name: "TreeSitterHTML", targets: ["TreeSitterHTML"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "TreeSitterHTML",
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
