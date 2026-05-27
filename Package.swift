// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "GenGrabber",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "GenGrabber",
            path: "GenGrabber",
            exclude: ["Tests"]
        ),
        .testTarget(
            name: "GenGrabberTests",
            dependencies: ["GenGrabber"],
            path: "GenGrabber/Tests"
        ),
    ]
)
