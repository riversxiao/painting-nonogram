// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "KanakaContentKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "KanakaContentKit", targets: ["KanakaContentKit"]),
    ],
    dependencies: [
        .package(path: "../KanakaCore"),
    ],
    targets: [
        .target(
            name: "KanakaContentKit",
            dependencies: ["KanakaCore"]
        ),
    ]
)
