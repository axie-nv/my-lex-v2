// swift-tools-version: 5.6
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MyLexV2",
    platforms: [.macOS(.v10_15), .iOS(.v13)],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "MyLexV2",
            targets: ["MyLexV2"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        .package(url: "https://github.com/awslabs/aws-sdk-swift", from: "0.2.6"),
        .package(url: "https://github.com/1024jp/GzipSwift", from: "5.2.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "MyLexV2",
            dependencies: [
                .product(name: "AWSLexRuntimeV2", package: "aws-sdk-swift"),
                .product(name: "Gzip", package: "GzipSwift")
            ]),
        .testTarget(
            name: "MyLexV2Tests",
            dependencies: ["MyLexV2"]),
    ]
)
