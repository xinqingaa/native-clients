// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BuildLessonKit",
    products: [
        .library(name: "BuildLessonKit", targets: ["BuildLessonKit"])
    ],
    targets: [
        .target(name: "BuildLessonKit")
    ]
)
