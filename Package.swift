// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "MCPKit",
    platforms: [
        .macOS(.v13),
        .macCatalyst(.v16),
        .iOS(.v16),
        .watchOS(.v9),
        .tvOS(.v16),
        .visionOS(.v1)
    ],
    products: [
        .library(name: "MCPKit", targets: ["MCPKit"])
    ],
    dependencies: [
        // The official Model Context Protocol Swift SDK, which MCPKit builds on.
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", from: "0.12.1")
    ],
    targets: [
        .target(
            name: "MCPKit",
            dependencies: [
                .product(name: "MCP", package: "swift-sdk")
            ],
            // The MCP server is actor-based and its handlers are nonisolated `@Sendable`
            // closures, so MCPKit is written against the default (nonisolated) isolation
            // the SDK expects, under the Swift 6 language mode.
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "MCPKitTests",
            dependencies: ["MCPKit"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        )
    ]
)
