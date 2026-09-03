// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "KanakaStory",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "KanakaStory", targets: ["KanakaStory"]),
    ],
    targets: [
        .target(name: "KanakaStory"),
    ]
)
