// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "kanaka-content",
    platforms: [
        .macOS(.v14),
    ],
    dependencies: [
        .package(path: "../../Packages/KanakaCore"),
        .package(path: "../../Packages/KanakaContentKit"),
    ],
    targets: [
        .executableTarget(
            name: "kanaka-content",
            dependencies: ["KanakaCore", "KanakaContentKit"]
        ),
    ]
)
