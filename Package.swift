// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.


import PackageDescription
import Foundation


let package = Package(
    name: "LightWeightDI",
    platforms: [
        .iOS(.v14),.macOS(.v13), .tvOS(.v16)
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "LightWeightDI",
            targets: ["LightWeightDI"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "LightWeightDI",
            dependencies: []),
        .testTarget(
            name: "LightWeightDITests",
            dependencies: ["LightWeightDI"]),
    ]
)

