// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "WorkframeBar",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Workframe", targets: ["Workframe"]),
    ],
    targets: [
        .target(name: "WorkframeCore"),
        .executableTarget(name: "Workframe", dependencies: ["WorkframeCore"]),
        .testTarget(name: "WorkframeTests", dependencies: ["WorkframeCore"]),
    ]
)
