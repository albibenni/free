// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Free",
    platforms: [
        .macOS("26.0")
    ],
    products: [
        // Exposed so the v2 Xcode targets (app + content-filter extension) can link it.
        .library(name: "FreeLogic", targets: ["FreeLogic"])
    ],
    targets: [
        .target(
            name: "FreeLogic",
            path: "Sources/Free",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .executableTarget(
            name: "FreeApp",
            dependencies: ["FreeLogic"],
            path: "Sources/FreeApp",
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
                .swiftLanguageMode(.v6)
            ]
        ),
    ]
)
