// swift-tools-version:6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "jmespath.swift",
    products: [
        .library(name: "JMESPath", targets: ["JMESPath"])
    ],
    dependencies: [],
    targets: [
        .target(name: "JMESPath", dependencies: []),
        .testTarget(name: "JMESPathTests", dependencies: ["JMESPath"]),
    ]
)
