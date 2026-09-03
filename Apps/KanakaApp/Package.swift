// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "KanakaApp",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .executable(name: "KanakaApp", targets: ["KanakaApp"]),
    ],
    dependencies: [
        .package(path: "../../Packages/KanakaCore"),
        .package(path: "../../Packages/KanakaContentKit"),
        .package(path: "../../Packages/KanakaProgress"),
        .package(path: "../../Packages/KanakaStory"),
        .package(path: "../../Packages/KanakaProductDomain"),
    ],
    targets: [
        .executableTarget(
            name: "KanakaApp",
            dependencies: [
                "KanakaCore",
                "KanakaContentKit",
                "KanakaProgress",
                "KanakaStory",
                "KanakaProductDomain",
            ],
            resources: [.copy("Resources/Content"), .copy("Resources/entitlements.json")]
        ),
    ]
)
