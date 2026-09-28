// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CuikeCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "CuikeCore", targets: ["CuikeCore"])],
    targets: [
        .target(name: "CuikeCore", path: "Core"),
        .testTarget(name: "CuikeCoreTests", dependencies: ["CuikeCore"], path: "Tests/CoreTests")
    ]
)
