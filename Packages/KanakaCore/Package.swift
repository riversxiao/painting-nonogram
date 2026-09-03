// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "KanakaCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "KanakaCore", targets: ["KanakaCore"]),
    ],
    targets: [
        .target(name: "KanakaCore")
    ]
)
