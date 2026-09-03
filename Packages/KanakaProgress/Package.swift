// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "KanakaProgress",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "KanakaProgress", targets: ["KanakaProgress"]),
    ],
    dependencies: [
        .package(path: "../KanakaCore"),
    ],
    targets: [
        .target(
            name: "KanakaProgress",
            dependencies: ["KanakaCore"]
        ),
    ]
)
