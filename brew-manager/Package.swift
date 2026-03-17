// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "BrewManager",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "BrewManager",
            path: "Sources/BrewManager"
        ),
        .testTarget(
            name: "BrewManagerTests",
            dependencies: ["BrewManager"],
            path: "Tests/BrewManagerTests"
        ),
    ]
)
