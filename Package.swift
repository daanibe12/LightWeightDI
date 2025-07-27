// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.


import PackageDescription
import Foundation



var dependencies: [Package.Dependency] = []
var targets: [Target] = []

let package = Package(
    name: "LightWeightDI",
    platforms: [
        .iOS(.v15),.macOS(.v13), .tvOS(.v16)
    ],
    dependencies: dependencies,
    targets: targets
)

