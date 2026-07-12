// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Marquee",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "Marquee",
            path: "Sources/Marquee"
        )
    ]
)
