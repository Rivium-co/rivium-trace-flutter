// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "rivium_trace_flutter_sdk",
    platforms: [.iOS("12.0")],
    products: [
        .library(name: "rivium-trace-flutter-sdk", targets: ["rivium_trace_flutter_sdk"])
    ],
    dependencies: [
        .package(url: "https://github.com/Rivium-co/rivium-trace-ios-sdk.git", from: "0.2.5")
    ],
    targets: [
        .target(
            name: "rivium_trace_flutter_sdk",
            dependencies: [.product(name: "RiviumTrace", package: "rivium-trace-ios-sdk")]
        )
    ]
)
