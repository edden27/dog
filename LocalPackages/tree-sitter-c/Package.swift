// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "TreeSitterC",
    products: [
        .library(name: "TreeSitterC", targets: ["TreeSitterC"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "TreeSitterC",
            dependencies: [],
            path: ".",
            sources: [
                "src/parser.c"
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
