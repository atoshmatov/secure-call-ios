// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SecureCallApp",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "SecureCallApp",
            targets: ["SecureCallApp"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "SecureCallApp",
            dependencies: [],
            path: "Sources/SecureCallApp"
        ),
        .testTarget(
            name: "SecureCallAppTests",
            dependencies: ["SecureCallApp"],
            path: "Tests/SecureCallAppTests"
        ),
    ]
)
