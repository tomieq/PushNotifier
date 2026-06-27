// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "PushNotifier",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .library(
            name: "PushNotifier",
            targets: ["PushNotifier"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-crypto.git", from: "3.0.0"),
    ],
    targets: [
        .target(
            name: "PushNotifier",
            dependencies: [
                .product(name: "Crypto", package: "swift-crypto"),
            ]
        ),
        .testTarget(
            name: "PushNotifierTests",
            dependencies: [
                "PushNotifier",
                .product(name: "Crypto", package: "swift-crypto"),
            ]
        ),
    ]
)
