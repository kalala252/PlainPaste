// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "PlainPaste",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .target(
            name: "PlainPasteCore"
        ),
        .executableTarget(
            name: "PlainPaste",
            dependencies: ["PlainPasteCore"]
        ),
        .testTarget(
            name: "PlainPasteCoreTests",
            dependencies: ["PlainPasteCore"]
        ),
        .testTarget(
            name: "PlainPasteTests",
            dependencies: ["PlainPaste"]
        ),
    ]
)
