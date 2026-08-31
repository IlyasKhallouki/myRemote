// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "TVRemote",
    platforms: [
        .iOS(.v18),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "TVRemote",
            targets: ["TVRemote"]
        ),
        // xtool packs this one into TVRemoteWidget.appex under the app bundle.
        .library(
            name: "TVRemoteWidget",
            targets: ["TVRemoteWidget"]
        ),
    ],
    targets: [
        // Everything both the app and the Live Activity need to see. The intents
        // must be compiled into the widget binary for `Button(intent:)` to build
        // one, and into the app binary for `perform()` to run there.
        .target(name: "TVRemoteCore"),
        .target(name: "TVRemote", dependencies: ["TVRemoteCore"]),
        .target(name: "TVRemoteWidget", dependencies: ["TVRemoteCore"]),
        .testTarget(
            name: "TVRemoteTests",
            dependencies: ["TVRemote", "TVRemoteCore"]
        ),
    ]
)
