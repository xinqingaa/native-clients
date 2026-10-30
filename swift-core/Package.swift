// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "SwiftCore",
    platforms: [.macOS(.v15)],
    products: [.library(name: "SwiftCore", targets: ["SwiftCore"])],
    targets: [
        .target(name: "SwiftCore"),
        .testTarget(name: "SwiftCoreTests", dependencies: ["SwiftCore"]),
        .executableTarget(name: "ValuesDemo", dependencies: ["SwiftCore"]),
        .executableTarget(name: "ModelingDemo", dependencies: ["SwiftCore"]),
        .executableTarget(name: "ProtocolsDemo", dependencies: ["SwiftCore"]),
        .executableTarget(name: "MemoryDemo", dependencies: ["SwiftCore"]),
        .executableTarget(name: "ConcurrencyDemo", dependencies: ["SwiftCore"]),
    ],
    swiftLanguageModes: [.v6]
)
