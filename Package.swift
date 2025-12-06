// swift-tools-version: 5.9

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
