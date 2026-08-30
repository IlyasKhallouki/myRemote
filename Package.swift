// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "TVRemote",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "TVRemote",
            targets: ["TVRemote"]
        ),
    ],
    targets: [
        .target(name: "TVRemote"),
        .testTarget(
            name: "TVRemoteTests",
            dependencies: ["TVRemote"]
        ),
    ]
)
