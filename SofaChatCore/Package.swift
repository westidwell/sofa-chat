// swift-tools-version:5.9
// SofaChatCore holds everything that isn't screen or speaker code: building the
// API request, reading the reply, the conversation, key handling, demo answers
// and the Pro stubs. It has no dependencies and builds on macOS, tvOS, iOS and
// Linux, so `swift test --package-path SofaChatCore` runs anywhere Swift does.
import PackageDescription

let package = Package(
    name: "SofaChatCore",
    platforms: [
        .tvOS(.v17),
        .iOS(.v17),
        .macOS(.v13),
    ],
    products: [
        .library(name: "SofaChatCore", targets: ["SofaChatCore"]),
    ],
    targets: [
        .target(name: "SofaChatCore"),
        .testTarget(name: "SofaChatCoreTests", dependencies: ["SofaChatCore"]),
    ]
)
