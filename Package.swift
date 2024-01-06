// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "SwiftPGP",
    products: [
        .library(
            name: "SwiftPGP",
            targets: ["PGPFormat"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-crypto", "1.0.0" ..< "3.0.0"),
    ],
    targets: [
        .target(
            name: "PGPFormat",
            dependencies: [
                .product(name: "Crypto", package: "swift-crypto"),
            ],
            path: "PGPFormat" // Adjust the path to where the source files are located
        ),
        .testTarget(
            name: "PGPFormatTests",
            dependencies: ["PGPFormat"],
            path: "PGPFormatTests",
            resources: [
                .process("Resources"),
            ]
        ),
    ]
)
