// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "RealityKitContent",
    platforms: [
        .visionOS(.v2),
        .macOS(.v15),
        .iOS(.v18)
    ],
    products: [
        .library(
            name: "RealityKitContent",
            targets: ["RealityKitContent"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "RealityKitContent",
            dependencies: [],
            resources: [
                .process("RealityKitContent.rkassets")
            ]
        ),
    ]
)
