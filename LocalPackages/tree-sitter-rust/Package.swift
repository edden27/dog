// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "TreeSitterRust",
    products: [
        .library(name: "TreeSitterRust", targets: ["TreeSitterRust"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "TreeSitterRust",
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
