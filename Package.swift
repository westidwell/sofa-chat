// swift-tools-version:5.9
// SofaChatCore asks Claude a question and gets back a small structured answer
// (what to say, a heading, optional chart bars) that fits a big screen.
// SofaChatUI draws that answer in SwiftUI. The engine has no dependencies and
// also builds on Linux, so `swift test` runs anywhere Swift does.
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
        .library(name: "SofaChatUI", targets: ["SofaChatUI"]),
    ],
    targets: [
        .target(name: "SofaChatCore"),
        .target(name: "SofaChatUI", dependencies: ["SofaChatCore"]),
        .testTarget(name: "SofaChatCoreTests", dependencies: ["SofaChatCore"]),
        .testTarget(name: "SofaChatUITests", dependencies: ["SofaChatUI", "SofaChatCore"]),
    ]
)
