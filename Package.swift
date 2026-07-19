// swift-tools-version: 5.9

import CompilerPluginSupport
import PackageDescription

let package = Package(
    name: "LightWeightDI",
    platforms: [
        .iOS(.v14),
        .macOS(.v13),
        .tvOS(.v16),
    ],
    products: [
        .library(
            name: "LightWeightDI",
            targets: ["LightWeightDI"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "600.0.0"),
    ],
    targets: [
        .target(
            name: "LightWeightDI",
            dependencies: ["LightWeightDIMacros"]
        ),
        .target(
            name: "LightWeightDIMacros",
            dependencies: ["LightWeightDIMacrosPlugin"]
        ),
        .macro(
            name: "LightWeightDIMacrosPlugin",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
                .product(name: "SwiftDiagnostics", package: "swift-syntax"),
            ]
        ),
        .testTarget(
            name: "LightWeightDITests",
            dependencies: ["LightWeightDI"]
        ),
        .testTarget(
            name: "LightWeightDIMacroTests",
            dependencies: [
                "LightWeightDI",
                "LightWeightDIMacros",
                "LightWeightDIMacrosPlugin",
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
            ]
        ),
    ]
)
