// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SwiftCore",
    products: [
        .library(name: "SwiftCore", targets: ["SwiftCore"])
    ],
    targets: [
        .target(name: "SwiftCore"),
        .testTarget(name: "SwiftCoreTests", dependencies: ["SwiftCore"])
    ]
)
