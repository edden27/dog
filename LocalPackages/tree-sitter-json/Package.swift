// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "TreeSitterJSON",
    products: [
        .library(name: "TreeSitterJSON", targets: ["TreeSitterJSON"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "TreeSitterJSON",
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
