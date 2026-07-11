// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "TeleprompterCore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "TeleprompterCore", targets: ["TeleprompterCore"]),
    ],
    targets: [
        .target(name: "TeleprompterCore"),
        .testTarget(
            name: "TeleprompterCoreTests",
            dependencies: ["TeleprompterCore"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
