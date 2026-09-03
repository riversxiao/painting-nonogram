// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "KanakaApp",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .executable(name: "KanakaApp", targets: ["KanakaApp"]),
    ],
    dependencies: [
        .package(path: "../../Packages/KanakaProductDomain"),
    ],
    targets: [
        .executableTarget(
            name: "KanakaApp",
            dependencies: ["KanakaProductDomain"]
        ),
    ]
)
