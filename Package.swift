// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "EyesCaller",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "EyesCaller", targets: ["EyesCaller"])
    ],
    targets: [
        .executableTarget(
            name: "EyesCaller",
            path: "Sources/EyesCaller",
            resources: [
                .copy("Resources/AppIcon.icns"),
                .copy("Resources/MenuBarIcon.png")
            ]
        )
    ]
)
