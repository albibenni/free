// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Free",
    platforms: [
        .macOS(.v14) // Sequoia is v15, but v14 is available in this swift-tools-version
    ],
    targets: [
        .target(
            name: "FreeLogic",
            path: "Sources/Free",
            exclude: [
                "FreeApp.swift", // Entry point
                // UI Views can be included if they don't cause linking issues in tests,
                // but usually better to separate if possible.
                // For now, including them allows compiling AppState which imports SwiftUI.
            ]
        ),
        .testTarget(
            name: "FreeTests",
            dependencies: ["FreeLogic"],
            path: "Tests/FreeTests"
        )
    ]
)
