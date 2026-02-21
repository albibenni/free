// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Free",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .target(
            name: "FreeLogic",
            path: "Sources/Free",
            exclude: []
        ),
        .testTarget(
            name: "FreeTests",
            dependencies: ["FreeLogic"],
            path: "Tests/FreeTests"
        ),
    ]
)
