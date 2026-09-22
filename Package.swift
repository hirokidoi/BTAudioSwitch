// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BTAudioSwitch",
    platforms: [.macOS(.v15)],
    targets: [
        .executableTarget(
            name: "BTAudioSwitch",
            path: "Sources/BTAudioSwitch"
        ),
        .testTarget(
            name: "BTAudioSwitchTests",
            dependencies: ["BTAudioSwitch"],
            path: "Tests/BTAudioSwitchTests"
        )
    ],
    swiftLanguageModes: [.v6]
)
