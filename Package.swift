// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "PlayHub",
    platforms: [.macOS(.v15)],
    targets: [
        .executableTarget(name: "PlayHub", path: "Sources/PlayHub", swiftSettings: [.swiftLanguageMode(.v5)])
    ]
)
