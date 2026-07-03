// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ABTastyQAssistant",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "ABTastyQAssistant",
            targets: ["ABTastyQAssistant"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/flagship-io/flagship-ios.git", .upToNextMajor(from: "5.0.0-beta.1"))
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "ABTastyQAssistant",
            dependencies: [
                .product(name: "Flagship", package: "flagship-ios")
            ],
            path: "ABTastyQAssistant",
            exclude: ["Tests", "Classes"],
            resources: [
                .process("Assets"),
                .process("Controllers/QAAssistant.storyboard"),
                .process("Views/QAVariationsView.xib"),
                .process("Views/QAVariationSectionView.xib")
            ],
            // Matches the CocoaPods build (podspec pins swift_version = 5.0). The code
            // predates Swift 6 strict concurrency checking (e.g. NSObjectProtocol observer
            // tokens read in deinit), so keep both distribution channels on Swift 5 mode.
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "ABTastyQAssistantTests",
            dependencies: ["ABTastyQAssistant"],
            path: "ABTastyQAssistant/Tests",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
