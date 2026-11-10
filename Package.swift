// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "PhoneKeyCore",
    platforms: [
        .iOS(.v12),
        .watchOS("6.2")
    ],
    products: [
        .library(name: "PhoneKeyCore", targets: ["PhoneKeyCore"])
    ],
    targets: [
        .target(
            name: "PhoneKeyCore",
            path: "PhoneKeyCore",
            exclude: ["PhoneKeyCore.modulemap", "PhoneKeyKit.h"]
        ),
        .testTarget(
            name: "PhoneKeyCoreTests",
            dependencies: ["PhoneKeyCore"],
            path: "PhoneKeyCoreTests"
        )
    ]
)
