// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ConverterCore",
    platforms: [.macOS(.v13), .iOS(.v16)],
    products: [.library(name: "ConverterCore", targets: ["ConverterCore"])],
    targets: [
        .target(name: "ConverterCore", path: "AIOConverter/Core"),
        .testTarget(name: "ConverterCoreTests", dependencies: ["ConverterCore"])
    ]
)
