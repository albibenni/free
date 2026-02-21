// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Free",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(url: "https://github.com/nalexn/ViewInspector.git", from: "0.9.11")
    ],
    targets: [
        .target(
            name: "FreeLogic",
            path: "Sources/Free",
            exclude: []
        ),
        .testTarget(
            name: "FreeTests",
            dependencies: [
                "FreeLogic",
                "ViewInspector"
            ],
            path: "Tests/FreeTests"
        ),
    ]
)
