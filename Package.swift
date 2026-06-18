// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CodexTrafficGlass",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "CodexTrafficGlass", targets: ["CodexTrafficGlassApp"])
    ],
    targets: [
        .target(
            name: "CodexTrafficGlassCore"
        ),
        .executableTarget(
            name: "CodexTrafficGlassApp",
            dependencies: ["CodexTrafficGlassCore"]
        ),
        .executableTarget(
            name: "CodexTrafficGlassSelfTests",
            dependencies: ["CodexTrafficGlassCore"],
            path: "Tests/CodexTrafficGlassSelfTests"
        )
    ]
)
