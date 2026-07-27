// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "HFMac",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "HFMac",
            path: "Sources/HFMac"
        ),
        .testTarget(
            name: "HFMacTests",
            dependencies: ["HFMac"],
            path: "Tests"
        ),
    ]
)
