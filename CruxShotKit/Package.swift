// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CruxShotKit",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "CruxShotKit", targets: ["CruxShotKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.0.0"),
    ],
    targets: [
        .target(
            name: "CruxShotKit",
            dependencies: ["KeyboardShortcuts"]
        ),
        .testTarget(
            name: "CruxShotKitTests",
            dependencies: ["CruxShotKit"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
