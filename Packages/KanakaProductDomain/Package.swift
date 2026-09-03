// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "KanakaProductDomain",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "KanakaProductDomain", targets: ["KanakaProductDomain"]),
    ],
    dependencies: [
        .package(path: "../KanakaCore"),
        .package(path: "../KanakaContentKit"),
        .package(path: "../KanakaProgress"),
        .package(path: "../KanakaStory"),
    ],
    targets: [
        .target(
            name: "KanakaProductDomain",
            dependencies: ["KanakaCore", "KanakaContentKit", "KanakaProgress", "KanakaStory"]
        ),
    ]
)
