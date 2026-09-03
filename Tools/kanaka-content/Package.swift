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
        .package(path: "../../Packages/KanakaProgress"),
    ],
    targets: [
        .executableTarget(
            name: "kanaka-content",
            dependencies: ["KanakaCore", "KanakaContentKit", "KanakaProgress"]
        ),
    ]
)
