// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "mvBlocks",
    platforms: [
        .iOS(.v26),
        .macOS(.v26),
    ],
    products: [
        .library(name: "mvBlocksKit", targets: ["mvBlocksKit"]),
        .library(name: "mvBlocksUI", targets: ["mvBlocksUI"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/scalecode-solutions/scalecode-metal-plugin.git",
            from: "1.0.1"
        ),
    ],
    targets: [
        .target(
            name: "mvBlocksKit",
            path: "Sources/mvBlocksKit"
        ),
        .target(
            name: "mvBlocksUI",
            dependencies: ["mvBlocksKit"],
            path: "Sources/mvBlocksUI",
            // The build-tool plugin compiles Sources/mvBlocksUI/Shaders/*.metal
            // into a default.metallib that ends up in this target's resource
            // bundle. Excluding the raw .metal files keeps SPM from also
            // treating them as un-handled resources.
            exclude: ["Shaders"],
            plugins: [
                .plugin(name: "MetalShadersPlugin", package: "scalecode-metal-plugin"),
            ]
        ),
        .testTarget(
            name: "mvBlocksKitTests",
            dependencies: ["mvBlocksKit"],
            path: "Tests/mvBlocksKitTests"
        ),
        .testTarget(
            name: "mvBlocksUITests",
            dependencies: ["mvBlocksUI"],
            path: "Tests/mvBlocksUITests"
        ),
    ]
)
