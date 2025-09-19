// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TellMe",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "TellMe",
            targets: ["App"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/exPHAT/SwiftWhisper.git", branch: "master")
    ],
    targets: [
        // Main Application Target
        .executableTarget(
            name: "App",
            dependencies: [
                "TellMeAudio",
                "CoreSTT",
                "CoreModels",
                "CoreInjection",
                "CorePermissions",
                "CoreSettings",
                "CoreUtils"
            ],
            path: "Sources/App",
            resources: [
                .copy("Resources")
            ]
        ),

        // Core Module Targets
        .target(
            name: "TellMeAudio",
            dependencies: ["CoreUtils"],
            path: "Sources/CoreAudio"
        ),

        .target(
            name: "CoreSTT",
            dependencies: [
                "CoreUtils",
                "CoreModels",
                "TellMeAudio",
                .product(name: "SwiftWhisper", package: "SwiftWhisper")
            ],
            path: "Sources/CoreSTT"
        ),

        .target(
            name: "CoreModels",
            dependencies: ["CoreUtils"],
            path: "Sources/CoreModels"
        ),

        .target(
            name: "CoreInjection",
            dependencies: ["CoreUtils", "CorePermissions"],
            path: "Sources/CoreInjection"
        ),

        .target(
            name: "CorePermissions",
            dependencies: ["CoreUtils"],
            path: "Sources/CorePermissions"
        ),

        .target(
            name: "CoreSettings",
            dependencies: ["CoreUtils"],
            path: "Sources/CoreSettings"
        ),

        .target(
            name: "CoreUtils",
            path: "Sources/CoreUtils"
        ),

        // Test Targets
        .testTarget(
            name: "TellMeAudioTests",
            dependencies: ["TellMeAudio"],
            path: "Tests/CoreAudioTests"
        ),

        .testTarget(
            name: "CoreSTTTests",
            dependencies: ["CoreSTT"],
            path: "Tests/CoreSTTTests"
        ),

        .testTarget(
            name: "CoreModelsTests",
            dependencies: ["CoreModels"],
            path: "Tests/CoreModelsTests"
        ),

        .testTarget(
            name: "CoreInjectionTests",
            dependencies: ["CoreInjection"],
            path: "Tests/CoreInjectionTests"
        ),

        .testTarget(
            name: "CorePermissionsTests",
            dependencies: ["CorePermissions"],
            path: "Tests/CorePermissionsTests"
        ),

        .testTarget(
            name: "CoreSettingsTests",
            dependencies: ["CoreSettings"],
            path: "Tests/CoreSettingsTests"
        ),

        .testTarget(
            name: "CoreUtilsTests",
            dependencies: ["CoreUtils"],
            path: "Tests/CoreUtilsTests"
        ),

        .testTarget(
            name: "IntegrationTests",
            dependencies: ["CoreSTT", "CoreModels", "TellMeAudio"],
            path: "Tests/IntegrationTests"
        )
    ]
)