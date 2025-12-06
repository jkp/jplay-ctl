// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "jplay-ctl",
    platforms: [.macOS(.v12)],
    targets: [
        .executableTarget(
            name: "jplay-ctl"
        ),
    ]
)
