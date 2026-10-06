// swift-tools-version: 6.0
import PackageDescription

// The platform-agnostic foundation for a portrait retouching app.
//
// PortraitCore deliberately depends on nothing but Foundation + CoreGraphics. Anything that needs
// AppKit, UIKit, Metal or Vision belongs in a separate target: this package defines the
// *data model* and the *rendering contract*, and must stay buildable on every platform
// so that a Mac, an iPad and an iPhone all agree on what a saved edit means.
var clientProducts: [Product] = []
var clientTargets: [Target] = []
#if os(macOS)
clientProducts.append(.executable(name: "portrait-mac", targets: ["PortraitMac"]))
clientTargets.append(.executableTarget(name: "PortraitMac", dependencies: ["PortraitMCP", "PortraitCore", "RetouchKit"]))
clientTargets.append(.testTarget(name: "PortraitMacTests", dependencies: ["PortraitMac"]))
#endif

let package = Package(
    name: "PortraitCore",
    platforms: [.macOS(.v15), .iOS(.v18)],
    products: [
        .library(name: "PortraitCore", targets: ["PortraitCore"]),
        .library(name: "RetouchKit", targets: ["RetouchKit"]),
        .library(name: "PortraitAnalysis", targets: ["PortraitAnalysis"]),
        .library(name: "PortraitMCP", targets: ["PortraitMCP"]),
        .executable(name: "portrait-mcp", targets: ["PortraitHost"]),
    ] + clientProducts,
    targets: [
        .target(name: "PortraitCore"),
        .target(name: "RetouchKit", dependencies: ["PortraitCore"], exclude: ["README.md"]),
        .target(name: "PortraitAnalysis", dependencies: ["PortraitCore"]),
        .target(name: "PortraitMCP", dependencies: ["PortraitCore", "RetouchKit", "PortraitAnalysis"]),
        .executableTarget(name: "PortraitHost", dependencies: ["PortraitMCP", "PortraitAnalysis", "RetouchKit"]),
        .testTarget(name: "PortraitAnalysisTests", dependencies: ["PortraitAnalysis"]),
        .testTarget(name: "PortraitMCPTests", dependencies: ["PortraitMCP"]),
        .testTarget(name: "RetouchKitTests", dependencies: ["RetouchKit", "PortraitCore"]),
        .testTarget(name: "PortraitCoreTests", dependencies: ["PortraitCore"]),
    ] + clientTargets
)
