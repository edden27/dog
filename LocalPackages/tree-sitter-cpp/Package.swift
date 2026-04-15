// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "TreeSitterCPP",
    products: [
        .library(name: "TreeSitterCPP", targets: ["TreeSitterCPP"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "TreeSitterCPP",
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
