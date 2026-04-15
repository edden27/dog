// swift-tools-version:5.3
import PackageDescription

let package = Package(
  name: "TreeSitterTypeScript",
  products: [
    .library(name: "TreeSitterTypeScript", targets: ["TreeSitterTypeScript", "TreeSitterTSX"])
  ],
  dependencies: [],
  targets: [
    .target(
      name: "TreeSitterTypeScript",
      path: ".",
      sources: [
        "typescript/src/parser.c",
        "typescript/src/scanner.c"
      ],
      resources: [
        .copy("queries")
      ],
      publicHeadersPath: "bindings/swift/typescript",
      cSettings: [.headerSearchPath("typescript/src")]
    ),
    .target(
      name: "TreeSitterTSX",
      path: ".",
      sources: [
        "tsx/src/parser.c",
        "tsx/src/scanner.c"
      ],
      resources: [
        .copy("queries")
      ],
      publicHeadersPath: "bindings/swift/tsx",
      cSettings: [.headerSearchPath("tsx/src")]
    )
  ]
)
