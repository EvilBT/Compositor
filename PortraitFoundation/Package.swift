// swift-tools-version: 6.0
import PackageDescription

// The platform-agnostic foundation for a portrait retouching app.
//
// Deliberately depends on nothing but Foundation + CoreGraphics. Anything that needs
// AppKit, UIKit, Metal or Vision belongs in a separate target: this package defines the
// *data model* and the *rendering contract*, and must stay buildable on every platform
// so that a Mac, an iPad and an iPhone all agree on what a saved edit means.
let package = Package(
    name: "PortraitCore",
    platforms: [.macOS(.v15), .iOS(.v18)],
    products: [
        .library(name: "PortraitCore", targets: ["PortraitCore"]),
    ],
    targets: [
        .target(name: "PortraitCore"),
        .testTarget(name: "PortraitCoreTests", dependencies: ["PortraitCore"]),
    ]
)
