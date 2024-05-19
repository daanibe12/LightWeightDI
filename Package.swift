// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.


import PackageDescription
import Foundation



var dependencies: [Package.Dependency] = []
var targets: [Target] = [
    .target(name: "LightWeightDI", dependencies: ["Swinject"]),
]

    dependencies.append(
        .package(url: "https://github.com/Swinject/Swinject.git", from: "2.6.2")
    )

let package = Package(
    name: "LightWeightDI",
    platforms: [
        .iOS(.v16),.macOS(.v13)
    ],
    products: [
        .library(name: "LightWeightDI", targets: ["LightWeightDI"]),
    ],
    dependencies: dependencies,
    targets: targets
)

