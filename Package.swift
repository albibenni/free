// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Free",
    platforms: [
        .macOS("26.0")
    ],
    targets: [
        .target(
            name: "FreeLogic",
            path: "Sources/Free",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .testTarget(
            name: "FreeTests",
            dependencies: [
                "FreeLogic"
            ],
            path: "Tests/FreeTests",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
    ]
)
