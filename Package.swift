// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Uchardet",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v13),
        .tvOS(.v13),
        .watchOS(.v6),
        .visionOS(.v1),
    ],
    products: [
        // 对外暴露的 Swift 封装库
        .library(
            name: "Uchardet",
            targets: ["Uchardet"]
        ),
    ],
    targets: [
        // xcframework 二进制目标（名称必须与 modulemap 中的模块名一致）
        .binaryTarget(
            name: "uchardet",
            path: "output/uchardet.xcframework"
        ),
        // Swift 封装层，依赖 xcframework
        .target(
            name: "Uchardet",
            dependencies: ["uchardet"],
            path: "Sources/Uchardet"
        ),
        // 测试目标
        .testTarget(
            name: "UchardetTests",
            dependencies: ["Uchardet"],
            path: "Tests/UchardetTests"
        ),
    ]
)
