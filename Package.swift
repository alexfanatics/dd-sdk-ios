// swift-tools-version:5.1

import PackageDescription

let package = Package(
    name: "Datadog",
    platforms: [
        .iOS(.v11)
    ],
    products: [
        .library(
            name: "Datadog",
            targets: ["Datadog"]),
        .library(
            name: "DatadogObjc",
            targets: ["DatadogObjc"]),
    ],
    dependencies: [
        .package(url: "https://github.com/DataDog/opentracing-swift.git", .branch("master")),
    ],
    targets: [
        .target(
            name: "Datadog",
            dependencies: ["_Datadog_Private", "OpenTracing"]),
        .target(
            name: "DatadogObjc",
            dependencies: ["Datadog"]),
        .target(
            name: "_Datadog_Private",
            path: "Datadog/DatadogPrivate"
        ),
        .testTarget(
            name: "DatadogTests",
            dependencies: ["Datadog", "DatadogObjc", "OpenTracing"]),
    ]
)
